#!/bin/bash
# Builds dist/PodPointer-v<version>.dmg, with the app and a link to Applications,
# then checks that the disk image opens and the app inside it is intact.
set -euo pipefail

cd "$(dirname "$0")/.."
