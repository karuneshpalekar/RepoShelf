#!/bin/bash
# Regenerates RepoShelf.xcodeproj from project.yml.
#
# xcodegen writes objectVersion=77 (the Xcode 16+ project format), which
# crashes Xcode 15.x the moment you open Signing & Capabilities. We don't
# use any object types that require the newer format, so downgrade it to
# 56 (Xcode 14/15's format) after generating. Harmless on newer Xcode.
set -euo pipefail
cd "$(dirname "$0")"

xcodegen generate
sed -i '' \
  -e 's/objectVersion = 77;/objectVersion = 56;/' \
  -e 's/preferredProjectObjectVersion = 77;/preferredProjectObjectVersion = 56;/' \
  RepoShelf.xcodeproj/project.pbxproj

echo "Generated RepoShelf.xcodeproj (objectVersion downgraded for Xcode 15.x compatibility)."
