#!/bin/bash
# Runs the unit tests. Command Line Tools installs without Xcode need the path
# to the Swift Testing macro plugin passed in by hand.
set -euo pipefail

cd "$(dirname "$0")/.."

plugins="$(xcode-select -p)/usr/lib/swift/host/plugins/testing"
if [[ -f "$plugins/libTestingMacros.dylib" && "$(xcode-select -p)" == *CommandLineTools* ]]; then
    swift test -Xswiftc -plugin-path -Xswiftc "$plugins" "$@"
else
    swift test "$@"
fi
