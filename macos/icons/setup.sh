#!/bin/bash

# Install fileicon if not present
if ! command -v fileicon &> /dev/null; then
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
        echo "Applying $icon_path to $app_path"
        # Use sudo for Adobe applications and System applications
        if [[ "$app_path" == *"Adobe"* ]] || [[ "$app_path" == "/System/"* ]] || [[ "$app_path" == *"zoom.us.app"* ]]; then
            sudo fileicon set "$app_path" "$icon_path"
        else
            fileicon set "$app_path" "$icon_path"
        fi
    else
        echo "Skipping $app_path (app or icon not found)"
    fi
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
apply_icon "/Applications/zotero.app" "$ICONS_DIR/zotero.png"
apply_icon "/Applications/ATLAS.ti.app" "$ICONS_DIR/atlasti.png"

# Clear icon cache with sudo
echo "Clearing icon cache..."
sudo rm -rf /Library/Caches/com.apple.iconservices.store
sudo find /private/var/folders/ \
    -name com.apple.iconservices -exec sudo rm -rf {} \; 2>/dev/null

# Restart Finder to refresh icons
killall Finder

echo "Icon setup complete!"