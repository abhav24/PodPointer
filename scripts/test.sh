#!/bin/bash
# Runs the unit tests. Command Line Tools installs without Xcode need the path
# to the Swift Testing macro plugin passed in by hand.
set -euo pipefail

cd "$(dirname "$0")/.."

