#!/usr/bin/env bash

setup_eza() {
    # Install shell completions if not already installed
    local COMPLETIONS_DIR="$HOME/.zsh/completions"
    mkdir -p "$COMPLETIONS_DIR"
    
    if [ ! -f "$COMPLETIONS_DIR/_eza" ]; then
        echo "Installing eza completions..."
        curl -L https://raw.githubusercontent.com/eza-community/eza/main/completions/zsh/_eza \
            -o "$COMPLETIONS_DIR/_eza"
    fi
    
    # Ensure completions directory is in FPATH
    if [[ ! "$FPATH" == *"$COMPLETIONS_DIR"* ]]; then
        echo "Adding completions to FPATH..."
        echo "export FPATH=\"$COMPLETIONS_DIR:\$FPATH\"" >> "$HOME/.zshrc"
    fi
    
    success "eza configured successfully"
}
