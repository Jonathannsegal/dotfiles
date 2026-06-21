#!/usr/bin/env bash

set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
BREWFILE="$DOTFILES/brew/Brewfile"
HARD_SETUP="${DOTFILES_HARD_SETUP:-false}"

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

installed_extensions="$("$CODE_CMD" --list-extensions | sort)"

while IFS= read -r extension; do
    [[ -n "$extension" ]] || continue
    if [[ "$HARD_SETUP" == false ]] && printf "%s\n" "$installed_extensions" | grep -Fxq "$extension"; then
        print_success "$extension is already installed"
    else
        install_args=(--install-extension "$extension")
        if [[ "$HARD_SETUP" == true ]]; then
            install_args+=(--force)
        fi

        "$CODE_CMD" "${install_args[@]}" >/dev/null
        print_success "Installed $extension"
    fi
done < <(sed -n 's/^vscode "\([^"]*\)".*/\1/p' "$BREWFILE")

print_success "VS Code extensions are up to date"
