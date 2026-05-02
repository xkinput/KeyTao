#!/usr/bin/env bash
# Leak test: N rounds × M strokes, with R-second rest between rounds.
# Shows live progress table and trend analysis.
#
# Usage:
#   bash scripts/leak_test.sh <rounds>                         # just rounds, use defaults for rest
#   bash scripts/leak_test.sh [platform] [schema] [rounds] [per-round] [rest-sec]
#
# Defaults: mac  keytao-dz  10  1000  20
set -uo pipefail

if [ -z "${IN_NIX_SHELL:-}" ]; then
    REPO=$(cd "$(dirname "$0")/.." && pwd)
    exec nix develop "$REPO" --command bash "$0" "$@"
fi

# If the first argument is a plain integer, treat it as rounds (shorthand mode).
if [[ "${1:-}" =~ ^[0-9]+$ ]]; then
    ROUNDS="$1"
    PLATFORM="${2:-mac}"
    SCHEMA="${3:-keytao-dz}"
    PER_ROUND="${4:-1000}"
    REST_SEC="${5:-20}"
else
    PLATFORM="${1:-mac}"
    SCHEMA="${2:-keytao-dz}"
    ROUNDS="${3:-10}"
    PER_ROUND="${4:-1000}"
    REST_SEC="${5:-20}"
fi

REPO=$(cd "$(dirname "$0")/.." && pwd)
BENCH="$REPO/scripts/mem_bench"
DEPLOYER=$(command -v rime_deployer 2>/dev/null \
    || ls /nix/store/*/bin/rime_deployer 2>/dev/null | sort -V | tail -1 || true)

[ -x "$BENCH" ]    || { echo "ERROR: scripts/mem_bench not compiled. Run: bash scripts/build_mem_bench.sh"; exit 1; }
[ -n "$DEPLOYER" ] || { echo "ERROR: rime_deployer not found"; exit 1; }

if [ -z "${RIME_SHARED:-}" ]; then
    RIME_SHARED=$(ls -d /nix/store/*/share/rime-data 2>/dev/null \
        | grep -v keytao | sort -V | tail -1 || true)
    [ -z "$RIME_SHARED" ] && RIME_SHARED=/usr/share/rime-data
fi

# ── Build release & deploy ────────────────────────────────────────────────────
printf "Building release... "
bash "$REPO/scripts/release.sh" v0.0.0-memtest >/dev/null 2>&1 && echo "done" || { echo "FAIL"; exit 1; }

SRC="$REPO/release/keytao-$PLATFORM"
[ -d "$SRC" ] || { echo "ERROR: $SRC not found"; exit 1; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cp -r "$SRC"/. "$WORK/"

printf "Deploying %s... " "$PLATFORM"
"$DEPLOYER" --build "$WORK" "$RIME_SHARED" "$WORK/build" >/dev/null 2>&1
[ -f "$WORK/build/${SCHEMA}.prism.bin" ] || \
[ -f "$WORK/build/${SCHEMA}.extended.prism.bin" ] || \
    { echo "FAIL: no prism.bin for $SCHEMA after deploy"; exit 1; }
echo "done"

_R=$'\033[1;31m'
_G=$'\033[1;32m'
_Y=$'\033[1;33m'
_X=$'\033[0m'

kb_to_mb() { awk "BEGIN{printf \"%.2f\", $1/1024}"; }

echo ""
printf "Leak test: %s / %s  —  %d rounds × %d strokes + %ds rest\n" \
    "$PLATFORM" "$SCHEMA" "$ROUNDS" "$PER_ROUND" "$REST_SEC"
total_time=$(( ROUNDS * (REST_SEC + (PER_ROUND / 50)) ))  # rough estimate
printf "Estimated time: ~%dm%ds\n" $((total_time/60)) $((total_time%60))
echo ""
printf "%-6s  %-8s  %-10s  %-10s  %-10s  %s\n" \
    "Round" "Strokes" "Peak RSS" "After ${REST_SEC}s" "Δ from R1" "Trend"
printf "%-6s  %-8s  %-10s  %-10s  %-10s  %s\n" \
    "──────" "────────" "──────────" "──────────" "──────────" "─────"

# ── Stream bench output and render table live ─────────────────────────────────
declare -A peaks rests strokes_at
base_rest=0
prev_rest=0

while IFS= read -r line; do
    key="${line%%=*}"
    val="${line##*=}"
    case "$key" in
        rss_after_schema)
            printf "Schema loaded: ${_G}%.2fM${_X}\n\n" "$(kb_to_mb "$val")"
            ;;
        round_*_strokes)
            r="${key#round_}"; r="${r%_strokes}"
            strokes_at[$r]=$val
            ;;
        round_*_peak)
            r="${key#round_}"; r="${r%_peak}"
            peaks[$r]=$val
            ;;
        round_*_rest)
            r="${key#round_}"; r="${r%_rest}"
            rests[$r]=$val
            p="${peaks[$r]:-0}"

            # set baseline from round 1
            [ "$r" -eq 1 ] && base_rest=$val

            delta_kb=$(( val - base_rest ))
            delta_mb=$(awk "BEGIN{printf \"%+.2f\", $delta_kb/1024}")

            # trend arrow based on change vs previous round
            if [ "$r" -eq 1 ]; then
                trend="  —"
            else
                diff_kb=$(( val - prev_rest ))
                if [ "$diff_kb" -gt 100 ]; then
                    trend="${_R}↑ +$(awk "BEGIN{printf \"%.2f\",$diff_kb/1024}")M${_X}"
                elif [ "$diff_kb" -lt -100 ]; then
                    trend="${_G}↓ $(awk "BEGIN{printf \"%.2f\",$diff_kb/1024}")M${_X}"
                else
                    trend="${_G}≈ stable${_X}"
                fi
            fi
            prev_rest=$val

            printf "%-6s  %-8s  %-10s  %-10s  %-10s  %s\n" \
                "$r" \
                "${strokes_at[$r]:-$((r * PER_ROUND))}" \
                "$(kb_to_mb "$p")M" \
                "$(kb_to_mb "$val")M" \
                "${delta_mb}M" \
                "$trend"
            ;;
    esac
done < <("$BENCH" \
    --user-data-dir   "$WORK" \
    --shared-data-dir "$RIME_SHARED" \
    --schema          "$SCHEMA" \
    --rounds          "$ROUNDS" \
    --per-round       "$PER_ROUND" \
    --rest-sec        "$REST_SEC" \
    2>&1)

# ── Final analysis ────────────────────────────────────────────────────────────
echo ""
echo "── Analysis ─────────────────────────────────────────────────────────────"

if [ ${#rests[@]} -ge 2 ]; then
    first="${rests[1]:-0}"
    last="${rests[$ROUNDS]:-0}"
    total_growth_kb=$(( last - first ))
    total_growth_mb=$(awk "BEGIN{printf \"%.2f\", $total_growth_kb/1024}")

    mid=${rests[$((ROUNDS/2))]:-0}
    first_half_kb=$(( mid  - first ))
    second_half_kb=$(( last - mid ))

    echo ""
    printf "  RSS after rest R1  → R%-2d:  %.2fM → %.2fM  (Δ %+.2fM)\n" \
        "$ROUNDS" "$(kb_to_mb "$first")" "$(kb_to_mb "$last")" "$total_growth_mb"
    echo ""

    if [ "$total_growth_kb" -lt 300 ]; then
        echo "  ${_G}✓ STABLE: total growth < 0.3 MB across all rounds.${_X}"
        echo "    RSS growth is normal mmap warm-up, not a leak."
    elif [ "$second_half_kb" -lt "$((first_half_kb / 2))" ]; then
        echo "  ${_Y}~ CONVERGING: growth rate is slowing down.${_X}"
        echo "    Memory is stabilizing — consistent with LevelDB user-dict caching."
    else
        echo "  ${_R}! GROWING: memory keeps increasing at a similar rate each round.${_X}"
        echo "    Possible leak or unbounded cache. Investigate further."
    fi

    echo ""
    echo "  Peak during typing always higher than rest-RSS:"
    for r in $(seq 1 "$ROUNDS"); do
        p="${peaks[$r]:-0}"; rv="${rests[$r]:-0}"
        [ "$p" -gt 0 ] || continue
        burst=$(awk "BEGIN{printf \"%.2f\", ($p-$rv)/1024}")
        printf "    R%-2d: peak=%.2fM  rest=%.2fM  (burst +%sM during typing)\n" \
            "$r" "$(kb_to_mb "$p")" "$(kb_to_mb "$rv")" "$burst"
    done
fi

echo ""
echo "RSS = current resident set (mach_task_basic_info). Includes mmap-backed dict pages."
