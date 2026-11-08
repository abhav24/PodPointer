#!/bin/bash
# Builds build/PodPointer.app.
#
# macOS only shows the motion permission to a real app bundle, so `swift run`
# isn't enough. This script signs with the first Apple Development certificate
# it finds, or CODESIGN_IDENTITY if set. Without a certificate it signs ad hoc,
# and macOS may ask for permissions again after each rebuild.
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release
binary="$(swift build -c release --show-bin-path)/PodPointer"

app="build/PodPointer.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$binary" "$app/Contents/MacOS/PodPointer"
cp Resources/Info.plist "$app/Contents/Info.plist"

identity="${CODESIGN_IDENTITY:-}"
if [[ -z "$identity" ]]; then
    identity="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' | head -1)"
fi
identity="${identity:--}"

codesign --force --sign "$identity" "$app"
if [[ "$identity" == "-" ]]; then
    echo "Signed ad hoc."
else
    echo "Signed with an Apple Development certificate."
fi
echo "Built $app"
