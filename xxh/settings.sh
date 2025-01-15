#!/usr/bin/env bash

setup_xxh() {
    # Create xxh config directory if it doesn't exist
    mkdir -p "$HOME/.config/xxh"
    
    # Install common plugins
    xxh +I xxh-plugin-zsh-ohmyzsh
    xxh +I xxh-plugin-zsh-powerlevel10k
    xxh +I xxh-plugin-prerun-dotfiles
    xxh +I xxh-plugin-prerun-python
    
    # Configure default shell
    echo "Setting up xxh config..."
    cat > "$HOME/.config/xxh/config.xxhc" << EOF
hosts:
  ".*":  # Required for all hosts
    +s: zsh
EOF
    
    success "xxh configured successfully"
}