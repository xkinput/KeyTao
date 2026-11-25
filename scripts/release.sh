#!/bin/bash
set -e

cd "$(dirname "$0")/.."

RAW_VERSION=${1:-0.0.0-test}
case "$RAW_VERSION" in
	v*) VERSION="$RAW_VERSION" ;;
	*) VERSION="v$RAW_VERSION" ;;
esac

echo "Building KeyTao package, version: $VERSION"

rm -rf release/
mkdir -p release/keytao

printf '%s\n' "$VERSION" > release/keytao/version.txt
cp -r rime/* release/keytao/
cp -r schema/*.yaml release/keytao/
(cd release/keytao && zip -qr "../keytao-${VERSION}.zip" .)
echo "✓ keytao-${VERSION}.zip"
