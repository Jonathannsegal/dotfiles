#!/usr/bin/env bash

setup_bat() {
    # Create bat config directory
    mkdir -p "$HOME/.config/bat/themes"
    
    # Build cache
    bat cache --build

    success "bat configured successfully"
}