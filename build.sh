#!/bin/bash
# Build build/ClaudeNotify.app (ad-hoc signed).
set -euo pipefail
cd "$(dirname "$0")"
APP=build/ClaudeNotify.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
# The deployment target must be explicit: Xcode's default can be newer than the running
# macOS, in which case launching fails with LaunchServices error -10825.
xcrun swiftc -O -target "$(uname -m)-apple-macos13" \
  -o "$APP/Contents/MacOS/ClaudeNotify" src/main.swift \
  -framework Cocoa -framework UserNotifications
cp src/Info.plist "$APP/Contents/Info.plist"
cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$APP"
echo "built: $APP"
