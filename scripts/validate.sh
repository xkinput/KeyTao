#!/usr/bin/env bash
set -euo pipefail

LUAC=$(command -v luac 2>/dev/null || ls /nix/store/*/bin/luac 2>/dev/null | grep "lua-5\." | sort -V | tail -1)
DEPLOYER=$(command -v rime_deployer 2>/dev/null || ls /nix/store/*/bin/rime_deployer 2>/dev/null | sort -V | tail -1)
# RIME_SHARED can be set externally (nix devShell / CI); otherwise auto-detect
if [ -z "${RIME_SHARED:-}" ]; then
    RIME_SHARED=$(ls -d /nix/store/*/share/rime-data 2>/dev/null | grep fcitx5-rime | sort -V | tail -1 || true)
fi
[ -z "${RIME_SHARED:-}" ] && RIME_SHARED=/usr/share/rime-data
SHARED=$RIME_SHARED

REPO=$(cd "$(dirname "$0")/.." && pwd)
TMPROOT=$(mktemp -d)
trap 'rm -rf "$TMPROOT"' EXIT

# ── 1. Lua syntax ────────────────────────────────────────────────────────────
echo "=== 1. Lua syntax check ==="
LUA_FAIL=0
for f in "$REPO/rime/lua/"*.lua; do
    result=$("$LUAC" -p "$f" 2>&1) \
        && echo "  OK   $(basename "$f")" \
        || { echo "  FAIL $(basename "$f") — $result"; LUA_FAIL=1; }
done
[ $LUA_FAIL -eq 0 ] && echo "All Lua files OK" || { echo "Lua syntax errors found"; exit 1; }

# ── 2. Schema compile ────────────────────────────────────────────────────────
echo ""
echo "=== 2. Schema compile (rime_deployer --build) ==="
WORK="$TMPROOT/keytao"
cp -r "$REPO/rime" "$WORK"
if ! output=$("$DEPLOYER" --build "$WORK" "$SHARED" "$WORK/build" 2>&1) || grep -qE "^E[0-9]" <<<"$output"; then
    echo "  FAIL keytao"
    sed 's/^/       /' <<<"$output"
    exit 1
fi
bins=$(find "$WORK/build" -maxdepth 1 -name '*.bin' | wc -l | tr -d ' ')
echo "  OK   keytao — $bins .bin files"

# ── 3. xnumber self-check ────────────────────────────────────────────────────
echo ""
echo "=== 3. xnumber self-check ==="
(cd "$REPO" && "${LUAC%/*}/lua" scripts/test_xnumber.lua)
