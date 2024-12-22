#!/usr/bin/env bash

VSCODE_SETTINGS_DIR="$HOME/Library/Application Support/Code/User"
PYTHON_VERSION=$(cat "$HOME/.python-version")

print_status() {
    printf "\r [ \033[00;34m..\033[0m ] $1\n"
}

print_success() {
    printf "\r\033[2K [ \033[00;32mOK\033[0m ] $1\n"
}

print_error() {
    printf "\r\033[2K [\033[0;31mFAIL\033[0m] $1\n"
}

# Create VSCode settings directory if it doesn't exist
mkdir -p "$VSCODE_SETTINGS_DIR"

# Generate settings.json with the current Python version
print_status "Configuring VSCode Python settings..."
cat > "$VSCODE_SETTINGS_DIR/settings.json" <<EOF
{
    "python.defaultInterpreterPath": "$HOME/.pyenv/versions/$PYTHON_VERSION/bin/python",
    "python.ignoreSystemPython": true
}
EOF

if [ $? -eq 0 ]; then
    print_success "VSCode Python settings configured successfully"
else
    print_error "Failed to configure VSCode Python settings"
    exit 1
fi