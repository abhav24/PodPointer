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
