#!/bin/bash
# Builds Speakeasy, installs it in /Applications, and gives it a launcher:
# a Dock icon and a shortcut on the Desktop. Safe to run again after changes;
# it replaces the installed app and leaves the Dock and Desktop alone if the
# icons are already there.
set -euo pipefail
cd "$(dirname "$0")"

./build.sh

APP="/Applications/Speakeasy.app"

# Quit the running copy so the new one can replace it.
if pgrep -x Speakeasy >/dev/null; then
  osascript -e 'quit app id "local.speakeasy.Speakeasy"' 2>/dev/null || pkill -x Speakeasy || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -x Speakeasy >/dev/null || break; sleep 0.3; done
fi

rm -rf "$APP"
ditto build/Speakeasy.app "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
echo "Installed $APP"

# Dock icon, next to the other apps.
if ! defaults read com.apple.dock persistent-apps 2>/dev/null | grep -q "Speakeasy.app"; then
  defaults write com.apple.dock persistent-apps -array-add \
    "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>file://$APP/</string><key>_CFURLStringType</key><integer>15</integer></dict></dict></dict>"
  killall Dock
  echo "Added Speakeasy to the Dock"
fi

# Desktop shortcut. A Finder alias when Finder allows it, otherwise a link.
SHORTCUT="$HOME/Desktop/Speakeasy"
if [ ! -e "$SHORTCUT" ] && [ ! -L "$SHORTCUT" ]; then
  if ! osascript -e "tell application \"Finder\" to make alias file to (POSIX file \"$APP\" as alias) at (POSIX file \"$HOME/Desktop\" as alias) with properties {name:\"Speakeasy\"}" >/dev/null 2>&1; then
    ln -s "$APP" "$SHORTCUT"
  fi
  echo "Added a Speakeasy shortcut to the Desktop"
fi

open "$APP"
