#!/usr/bin/env bash

setup_terminal_profiles() {
    echo "Installing Terminal profiles..."
    
    # First list and remove all existing profiles
    echo "Removing existing profiles..."
    profiles_list=$(sudo profiles -P | grep -B1 "Terminal" | grep "attribute" | awk '{print $4}')
    
    while IFS= read -r profile_id; do
        if [ ! -z "$profile_id" ]; then
            echo "Removing profile: $profile_id"
            sudo profiles -R -p "$profile_id"
        fi
    done <<< "$profiles_list"
    
    # Install new profiles
    open "$DOTFILES/terminal/profiles/Dark.terminal"
    sleep 1  # Give Terminal time to process the first profile
    open "$DOTFILES/terminal/profiles/Light.terminal"
    sleep 1  # Give Terminal time to process the second profile
    
    # Set Dark as default profile
    defaults write com.apple.Terminal "Default Window Settings" -string "Dark"
    defaults write com.apple.Terminal "Startup Window Settings" -string "Dark"
    
    # Verify remaining profiles
    echo "Verifying profiles..."
    sudo profiles -P
    
    # Kill Terminal to apply changes
    echo "Restarting Terminal to apply changes..."
    killall Terminal &>/dev/null || true
    
    echo "Terminal profiles configured successfully"
}

setup_theme_switcher() {
    local launch_agent="$HOME/Library/LaunchAgents/com.user.terminal-theme.plist"
    # Create LaunchAgent for theme switching
    cat > "$launch_agent" << EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.terminal-theme</string>
    <key>ProgramArguments</key>
    <array>
        <string>$HOME/.config/terminal/switch-theme.sh</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>$HOME/Library/Preferences/.GlobalPreferences.plist</string>
    </array>
</dict>
</plist>
EOL
    # Load the LaunchAgent
    launchctl unload "$launch_agent" 2>/dev/null || true
    launchctl load "$launch_agent"
}