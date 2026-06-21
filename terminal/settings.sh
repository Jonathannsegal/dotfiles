#!/usr/bin/env bash

hard_setup_enabled() {
    [[ "${DOTFILES_HARD_SETUP:-false}" == true ]]
}

setup_terminal_profiles() {
    if ! hard_setup_enabled &&
       defaults read com.apple.Terminal "Window Settings" 2>/dev/null | grep -q '^[[:space:]]*Dark =' &&
       defaults read com.apple.Terminal "Window Settings" 2>/dev/null | grep -q '^[[:space:]]*Light =' &&
       [[ "$(defaults read com.apple.Terminal "Default Window Settings" 2>/dev/null || true)" == "Dark" ]] &&
       [[ "$(defaults read com.apple.Terminal "Startup Window Settings" 2>/dev/null || true)" == "Dark" ]]; then
        echo "Terminal profiles are already configured"
        return 0
    fi

    echo "Installing Terminal profiles..."

    # Install new profiles
    open "$DOTFILES/terminal/profiles/Dark.terminal"
    sleep 1  # Give Terminal time to process the first profile
    open "$DOTFILES/terminal/profiles/Light.terminal"
    sleep 1  # Give Terminal time to process the second profile
    
    # Set Dark as default profile
    defaults write com.apple.Terminal "Default Window Settings" -string "Dark"
    defaults write com.apple.Terminal "Startup Window Settings" -string "Dark"
    
    # Kill Terminal to apply changes
    echo "Restarting Terminal to apply changes..."
    killall Terminal &>/dev/null || true
    
    echo "Terminal profiles configured successfully"
}

setup_theme_switcher() {
    local launch_agent="$HOME/Library/LaunchAgents/com.user.terminal-theme.plist"
    local tmp
    mkdir -p "$(dirname "$launch_agent")"

    # Create LaunchAgent for theme switching
    tmp="$(mktemp)"
    cat > "$tmp" << EOL
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

    if ! hard_setup_enabled &&
       [[ -f "$launch_agent" ]] && cmp -s "$tmp" "$launch_agent" &&
       launchctl print "gui/$(id -u)/com.user.terminal-theme" >/dev/null 2>&1; then
        rm -f "$tmp"
        echo "Terminal theme switcher is already configured"
        return 0
    fi

    mv "$tmp" "$launch_agent"
    launchctl bootout "gui/$(id -u)/com.user.terminal-theme" >/dev/null 2>&1 || true
    launchctl bootstrap "gui/$(id -u)" "$launch_agent"
}
