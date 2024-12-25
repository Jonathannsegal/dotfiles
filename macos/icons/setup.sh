#!/bin/bash

# Check if fileicon is installed
if ! command -v fileicon &> /dev/null; then
    echo "Installing fileicon..."
    brew install fileicon
fi

# Directory containing this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Icons directory is now nested one level deeper
ICONS_DIR="$SCRIPT_DIR/icons"

# Function to apply icon to application
apply_app_icon() {
    local icon="$1"
    local app_path="$2"
    local app_name="$3"

    if [ ! -f "$icon" ]; then
        echo "Error: Icon file not found: $icon"
        echo "Please place $icon in the $ICONS_DIR directory"
        return 1
    fi

    if [ ! -e "$app_path" ]; then
        echo "Error: Application not found: $app_path"
        return 1
    fi

    echo "Applying icon from $icon to $app_path..."
    
    # Quit the application if it's running
    osascript -e "tell application \"$app_name\" to quit" 2>/dev/null
    
    # Wait a moment for the app to fully quit
    sleep 2
    
    # Apply the icon
    fileicon set "$app_path" "$icon"
    
    # Remove the app from the dock
    osascript -e "tell application \"Dock\" to delete (dock item \"$app_path\")" 2>/dev/null
    
    # Wait a moment
    sleep 1
    
    # Add the app back to the dock
    osascript -e "tell application \"Dock\" to add POSIX file \"$app_path\" to persistent entries" 2>/dev/null
}

# Function to check permissions
check_permissions() {
    if ! sudo -n true 2>/dev/null; then
        echo "This script requires sudo privileges to clear icon caches."
        echo "You will be prompted for your password."
    fi

    # Check if Terminal has Full Disk Access
    if ! sudo touch /private/var/folders/test_permission 2>/dev/null; then
        echo "Error: Terminal needs Full Disk Access to modify icon cache."
        echo "Please grant Terminal.app Full Disk Access in System Settings > Privacy & Security > Full Disk Access"
        return 1
    fi
    sudo rm -f /private/var/folders/test_permission 2>/dev/null
}

# Function to clear icon cache and refresh Finder
clear_icon_cache_and_refresh() {
    echo "Clearing icon cache and refreshing Finder..."
    
    # Clear icon services cache
    sudo rm -rf /Library/Caches/com.apple.iconservices.store 2>/dev/null
    
    # Find and remove icon service folders
    sudo find /private/var/folders/ -name com.apple.iconservices -exec rm -rf {} \; 2>/dev/null
    
    # Restart Dock and Finder
    killall Dock 2>/dev/null
    killall Finder 2>/dev/null
    
    echo "Icon cache cleared and Finder refreshed!"
}

# Function to prompt for icon customization
prompt_for_customization() {
    if [[ "$1" != "--no-prompt" ]]; then
        echo " [ ?? ] Do you want to customize application icons? (y/n)"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo " [ OK ] Skipping icon customization"
            exit 0
        fi
        echo " [ .. ] running icon setup script"
    fi
}

# Main execution
prompt_for_customization "$1"

# Check permissions first
check_permissions || exit 1

# Customize Slack icon
SLACK_APP="/Applications/Slack.app"
if [ -d "$SLACK_APP" ]; then
    apply_app_icon "$ICONS_DIR/slack.png" "$SLACK_APP" "Slack"
    echo "Would you like to relaunch Slack now? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        open -a Slack
    fi
else
    echo "Slack is not installed in /Applications"
fi

# Clear icon cache and refresh Finder after applying all icons
clear_icon_cache_and_refresh

# Final Dock refresh to ensure changes take effect
killall Dock 2>/dev/null

echo " [ OK ] Icon setup complete!"