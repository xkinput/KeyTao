#!/usr/bin/env bash
# Measure runtime memory of every Rime schema across all release platforms.
# Can be run directly — auto-enters nix develop if needed.
#
# Usage:
#   bash scripts/measure_memory.sh [platform] [schema_id]
#   bash scripts/measure_memory.sh mac
#   bash scripts/measure_memory.sh android keytao-dz
set -uo pipefail

# ── Auto-enter nix develop if not already inside ────────────────────────────
if [ -z "${IN_NIX_SHELL:-}" ]; then
    REPO_FOR_NIX=$(cd "$(dirname "$0")/.." && pwd)
    exec nix develop "$REPO_FOR_NIX" --command bash "$0" "$@"
fi

FILTER_PLATFORM="${1:-}"
FILTER_SCHEMA="${2:-}"

REPO=$(cd "$(dirname "$0")/.." && pwd)
BENCH="$REPO/scripts/mem_bench"
DEPLOYER=$(command -v rime_deployer 2>/dev/null \
    || ls /nix/store/*/bin/rime_deployer 2>/dev/null | sort -V | tail -1 || true)

[ -x "$BENCH" ]    || { echo "ERROR: scripts/mem_bench not compiled"; exit 1; }
[ -n "$DEPLOYER" ] || { echo "ERROR: rime_deployer not found";        exit 1; }

if [ -z "${RIME_SHARED:-}" ]; then
    RIME_SHARED=$(ls -d /nix/store/*/share/rime-data 2>/dev/null \
        | grep -v keytao | sort -V | tail -1 || true)
    [ -z "$RIME_SHARED" ] && RIME_SHARED=/usr/share/rime-data
fi

# ── 1. Generate release directories ─────────────────────────────────────────
printf "Building release packages... "
bash "$REPO/scripts/release.sh" v0.0.0-memtest >/dev/null 2>&1 \
    && echo "done" || { echo "FAIL"; exit 1; }

RELEASE="$REPO/release"
TMPROOT=$(mktemp -d)
trap 'rm -rf "$TMPROOT"' EXIT

declare -a PLATFORMS=(linux mac windows android ios)
declare -a CHECKPOINTS=(500 1500 3000)
declare -a RESULTS=()        # platform|sid|cp500|cp1500|cp3000|rss_schema|rss_idle
declare -a SCHEMA_ORDER=()

# ── 2. Deploy + bench each platform ─────────────────────────────────────────
for platform in "${PLATFORMS[@]}"; do
    [ -n "$FILTER_PLATFORM" ] && [ "$platform" != "$FILTER_PLATFORM" ] && continue

    SRC="$RELEASE/keytao-$platform"
    [ -d "$SRC" ] || continue

    WORK="$TMPROOT/$platform"
    mkdir -p "$WORK"
    cp -r "$SRC"/. "$WORK/"

    printf "Measuring %-10s " "$platform..."
    "$DEPLOYER" --build "$WORK" "$RIME_SHARED" "$WORK/build" >/dev/null 2>&1

    mapfile -t schema_ids < <(
        grep -rh "^  schema_id:" "$SRC"/*.schema.yaml 2>/dev/null \
        | awk '{print $2}' | sort -u
    )

    count=0
    for sid in "${schema_ids[@]}"; do
        [ -n "$FILTER_SCHEMA" ] && [ "$sid" != "$FILTER_SCHEMA" ] && continue
        [ -f "$WORK/build/${sid}.prism.bin" ] || \
        [ -f "$WORK/build/${sid}.extended.prism.bin" ] || continue

        bench_out=$("$BENCH" \
            --user-data-dir   "$WORK" \
            --shared-data-dir "$RIME_SHARED" \
            --schema          "$sid" \
            --checkpoints     "$(IFS=,; echo "${CHECKPOINTS[*]}")" \
            2>&1) || { printf "!"; continue; }

        rss_schema=$(echo "$bench_out" | awk -F= '/^rss_after_schema=/ {print $2}')
        rss_idle=$(  echo "$bench_out" | awk -F= '/^rss_idle=/         {print $2}')
        rss_rest=$(  echo "$bench_out" | awk -F= '/^rss_after_rest=/   {print $2}')
        cp_vals=""
        for cp in "${CHECKPOINTS[@]}"; do
            v=$(echo "$bench_out" | awk -F= "/^rss_at_${cp}=/ {print \$2}")
            cp_vals="${cp_vals}|${v:-0}"
        done

        RESULTS+=("$platform|$sid${cp_vals}|$rss_schema|$rss_idle|${rss_rest:-0}")

        if ! printf '%s\n' "${SCHEMA_ORDER[@]:-}" | grep -qx "$sid"; then
            SCHEMA_ORDER+=("$sid")
        fi
        printf "."; count=$((count+1))
    done
    echo " ($count schemas)"
done

[ ${#RESULTS[@]} -eq 0 ] && { echo "No results collected."; exit 1; }

# ── helpers ──────────────────────────────────────────────────────────────────
_R=$'\033[1;31m'
_X=$'\033[0m'

kb_to_mb() { awk "BEGIN{printf \"%.2f\", $1/1024}"; }

# lookup_cp <platform> <sid> <checkpoint_index (0-based)>
# RESULTS row: platform|sid|cp0|cp1|cp2|...|rss_schema|rss_idle
lookup_cp() {
    local want_p="$1" want_s="$2" want_i=$(( $3 + 2 ))  # +2: skip platform,sid, then 0-based cp index
    local col=0
    for r in "${RESULTS[@]}"; do
        col=0
        IFS='|' read -ra fields <<< "$r"
        [ "${fields[0]}" = "$want_p" ] && [ "${fields[1]}" = "$want_s" ] || continue
        echo "${fields[$want_i]}"
        return
    done
}
lookup_schema() {
    local want_p="$1" want_s="$2" want_f="${3:-schema}"
    local n_cp=${#CHECKPOINTS[@]}
    for r in "${RESULTS[@]}"; do
        IFS='|' read -ra fields <<< "$r"
        [ "${fields[0]}" = "$want_p" ] && [ "${fields[1]}" = "$want_s" ] || continue
        case "$want_f" in
            schema) echo "${fields[$((n_cp + 2))]}" ;;  # rss_after_schema
            idle)   echo "${fields[$((n_cp + 3))]}" ;;  # rss_idle
            rest)   echo "${fields[$((n_cp + 4))]}" ;;  # rss_after_rest
        esac
        return
    done
}

# global max across all RESULTS for a given column index
col_max() {
    local idx="$1" best=0
    for r in "${RESULTS[@]}"; do
        IFS='|' read -ra fields <<< "$r"
        local v="${fields[$idx]:-0}"
        [ "$v" -gt "$best" ] && best=$v
    done
    echo "$best"
}

# active platforms (respect filter)
declare -a ACT_PLATFORMS=()
for p in "${PLATFORMS[@]}"; do
    [ -n "$FILTER_PLATFORM" ] && [ "$p" != "$FILTER_PLATFORM" ] && continue
    ACT_PLATFORMS+=("$p")
done

NUM_W=9
CELL_W=$((NUM_W + 2))
sep_inner=$(printf '%0.s─' $(seq 1 $((${#ACT_PLATFORMS[@]} * CELL_W))))

print_cp_table() {   # print_cp_table <cp_index> <cp_label>
    local ci="$1" label="$2"
    local col_idx=$(( ci + 2 ))  # in RESULTS fields: 0=platform,1=sid,2..=checkpoints
    local gmax
    gmax=$(col_max "$col_idx")
    local inner_w=$(( ${#ACT_PLATFORMS[@]} * CELL_W ))

    echo ""
    printf "┌──────────────────────────┬%s┐\n" "$sep_inner"
    printf "│ %-24s │ %-*s│\n" "" $((inner_w - 1)) "$label  (MB, peak RSS up to this point)"
    printf "│ %-24s │" "Schema"
    for p in "${ACT_PLATFORMS[@]}"; do printf " %-*s " $NUM_W "$p"; done
    printf "│\n"
    printf "├──────────────────────────┼%s┤\n" "$sep_inner"
    for sid in "${SCHEMA_ORDER[@]}"; do
        [ -n "$FILTER_SCHEMA" ] && [ "$sid" != "$FILTER_SCHEMA" ] && continue
        printf "│ %-24s │" "$sid"
        for p in "${ACT_PLATFORMS[@]}"; do
            val=$(lookup_cp "$p" "$sid" "$ci")
            if [ -n "$val" ] && [ "$val" -gt 0 ]; then
                num_str=$(printf "%${NUM_W}s" "$(kb_to_mb "$val")M")
                if [ "$val" -eq "$gmax" ]; then
                    printf "%s %s*%s" "$_R" "$num_str" "$_X"
                else
                    printf " %s " "$num_str"
                fi
            else
                printf " %*s " $NUM_W "-"
            fi
        done
        printf "│\n"
    done
    printf "└──────────────────────────┴%s┘\n" "$sep_inner"
}

print_field_table() {  # print_field_table <field: schema|idle> <title>
    local field="$1" label="$2"
    local n_cp=${#CHECKPOINTS[@]}
    local col_idx
    case "$field" in
        schema) col_idx=$(( n_cp + 2 )) ;;
        idle)   col_idx=$(( n_cp + 3 )) ;;
        rest)   col_idx=$(( n_cp + 4 )) ;;
    esac
    local gmax
    gmax=$(col_max "$col_idx")
    local inner_w=$(( ${#ACT_PLATFORMS[@]} * CELL_W ))

    echo ""
    printf "┌──────────────────────────┬%s┐\n" "$sep_inner"
    printf "│ %-24s │ %-*s│\n" "" $((inner_w - 1)) "$label  (MB)"
    printf "│ %-24s │" "Schema"
    for p in "${ACT_PLATFORMS[@]}"; do printf " %-*s " $NUM_W "$p"; done
    printf "│\n"
    printf "├──────────────────────────┼%s┤\n" "$sep_inner"
    for sid in "${SCHEMA_ORDER[@]}"; do
        [ -n "$FILTER_SCHEMA" ] && [ "$sid" != "$FILTER_SCHEMA" ] && continue
        printf "│ %-24s │" "$sid"
        for p in "${ACT_PLATFORMS[@]}"; do
            val=$(lookup_schema "$p" "$sid" "$field")
            if [ -n "$val" ] && [ "$val" -gt 0 ]; then
                num_str=$(printf "%${NUM_W}s" "$(kb_to_mb "$val")M")
                if [ "$val" -eq "$gmax" ]; then
                    printf "%s %s*%s" "$_R" "$num_str" "$_X"
                else
                    printf " %s " "$num_str"
                fi
            else
                printf " %*s " $NUM_W "-"
            fi
        done
        printf "│\n"
    done
    printf "└──────────────────────────┴%s┘\n" "$sep_inner"
}

# ── 3. Print result tables ────────────────────────────────────────────────────
print_field_table schema "After schema load (idle, before typing)"

for ci in "${!CHECKPOINTS[@]}"; do
    print_cp_table "$ci" "After ${CHECKPOINTS[$ci]} strokes"
done

print_field_table idle "After typing cleared (idle)"
print_field_table rest "After 5s rest (OS mmap page reclaim)"

echo ""
echo "* = global max in that table"
echo "RSS = current resident set (mach_task_basic_info on macOS; can decrease after reclaim)"
echo "keytao-bj: uses Lua (keytao_filter.lua) + OpenCC (emoji.json, s2t.json)"
echo "keytao / keytao-cx / keytao-dz: no Lua, no OpenCC"
