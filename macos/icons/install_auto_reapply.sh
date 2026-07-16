#!/usr/bin/env bash

set -euo pipefail

LABEL="com.jsegal.dotfiles-icons-reapply"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"
DOTFILES_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT_PATH="${DOTFILES_ROOT}/macos/icons/setup.sh"
TMP_PLIST="$(mktemp)"
HARD_SETUP="${DOTFILES_HARD_SETUP:-false}"

# Watch the bundle internals used by in-place updaters (including VS Code's),
# not only /Applications. The icon script's auto mode skips apps whose custom
# icon is still present, so an update only repairs the app that lost its icon.
MANAGED_APP_PATHS=(
  "/Applications/Google Chrome.app"
  "/Applications/iTerm.app"
  "/Applications/Adobe Lightroom Classic/Adobe Lightroom Classic.app"
  "/Applications/Notion.app"
  "/Applications/Slack.app"
  "/Applications/Unity Hub.app"
  "/Applications/Visual Studio Code.app"
  "/Applications/zoom.us.app"
  "/Applications/Zotero.app"
  "/Applications/zotero.app"
  "/Applications/ATLAS.ti.app"
  "/Applications/Blender.app"
  "/Applications/Lens Studio.app"
  "/Applications/Xcode.app"
  "/System/Applications/Messages.app"
  "/System/Applications/Mail.app"
  "/System/Applications/Photos.app"
  "/System/Applications/FaceTime.app"
)

shopt -s nullglob
for illustrator_path in /Applications/Adobe\ Illustrator*/Adobe\ Illustrator*.app; do
  MANAGED_APP_PATHS+=("$illustrator_path")
done
shopt -u nullglob

mkdir -p "${HOME}/Library/LaunchAgents"

cat > "$TMP_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-lc</string>
    <string>${SCRIPT_PATH} --auto</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>StartInterval</key>
  <integer>21600</integer>

  <key>WatchPaths</key>
  <array>
    <string>/Applications</string>
EOF

for app_path in "${MANAGED_APP_PATHS[@]}"; do
  for watch_path in \
    "$app_path" \
    "$app_path/Contents" \
    "$app_path/Contents/Info.plist" \
    "$app_path/Contents/Resources"; do
    printf '    <string>%s</string>\n' "$watch_path" >> "$TMP_PLIST"
  done
done

cat >> "$TMP_PLIST" <<EOF
  </array>

  <key>ThrottleInterval</key>
  <integer>10</integer>

  <key>StandardOutPath</key>
  <string>${HOME}/Library/Logs/${LABEL}.log</string>
  <key>StandardErrorPath</key>
  <string>${HOME}/Library/Logs/${LABEL}.log</string>
</dict>
</plist>
EOF

if [[ "$HARD_SETUP" == false && -f "$PLIST_PATH" ]] && cmp -s "$TMP_PLIST" "$PLIST_PATH" &&
   launchctl print "gui/$(id -u)/${LABEL}" >/dev/null 2>&1; then
  rm -f "$TMP_PLIST"
  echo "Already installed and started: ${LABEL}"
  echo "Plist: ${PLIST_PATH}"
  echo "Log: ${HOME}/Library/Logs/${LABEL}.log"
  exit 0
fi

mv "$TMP_PLIST" "$PLIST_PATH"
launchctl bootout "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH"
launchctl kickstart -k "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true

echo "Installed and started: ${LABEL}"
echo "Plist: ${PLIST_PATH}"
echo "Log: ${HOME}/Library/Logs/${LABEL}.log"
