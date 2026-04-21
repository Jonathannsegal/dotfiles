#!/usr/bin/env bash

set -euo pipefail

LABEL="com.jsegal.dotfiles-icons-reapply"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"
DOTFILES_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT_PATH="${DOTFILES_ROOT}/macos/icons/setup.sh"

mkdir -p "${HOME}/Library/LaunchAgents"

cat > "$PLIST_PATH" <<EOF
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
  </array>

  <key>StandardOutPath</key>
  <string>${HOME}/Library/Logs/${LABEL}.log</string>
  <key>StandardErrorPath</key>
  <string>${HOME}/Library/Logs/${LABEL}.log</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH"
launchctl kickstart -k "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true

echo "Installed and started: ${LABEL}"
echo "Plist: ${PLIST_PATH}"
echo "Log: ${HOME}/Library/Logs/${LABEL}.log"
