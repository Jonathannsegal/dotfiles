#!/usr/bin/env bash

set -euo pipefail

PICTOGRAM_APP="/Applications/Pictogram.app"
PICTOGRAM_BUNDLE_ID="com.NeilSardesai.Pictogram"
CUSTOM_ICONS_DIR="${HOME}/Library/Application Support/${PICTOGRAM_BUNDLE_ID}/Custom Icons"
LEGACY_LABEL="com.jsegal.dotfiles-icons-reapply"
LEGACY_AGENT_PLIST="${HOME}/Library/LaunchAgents/${LEGACY_LABEL}.plist"
LEGACY_DAEMON_PLIST="/Library/LaunchDaemons/${LEGACY_LABEL}.plist"
LEGACY_INSTALL_ROOT="/Library/Application Support/DotfilesIcons"
LEGACY_LOG="/Library/Logs/${LEGACY_LABEL}.log"
DOTFILES_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ICONS_DIR="${DOTFILES_ROOT}/macos/icons/icons"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Skipping automatic icon helper outside macOS"
  exit 0
fi

if [[ ! -d "$PICTOGRAM_APP" ]]; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is required to install Pictogram"
    exit 1
  fi

  echo "Installing Pictogram..."
  brew install --cask pictogram
fi

mkdir -p "$CUSTOM_ICONS_DIR"

register_icon() {
  local app_path="$1"
  local icon_path="$2"
  local bundle_id

  [[ -d "$app_path" && -f "$icon_path" ]] || return 0
  bundle_id="$(defaults read "$app_path/Contents/Info" CFBundleIdentifier 2>/dev/null || true)"
  [[ -n "$bundle_id" ]] || {
    echo "Skipping Pictogram registration for $app_path (bundle identifier not found)"
    return 0
  }

  install -m 0644 "$icon_path" "${CUSTOM_ICONS_DIR}/${bundle_id}"
  echo "Registered persistent icon for $app_path"
}

register_first_found() {
  local icon_path="$1"
  shift

  local candidate
  for candidate in "$@"; do
    if [[ -d "$candidate" ]]; then
      register_icon "$candidate" "$icon_path"
      return 0
    fi
  done
}

register_icon "/Applications/Google Chrome.app" "$ICONS_DIR/chrome.png"

shopt -s nullglob
ILLUSTRATOR_CANDIDATES=(/Applications/Adobe\ Illustrator*/Adobe\ Illustrator*.app)
shopt -u nullglob
if [[ ${#ILLUSTRATOR_CANDIDATES[@]} -gt 0 ]]; then
  register_icon "${ILLUSTRATOR_CANDIDATES[0]}" "$ICONS_DIR/illustrator.png"
fi

register_icon "/Applications/iTerm.app" "$ICONS_DIR/iterm2.png"
register_icon "/Applications/Adobe Lightroom Classic/Adobe Lightroom Classic.app" "$ICONS_DIR/lightroom.png"
register_icon "/Applications/Notion.app" "$ICONS_DIR/notion.png"
register_icon "/Applications/Slack.app" "$ICONS_DIR/slack.png"
register_icon "/Applications/Unity Hub.app" "$ICONS_DIR/unityhub.png"
register_icon "/Applications/Visual Studio Code.app" "$ICONS_DIR/vscode.png"
register_icon "/Applications/zoom.us.app" "$ICONS_DIR/zoom.png"
register_first_found "$ICONS_DIR/zotero.png" "/Applications/Zotero.app" "/Applications/zotero.app"
register_icon "/Applications/ATLAS.ti.app" "$ICONS_DIR/atlasti.png"
register_icon "/Applications/Blender.app" "$ICONS_DIR/blender.png"
register_icon "/Applications/Lens Studio.app" "$ICONS_DIR/lense.png"
register_icon "/Applications/Xcode.app" "$ICONS_DIR/xcode.png"

# Launching Pictogram once registers its signed background login helper. It is
# hidden and placed in the background so setup does not interrupt the user.
open -gj -a Pictogram
sleep 2

TCC_DB="${HOME}/Library/Application Support/com.apple.TCC/TCC.db"
APP_MANAGEMENT_AUTH=""
if [[ -r "$TCC_DB" ]]; then
  APP_MANAGEMENT_AUTH="$(sqlite3 "$TCC_DB" \
    "SELECT auth_value FROM access WHERE service = 'kTCCServiceSystemPolicyAppBundles' AND client = '${PICTOGRAM_BUNDLE_ID}' ORDER BY last_modified DESC LIMIT 1;" \
    2>/dev/null || true)"
fi

if [[ "$APP_MANAGEMENT_AUTH" != "2" ]]; then
  echo "Pictogram needs approval in Privacy & Security > App Management."
  open "x-apple.systempreferences:com.apple.preference.security?AppManagement"
  echo "Turn on Pictogram there so its login helper can restore icons after updates."
fi

# Remove the old shell watchers. macOS App Management blocks unattended shell
# jobs from editing apps even when the job runs as root; Pictogram's signed
# login helper is the supported persistence path.
launchctl bootout "gui/$(id -u)/${LEGACY_LABEL}" >/dev/null 2>&1 || true
rm -f "$LEGACY_AGENT_PLIST"

if [[ -e "$LEGACY_DAEMON_PLIST" || -e "$LEGACY_INSTALL_ROOT" || -e "$LEGACY_LOG" ]]; then
  if ! sudo -n true >/dev/null 2>&1; then
    echo "Administrator permission is required to remove the obsolete icon daemon."
    sudo -v
  fi
  sudo launchctl bootout "system/${LEGACY_LABEL}" >/dev/null 2>&1 || true
  sudo rm -f "$LEGACY_DAEMON_PLIST" "$LEGACY_LOG"
  sudo rm -rf "$LEGACY_INSTALL_ROOT"
fi

echo "Pictogram icon persistence is configured."
echo "Mappings: ${CUSTOM_ICONS_DIR}"
