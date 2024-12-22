#!/bin/bash

SLACK_CONFIG_DIR="$HOME/Library/Application Support/Slack"
SLACK_BACKUP_DIR="$HOME/.dotfiles/slack/config"
THEME_COLORS="#252A2D,#F4F5F7,#87FFD9,#FF7477"

# Create backup directory if it doesn't exist
mkdir -p "$SLACK_BACKUP_DIR"

# Backup current Slack settings if they exist
if [ -d "$SLACK_CONFIG_DIR" ]; then
    echo "Backing up current Slack settings..."
    cp -R "$SLACK_CONFIG_DIR/storage" "$SLACK_BACKUP_DIR/"
    cp -R "$SLACK_CONFIG_DIR/settings.json" "$SLACK_BACKUP_DIR/" 2>/dev/null
fi

# Set default Slack preferences
setup_slack_preferences() {
    # Create settings directory if it doesn't exist
    mkdir -p "$SLACK_CONFIG_DIR"
    
    # Set global preferences
    defaults write com.slack.Slack SlackThemeMode -string "system"
    defaults write com.slack.Slack DarkerSidebars -bool true
    defaults write com.slack.Slack WindowGradient -bool true
    
    # Update theme for all workspaces
    local storage_dir="$SLACK_CONFIG_DIR/storage"
    if [ -d "$storage_dir" ]; then
        # Find all workspace config files
        find "$storage_dir" -name "config.json" | while read -r config_file; do
            if [ -f "$config_file" ]; then
                echo "Updating theme for workspace config: $config_file"
                # Create temp file
                temp_file=$(mktemp)
                # Update theme in config file
                jq --arg theme "$THEME_COLORS" '.theme.colors = $theme' "$config_file" > "$temp_file"
                mv "$temp_file" "$config_file"
            fi
        done
    fi
    
    echo "Slack preferences have been configured."
}

# Check if jq is installed
check_dependencies() {
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is required but not installed. Please install it first:"
        echo "brew install jq"
        exit 1
    fi
}

# Main setup
main() {
    echo "Setting up Slack configuration..."
    check_dependencies
    setup_slack_preferences
    
    # Restart Slack if it's running
    if pgrep -x "Slack" > /dev/null; then
        echo "Restarting Slack to apply changes..."
        killall Slack
        open -a Slack
    fi
    
    echo "Slack setup completed!"
}

main