#!/usr/bin/env bash

set -euo pipefail

DOTFILES="${DOTFILES:-$(cd "$(dirname "$0")/.." && pwd)}"
BREWFILE="$DOTFILES/brew/Brewfile"

print_status() {
    printf "\r [ \033[00;34m..\033[0m ] %s\n" "$1"
}

print_success() {
    printf "\r\033[2K [ \033[00;32mOK\033[0m ] %s\n" "$1"
}

print_warning() {
    printf "\r\033[2K [ \033[00;33mWARN\033[0m ] %s\n" "$1"
}

find_code() {
    if command -v code >/dev/null 2>&1; then
        CODE_CMD="code"
        return 0
    fi

    local app_code="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
    if [[ -x "$app_code" ]]; then
        CODE_CMD="$app_code"
        return 0
    fi

    return 1
}

if ! find_code; then
    print_warning "VS Code command not found; skipping extension installation"
    exit 0
fi

if [[ ! -f "$BREWFILE" ]]; then
    print_warning "Brewfile not found; skipping VS Code extension installation"
    exit 0
fi

print_status "Installing VS Code extensions from Brewfile"

while IFS= read -r extension; do
    [[ -n "$extension" ]] || continue
    "$CODE_CMD" --install-extension "$extension" --force >/dev/null
    print_success "Installed/updated $extension"
done < <(sed -n 's/^vscode "\([^"]*\)".*/\1/p' "$BREWFILE")

print_success "VS Code extensions are up to date"
