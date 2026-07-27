#!/usr/bin/env bash

set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
TAP_NAME="jsegal/local"
SOURCE_DIR="$DOTFILES/brew/Casks"

command -v brew >/dev/null 2>&1 || {
    echo "Homebrew is required to configure the local cask tap."
    exit 1
}

if ! brew tap | grep -Fxq "$TAP_NAME"; then
    HOMEBREW_NO_AUTO_UPDATE=1 brew tap-new "$TAP_NAME" >/dev/null
fi

TAP_DIR="$(brew --repository "$TAP_NAME")"
mkdir -p "$TAP_DIR/Casks"

for source in "$SOURCE_DIR"/*.rb; do
    target="$TAP_DIR/Casks/$(basename "$source")"
    if [[ ! -f "$target" ]] || ! cmp -s "$source" "$target"; then
        cp "$source" "$target"
    fi
done
