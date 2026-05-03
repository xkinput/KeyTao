#!/usr/bin/env bash
# Compile scripts/mem_bench.cc using the librime from nix develop.
# Run directly — auto-enters nix develop if needed.
#
# Usage:
#   bash scripts/build_mem_bench.sh
set -euo pipefail

if [ -z "${IN_NIX_SHELL:-}" ]; then
    REPO=$(cd "$(dirname "$0")/.." && pwd)
    exec nix develop "$REPO" --command bash "$0" "$@"
fi

REPO=$(cd "$(dirname "$0")/.." && pwd)
SRC="$REPO/scripts/mem_bench.cc"
OUT="$REPO/scripts/mem_bench"

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
    -Wl,-rpath,"${LIBRIME}lib" \
    -o "$OUT"

echo "OK  →  scripts/mem_bench"
