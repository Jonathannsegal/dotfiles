#!/usr/bin/env bash

setup_alder() {
    # Install alder globally using npm
    if ! command -v alder &> /dev/null; then
        echo "Installing alder globally..."
        npm install -g @aweary/alder
    fi
    
    success "alder configured successfully"
}