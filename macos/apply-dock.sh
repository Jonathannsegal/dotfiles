#!/usr/bin/env bash

set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
DOCK_ITEMS_FILE="${1:-$DOTFILES/macos/dock-items.txt}"

add_dock_app() {
  local app_path="$1"
  if [[ "$app_path" == "~/"* ]]; then
    app_path="$HOME/${app_path:2}"
  fi

  local file_url="file://${app_path%/}/"

  defaults write com.apple.dock persistent-apps -array-add \
    "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>${file_url}</string><key>_CFURLStringType</key><integer>15</integer></dict></dict></dict>"
}

if [[ ! -f "$DOCK_ITEMS_FILE" ]]; then
  echo "Dock items file not found: $DOCK_ITEMS_FILE" >&2
  exit 1
fi

defaults write com.apple.dock persistent-apps -array
defaults write com.apple.dock persistent-others -array

while IFS= read -r app_path || [[ -n "$app_path" ]]; do
  [[ -z "$app_path" || "$app_path" =~ ^[[:space:]]*# ]] && continue
  add_dock_app "$app_path"
done < "$DOCK_ITEMS_FILE"

killall Dock >/dev/null 2>&1 || true
