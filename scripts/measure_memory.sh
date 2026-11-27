#!/usr/bin/env bash
# Measure runtime memory of Rime schemas in rime/.
# Can be run directly — auto-enters nix develop if needed.
#
# Usage:
#   bash scripts/measure_memory.sh [schema_id]
#   bash scripts/measure_memory.sh keytao-dz
set -uo pipefail

# ── Auto-enter nix develop if not already inside ────────────────────────────
if [ -z "${IN_NIX_SHELL:-}" ]; then
    REPO_FOR_NIX=$(cd "$(dirname "$0")/.." && pwd)
    exec nix develop "$REPO_FOR_NIX" --command bash "$0" "$@"
fi

FILTER_SCHEMA="${1:-}"
REPO=$(cd "$(dirname "$0")/.." && pwd)
BENCH="$REPO/scripts/mem_bench"
DEPLOYER=$(command -v rime_deployer || true)

[ -x "$BENCH" ]    || { echo "ERROR: scripts/mem_bench not compiled. Re-enter nix develop"; exit 1; }
[ -n "$DEPLOYER" ] || { echo "ERROR: rime_deployer not found"; exit 1; }
: "${RIME_SHARED:?ERROR: RIME_SHARED not set — run inside nix develop}"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cp -r "$REPO/rime"/. "$WORK/"

printf "Deploying rime/... "
"$DEPLOYER" --build "$WORK" "$RIME_SHARED" "$WORK/build" >/dev/null 2>&1
echo "done"

CHECKPOINTS="500,1500,3000"
schema_ids=()
while IFS= read -r sid; do
    [ -n "$sid" ] && schema_ids+=("$sid")
done < <(grep -rh "^  schema_id:" "$REPO/rime"/*.schema.yaml 2>/dev/null | awk '{print $2}' | sort -u)

kb_to_mb() { awk "BEGIN{printf \"%.2fM\", $1/1024}"; }

declare -a ROWS=()
printf "Measuring"
for sid in "${schema_ids[@]}"; do
    [ -n "$FILTER_SCHEMA" ] && [ "$sid" != "$FILTER_SCHEMA" ] && continue
    [ -f "$WORK/build/${sid}.prism.bin" ] || [ -f "$WORK/build/${sid}.extended.prism.bin" ] || continue

    bench_out=$("$BENCH" \
        --user-data-dir   "$WORK" \
        --shared-data-dir "$RIME_SHARED" \
        --schema          "$sid" \
        --checkpoints     "$CHECKPOINTS" \
        2>&1) || { printf "!"; continue; }

    rss_schema=$(awk -F= '/^rss_after_schema=/ {print $2}' <<<"$bench_out")
    rss_500=$(   awk -F= '/^rss_at_500=/       {print $2}' <<<"$bench_out")
    rss_1500=$(  awk -F= '/^rss_at_1500=/      {print $2}' <<<"$bench_out")
    rss_3000=$(  awk -F= '/^rss_at_3000=/      {print $2}' <<<"$bench_out")
    rss_idle=$(  awk -F= '/^rss_idle=/         {print $2}' <<<"$bench_out")
    rss_rest=$(  awk -F= '/^rss_after_rest=/   {print $2}' <<<"$bench_out")

    ROWS+=("$sid|${rss_schema:-0}|${rss_500:-0}|${rss_1500:-0}|${rss_3000:-0}|${rss_idle:-0}|${rss_rest:-0}")
    printf "."
done
echo " (${#ROWS[@]} schemas)"

[ ${#ROWS[@]} -eq 0 ] && { echo "No results collected."; exit 1; }

echo ""
printf "%-16s  %9s  %9s  %9s  %9s  %9s  %9s\n" \
    "Schema" "Loaded" "@500" "@1500" "@3000" "Idle" "Rest(5s)"
printf "%-16s  %9s  %9s  %9s  %9s  %9s  %9s\n" \
    "────────────────" "─────────" "─────────" "─────────" "─────────" "─────────" "─────────"
for row in "${ROWS[@]}"; do
    IFS='|' read -r sid s c1 c2 c3 idle rest <<<"$row"
    printf "%-16s  %9s  %9s  %9s  %9s  %9s  %9s\n" \
        "$sid" \
        "$(kb_to_mb "$s")" \
        "$(kb_to_mb "$c1")" \
        "$(kb_to_mb "$c2")" \
        "$(kb_to_mb "$c3")" \
        "$(kb_to_mb "$idle")" \
        "$(kb_to_mb "$rest")"
done

echo ""
echo "RSS = current resident set (MB; mach_task_basic_info on macOS, VmRSS on Linux)"
