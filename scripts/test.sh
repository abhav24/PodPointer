#!/bin/bash
# Runs the unit tests. Command Line Tools installs without Xcode need the path
# to the Swift Testing macro plugin passed in by hand.
set -euo pipefail

cd "$(dirname "$0")/.."

developer_dir="$(xcode-select -p)"
plugins="$developer_dir/usr/lib/swift/host/plugins/testing"
if [[ "$developer_dir" == *CommandLineTools* && -f "$plugins/libTestingMacros.dylib" ]]; then
    swift test -Xswiftc -plugin-path -Xswiftc "$plugins" "$@"
else
    swift test "$@"
fi
