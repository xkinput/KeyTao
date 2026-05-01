#!/usr/bin/env bash
set -euo pipefail

LUAC=$(command -v luac 2>/dev/null || ls /nix/store/*/bin/luac 2>/dev/null | grep "lua-5\." | sort -V | tail -1)
DEPLOYER=$(command -v rime_deployer 2>/dev/null || ls /nix/store/*/bin/rime_deployer 2>/dev/null | sort -V | tail -1)
# RIME_SHARED can be set externally (nix devShell / CI); otherwise auto-detect
if [ -z "${RIME_SHARED:-}" ]; then
    RIME_SHARED=$(ls -d /nix/store/*/share/rime-data 2>/dev/null | grep fcitx5-rime | sort -V | tail -1)
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

# ── 2. Platform schema compile ───────────────────────────────────────────────
echo ""
echo "=== 2. Schema compile per platform (rime_deployer --build) ==="

PASS=0
FAIL_COUNT=0

compile() {
    local name=$1; shift
    local work="$TMPROOT/$name"
    mkdir -p "$work"
    for src in "$@"; do
        cp -r "$src"/. "$work/"
    done

    local output
    output=$("$DEPLOYER" --build "$work" "$SHARED" "$work/build" 2>&1)

    if echo "$output" | grep -qE "^E[0-9]"; then
        echo "  FAIL $name"
        echo "$output" | grep "^E" | sed 's/^/       /'
        FAIL_COUNT=$((FAIL_COUNT + 1))
    else
        local bins
        bins=$(ls "$work/build/"*.bin 2>/dev/null | wc -l)
        echo "  OK   $name — $bins .bin files"
        PASS=$((PASS + 1))
    fi
}

RIME="$REPO/rime"
DESKTOP="$REPO/schema/desktop"

compile "linux"   "$RIME" "$DESKTOP"
compile "mac"     "$RIME" "$DESKTOP" "$REPO/schema/mac"
compile "windows" "$RIME" "$DESKTOP" "$REPO/schema/windows"
compile "android" "$RIME" "$REPO/schema/android"
compile "ios"     "$RIME" "$DESKTOP" "$REPO/schema/ios"

echo ""
echo "Results: $PASS passed, $FAIL_COUNT failed"
[ $FAIL_COUNT -eq 0 ] || exit 1
