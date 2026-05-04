#!/usr/bin/env bash
# Compile scripts/rime_tui.cc (interactive Rime TUI with memory monitoring).
# Auto-enters nix develop if not already inside.
#
# Usage:
#   bash scripts/build_rime_tui.sh
set -euo pipefail

if [ -z "${IN_NIX_SHELL:-}" ]; then
    REPO=$(cd "$(dirname "$0")/.." && pwd)
    exec nix develop "$REPO" --command bash "$0" "$@"
fi

REPO=$(cd "$(dirname "$0")/.." && pwd)
SRC="$REPO/scripts/rime_tui.cc"
OUT="$REPO/scripts/rime_tui"

LIBRIME=$(ls -d /nix/store/*-librime-*/ 2>/dev/null \
    | grep -v keytao | sort -V | tail -1)

[ -n "$LIBRIME" ] || { echo "ERROR: librime not found in nix store"; exit 1; }
[ -f "$SRC" ]     || { echo "ERROR: $SRC not found"; exit 1; }

echo "librime : $LIBRIME"
echo "src     : $SRC"
echo "output  : $OUT"
echo ""

c++ -std=c++17 -O2 \
    -I"${LIBRIME}include" \
    "$SRC" \
    -L"${LIBRIME}lib" -lrime \
    -lncurses \
    -Wl,-rpath,"${LIBRIME}lib" \
    -o "$OUT"

echo "OK  →  scripts/rime_tui"
echo ""
echo "Run:"
echo "  scripts/rime_tui --user-data-dir rime/ [--schema keytao]"
