#!/bin/bash
set -e

cd "$(dirname "$0")/.."

VERSION=${1:-v0.0.0-test}

echo "Building KeyTao packages, version: $VERSION"

rm -rf release/
mkdir -p release/keytao-linux release/keytao-mac release/keytao-windows release/keytao-android release/keytao-ios

cp -r rime/* release/keytao-linux/
cp -r schema/desktop/* release/keytao-linux/
(cd release/keytao-linux && zip -qr ../keytao-linux-${VERSION}.zip .)
echo "✓ linux"

cp -r rime/* release/keytao-mac/
cp -r schema/desktop/* release/keytao-mac/
cp -r schema/mac/* release/keytao-mac/
(cd release/keytao-mac && zip -qr ../keytao-mac-${VERSION}.zip .)
echo "✓ mac"

cp -r rime/* release/keytao-windows/
cp -r schema/desktop/* release/keytao-windows/
cp -r schema/windows/* release/keytao-windows/
(cd release/keytao-windows && zip -qr ../keytao-windows-${VERSION}.zip .)
echo "✓ windows"

cp -r rime/* release/keytao-android/
cp -r schema/android/* release/keytao-android/
(cd release/keytao-android && zip -qr ../keytao-android-${VERSION}.zip .)
echo "✓ android"

# iOS (Hamster) requires both desktop schema and its own skin file
cp -r rime/* release/keytao-ios/
cp -r schema/desktop/* release/keytao-ios/
cp -r schema/ios/* release/keytao-ios/
(cd release/keytao-ios && zip -qr ../keytao-ios-${VERSION}.zip .)
echo "✓ ios"

echo ""
cd release && sha256sum keytao-*.zip
