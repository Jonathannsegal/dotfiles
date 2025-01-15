#!/usr/bin/env bash

setup_tmux() {
    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
        echo "Installing tmux plugin manager..."
        git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    fi
    
    success "tmux configured successfully"
}
