#!/usr/bin/env bash
set -euo pipefail
# Migrate away from the periodic agent. The interactive shell now triggers checks.
launchctl bootout "gui/$(id -u)/com.jsegal.dotfiles-health" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/com.jsegal.dotfiles-health.plist"
echo 'Health check configured: first interactive terminal each day, in the background.'
