#!/usr/bin/env bash

set -euo pipefail

LABEL="com.jsegal.dotfiles-icons-reapply"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"
DOTFILES_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT_PATH="${DOTFILES_ROOT}/macos/icons/setup.sh"
TMP_PLIST="$(mktemp)"
HARD_SETUP="${DOTFILES_HARD_SETUP:-false}"

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
    <string>${SCRIPT_PATH} --auto --force</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>StartInterval</key>
  <integer>21600</integer>

  <key>WatchPaths</key>
  <array>
    <string>/Applications</string>
    <string>/Applications/Google Chrome.app</string>
    <string>/Applications/Google Chrome.app/Contents</string>
    <string>/Applications/Google Chrome.app/Contents/Info.plist</string>
    <string>/Applications/Google Chrome.app/Contents/Resources</string>
  </array>

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
