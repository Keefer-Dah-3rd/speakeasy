#!/bin/bash
# Builds Speakeasy.app into ./build
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="build/Speakeasy.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Speakeasy "$APP/Contents/MacOS/Speakeasy"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then
  cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

# Sign with the Apple Development certificate when there is one, so macOS keeps
# the Microphone and Accessibility permissions from one build to the next.
# Without it the app still runs, but permissions must be re-granted after a rebuild.
IDENTITY="$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ {print $2; exit}')"
if [ -n "$IDENTITY" ] && perl -e 'alarm 90; exec @ARGV' codesign --force --sign "$IDENTITY" "$APP" 2>/dev/null; then
  echo "Signed with your Apple Development certificate"
else
  codesign --force --sign - "$APP"
  echo "Signed ad hoc (no certificate used)"
fi

echo "Built $APP"
