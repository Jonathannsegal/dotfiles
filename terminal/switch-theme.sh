#!/usr/bin/env bash

set -euo pipefail

if defaults read -globalDomain AppleInterfaceStyle >/dev/null 2>&1; then
    defaults write com.apple.Terminal "Default Window Settings" -string "Dark"
    defaults write com.apple.Terminal "Startup Window Settings" -string "Dark"
else
    defaults write com.apple.Terminal "Default Window Settings" -string "Light"
    defaults write com.apple.Terminal "Startup Window Settings" -string "Light"
fi
