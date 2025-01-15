#!/usr/bin/env bash

setup_iterm2() {
    echo "Configuring iTerm2 settings..."
    
    # Install shell integration if not already installed
    if [ ! -f "$HOME/.iterm2_shell_integration.zsh" ]; then
        echo "Installing shell integration..."
        curl -L https://iterm2.com/shell_integration/zsh \
            -o "$HOME/.iterm2_shell_integration.zsh"
    fi
    
    # Install utilities
    if [ ! -d "$HOME/.iterm2" ]; then
        echo "Installing iTerm2 utilities..."
        mkdir -p "$HOME/.iterm2"
        curl -L https://iterm2.com/utilities/it2check \
            -o "$HOME/.iterm2/it2check"
        curl -L https://iterm2.com/utilities/imgcat \
            -o "$HOME/.iterm2/imgcat"
        chmod +x "$HOME/.iterm2/it2check" "$HOME/.iterm2/imgcat"
    fi
    
    success "iTerm2 configured successfully"
}