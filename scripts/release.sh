#!/bin/bash
set -e

cd "$(dirname "$0")/.."

RAW_VERSION=${1:-0.0.0-test}
case "$RAW_VERSION" in
	v*) VERSION="$RAW_VERSION" ;;
	*) VERSION="v$RAW_VERSION" ;;
esac

echo "Building KeyTao packages, version: $VERSION"

rm -rf release/
mkdir -p release/keytao-linux release/keytao-mac release/keytao-windows release/keytao-android release/keytao-ios

write_version_file() {
	printf '%s\n' "$VERSION" > "$1/version.txt"
}

cp -r rime/* release/keytao-linux/
cp -r schema/desktop/* release/keytao-linux/
write_version_file release/keytao-linux
(cd release/keytao-linux && zip -qr ../keytao-linux-${VERSION}.zip .)
echo "✓ linux"

cp -r rime/* release/keytao-mac/
cp -r schema/desktop/* release/keytao-mac/
cp -r schema/mac/* release/keytao-mac/
write_version_file release/keytao-mac
(cd release/keytao-mac && zip -qr ../keytao-mac-${VERSION}.zip .)
echo "✓ mac"

cp -r rime/* release/keytao-windows/
cp -r schema/desktop/* release/keytao-windows/
cp -r schema/windows/* release/keytao-windows/
write_version_file release/keytao-windows
(cd release/keytao-windows && zip -qr ../keytao-windows-${VERSION}.zip .)
echo "✓ windows"

cp -r rime/* release/keytao-android/
cp -r schema/android/* release/keytao-android/
write_version_file release/keytao-android
(cd release/keytao-android && zip -qr ../keytao-android-${VERSION}.zip .)
echo "✓ android"

# iOS (Hamster) requires both desktop schema and its own skin file
cp -r rime/* release/keytao-ios/
cp -r schema/ios/* release/keytao-ios/
write_version_file release/keytao-ios
(cd release/keytao-ios && zip -qr ../keytao-ios-${VERSION}.zip .)
echo "✓ ios"

echo ""
cd release && sha256sum keytao-*.zip | tee checksums.txt
