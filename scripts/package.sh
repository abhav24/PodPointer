#!/bin/bash
# Builds dist/PodPointer-v<version>.dmg, with the app and a link to Applications,
# then checks that the disk image opens and the app inside it is intact.
set -euo pipefail

cd "$(dirname "$0")/.."

UNIVERSAL=1 scripts/build-app.sh

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
dmg="dist/PodPointer-v$version.dmg"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT

ditto build/PodPointer.app "$staging/PodPointer.app"
ln -s /Applications "$staging/Applications"

mkdir -p dist
rm -f "$dmg"
hdiutil create -quiet -volname "PodPointer" -srcfolder "$staging" -ov -format UDZO "$dmg"

mount="$staging/mount"
mkdir "$mount"
hdiutil attach -quiet -nobrowse -mountpoint "$mount" "$dmg"
trap 'hdiutil detach -quiet "$mount" || true; rm -rf "$staging"' EXIT
codesign --verify --deep --strict "$mount/PodPointer.app"
architectures="$(lipo -archs "$mount/PodPointer.app/Contents/MacOS/PodPointer")"
[[ "$architectures" == *arm64* && "$architectures" == *x86_64* ]]
test -f "$mount/PodPointer.app/Contents/Resources/AppIcon.icns"
test -L "$mount/Applications"

echo "Built and checked $dmg"
shasum -a 256 "$dmg"
