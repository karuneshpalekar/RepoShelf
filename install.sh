#!/bin/bash
# Builds a Release version and installs it to /Applications, bypassing
# Xcode's GUI entirely (Xcode 15.3 crashes when opening Signing &
# Capabilities; command-line builds are unaffected).
#
# Run this after making code changes to rebuild and reinstall.
set -euo pipefail
cd "$(dirname "$0")"

./generate.sh

xcodebuild -project RepoShelf.xcodeproj -scheme RepoShelf \
  -configuration Release -destination 'platform=macOS' -allowProvisioningUpdates build

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -iname 'RepoShelf-*' -print -quit)/Build/Products/Release/RepoShelf.app

rm -rf /Applications/RepoShelf.app
cp -R "$APP_PATH" /Applications/
xattr -dr com.apple.quarantine /Applications/RepoShelf.app 2>/dev/null || true

killall RepoShelf 2>/dev/null || true
open /Applications/RepoShelf.app

echo "Installed and launched /Applications/RepoShelf.app"
echo "Look for the shelf/box icon in your menu bar."
