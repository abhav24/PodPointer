#!/bin/bash
# Builds build/PodPointer.app.
#
# macOS only shows the motion permission to a real app bundle, so `swift run`
# isn't enough. This script signs with the first Apple Development certificate
# it finds, or CODESIGN_IDENTITY if set. Without a certificate it signs ad hoc,
