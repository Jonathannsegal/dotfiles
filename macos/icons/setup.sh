#!/bin/bash

set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

AUTO_MODE=false
SKIP_PRIVILEGED=false
CLEAR_CACHE=true
APPLIED_ANY=false
FORCE_ICON_APPLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto)
            AUTO_MODE=true
            SKIP_PRIVILEGED=true
            CLEAR_CACHE=false
            shift
            ;;
        --skip-privileged)
            SKIP_PRIVILEGED=true
            shift
            ;;
        --no-cache-clear)
            CLEAR_CACHE=false
            shift
            ;;
        --force)
            FORCE_ICON_APPLY=true
            shift
            ;;
        --help|-h)
            echo "Usage: setup.sh [--auto] [--skip-privileged] [--no-cache-clear] [--force]"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Skipping icon setup outside macOS"
    exit 0
fi

if ! command -v fileicon >/dev/null 2>&1; then
    if [[ "$AUTO_MODE" == true ]]; then
        echo "Skipping icon setup because fileicon is not available in auto mode"
        exit 0
    fi

    if ! command -v brew >/dev/null 2>&1; then
        echo "Homebrew is required to install fileicon"
        exit 1
    fi

    echo "Installing fileicon..."
    brew install fileicon
fi

# Directory containing icons
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ICONS_DIR="$SCRIPT_DIR/icons"

# Function to apply icon
apply_icon() {
    local app_path="$1"
    local icon_path="$2"
    
    if [ -e "$app_path" ] && [ -f "$icon_path" ]; then
        if [[ "$FORCE_ICON_APPLY" == false ]] && fileicon test "$app_path" >/dev/null 2>&1; then
            echo "Skipping $app_path (custom icon already set)"
            return 0
        fi

        echo "Applying $icon_path to $app_path"
        # Privileged apps may require elevated permissions.
        if [[ "$app_path" == *"Adobe"* ]] || [[ "$app_path" == "/System/"* ]] || [[ "$app_path" == *"zoom.us.app"* ]] || [[ "$app_path" == *"Xcode.app"* ]]; then
            if [[ "$SKIP_PRIVILEGED" == true ]]; then
                echo "Skipping privileged app in auto mode: $app_path"
            else
                sudo fileicon set "$app_path" "$icon_path"
                APPLIED_ANY=true
            fi
        else
            fileicon set "$app_path" "$icon_path"
            APPLIED_ANY=true
        fi
    else
        echo "Skipping $app_path (app or icon not found)"
    fi
}

apply_first_found() {
    local icon_path="$1"
    shift

    local candidate
    for candidate in "$@"; do
        if [[ -e "$candidate" ]]; then
            apply_icon "$candidate" "$icon_path"
            return 0
        fi
    done

    echo "Skipping $(basename "$icon_path" .png) (app not found)"
}

# Apply icons
apply_icon "/Applications/Google Chrome.app" "$ICONS_DIR/chrome.png"

# Resolve Adobe Illustrator path dynamically (handles different yearly versions)
shopt -s nullglob
ILLUSTRATOR_CANDIDATES=(/Applications/Adobe\ Illustrator*/Adobe\ Illustrator*.app)
shopt -u nullglob
if [ ${#ILLUSTRATOR_CANDIDATES[@]} -gt 0 ]; then
    apply_icon "${ILLUSTRATOR_CANDIDATES[0]}" "$ICONS_DIR/illustrator.png"
else
    echo "Skipping Adobe Illustrator (app not found)"
fi
apply_icon "/Applications/iTerm.app" "$ICONS_DIR/iterm2.png"
apply_icon "/Applications/Adobe Lightroom Classic/Adobe Lightroom Classic.app" "$ICONS_DIR/lightroom.png"
apply_icon "/Applications/Notion.app" "$ICONS_DIR/notion.png"
apply_icon "/Applications/Slack.app" "$ICONS_DIR/slack.png"
apply_icon "/Applications/Unity Hub.app" "$ICONS_DIR/unityhub.png"
apply_icon "/Applications/Visual Studio Code.app" "$ICONS_DIR/vscode.png"
apply_icon "/Applications/zoom.us.app" "$ICONS_DIR/zoom.png"
apply_first_found "$ICONS_DIR/zotero.png" "/Applications/Zotero.app" "/Applications/zotero.app"
apply_icon "/Applications/ATLAS.ti.app" "$ICONS_DIR/atlasti.png"
apply_icon "/Applications/Blender.app" "$ICONS_DIR/blender.png"
apply_icon "/Applications/Lens Studio.app" "$ICONS_DIR/lense.png"
apply_icon "/Applications/Xcode.app" "$ICONS_DIR/xcode.png"
apply_first_found "$ICONS_DIR/messages.png" "/System/Applications/Messages.app" "/Applications/Messages.app"
apply_first_found "$ICONS_DIR/mail.png" "/System/Applications/Mail.app" "/Applications/Mail.app"
apply_first_found "$ICONS_DIR/photos.png" "/System/Applications/Photos.app" "/Applications/Photos.app"
apply_first_found "$ICONS_DIR/facetime.png" "/System/Applications/FaceTime.app" "/Applications/FaceTime.app"

if [[ "$CLEAR_CACHE" == true && "$APPLIED_ANY" == true ]]; then
    # Clear icon cache with sudo
    echo "Clearing icon cache..."
    sudo rm -rf /Library/Caches/com.apple.iconservices.store
    sudo find /private/var/folders/ \
        -name com.apple.iconservices -exec sudo rm -rf {} \; 2>/dev/null

    # Restart Finder to refresh icons
    killall Finder
else
    echo "Skipping cache clear"
fi

echo "Icon setup complete!"
