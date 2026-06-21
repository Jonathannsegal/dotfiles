#!/usr/bin/env bash

set -euo pipefail

LABEL="com.jsegal.dotfiles-installer-guard"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"
DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_PATH="${DOTFILES}/macos/installer-guard.sh"
BLOCK_DIR="${HOME}/CleanupStaging/blocked-installers"
LOG_FILE="${HOME}/Library/Logs/${LABEL}.log"

usage() {
  cat <<EOF
Usage: $(basename "$0") [scan|install|uninstall|status]

Blocks unmanaged app installers from common inbox locations. Install apps by
adding them to brew/Brewfile and running ./run/setup.sh or brew bundle.

Commands:
  scan       Move installer files out of ~/Downloads and ~/Desktop.
  install    Install and start the LaunchAgent.
  uninstall  Remove the LaunchAgent.
  status     Show LaunchAgent status.
EOF
}

notify_user() {
  local item="$1"
  local dest="$2"
  local message

  message="Moved $(basename "$item") to $(dirname "$dest"). Add the app to brew/Brewfile and install with Homebrew."
  echo "$(date '+%Y-%m-%d %H:%M:%S') $message" >> "$LOG_FILE"

  if command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"${message//\"/\\\"}\" with title \"Installer blocked\"" >/dev/null 2>&1 || true
  fi
}

unique_dest() {
  local src="$1"
  local base dest suffix

  base="$(basename "$src")"
  dest="$BLOCK_DIR/$base"
  suffix=1

  while [[ -e "$dest" ]]; do
    dest="$BLOCK_DIR/${base}-${suffix}"
    suffix=$((suffix + 1))
  done

  printf "%s" "$dest"
}

block_item() {
  local src="$1"
  local dest

  [[ -e "$src" ]] || return 0
  mkdir -p "$BLOCK_DIR" "$(dirname "$LOG_FILE")"
  dest="$(unique_dest "$src")"
  mv "$src" "$dest"
  notify_user "$src" "$dest"
}

scan_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0

  find "$dir" -maxdepth 1 \
    \( -name "*.dmg" -o -name "*.pkg" -o -name "*.mpkg" -o -name "*.app" \) \
    -print0 2>/dev/null |
  while IFS= read -r -d '' item; do
    block_item "$item"
  done
}

scan_installers() {
  scan_dir "$HOME/Downloads"
  scan_dir "$HOME/Desktop"
}

install_agent() {
  mkdir -p "$HOME/Library/LaunchAgents" "$(dirname "$LOG_FILE")"

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
    <string>${SCRIPT_PATH}</string>
    <string>scan</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>StartInterval</key>
  <integer>15</integer>

  <key>WatchPaths</key>
  <array>
    <string>${HOME}/Downloads</string>
    <string>${HOME}/Desktop</string>
  </array>

  <key>StandardOutPath</key>
  <string>${LOG_FILE}</string>
  <key>StandardErrorPath</key>
  <string>${LOG_FILE}</string>
</dict>
</plist>
EOF

  launchctl bootout "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH"
  launchctl kickstart -k "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true

  echo "Installed and started: ${LABEL}"
  echo "Plist: ${PLIST_PATH}"
  echo "Blocked installers: ${BLOCK_DIR}"
  echo "Log: ${LOG_FILE}"
}

uninstall_agent() {
  launchctl bootout "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true
  rm -f "$PLIST_PATH"
  echo "Removed: ${LABEL}"
}

status_agent() {
  launchctl print "gui/$(id -u)/${LABEL}" 2>/dev/null || {
    echo "${LABEL} is not loaded"
    return 1
  }
}

case "${1:-scan}" in
  scan) scan_installers ;;
  install) install_agent ;;
  uninstall) uninstall_agent ;;
  status) status_agent ;;
  --help|-h|help) usage ;;
  *) usage; exit 1 ;;
esac
