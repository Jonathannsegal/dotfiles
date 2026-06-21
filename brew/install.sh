#!/usr/bin/env bash

set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
BREWFILE="$DOTFILES/brew/Brewfile"
HARD_SETUP="${DOTFILES_HARD_SETUP:-false}"

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

configure_homebrew_shellenv() {
    local brew_bin=""
    local profile="$HOME/.zprofile"
    local tmp
    local block_start="# >>> dotfiles homebrew shellenv >>>"
    local block_end="# <<< dotfiles homebrew shellenv <<<"

    if [[ -x "/opt/homebrew/bin/brew" ]]; then
        brew_bin="/opt/homebrew/bin/brew"
    elif [[ -x "/usr/local/bin/brew" ]]; then
        brew_bin="/usr/local/bin/brew"
    else
        return 0
    fi

    eval "$("$brew_bin" shellenv)"

    tmp="$(mktemp)"
    if [[ -f "$profile" ]]; then
        awk -v start="$block_start" -v end="$block_end" '
            $0 == start { skipping = 1; next }
            $0 == end { skipping = 0; next }
            $0 ~ /^eval "\$\(\/opt\/homebrew\/bin\/brew shellenv\)"$/ { next }
            $0 ~ /^eval "\$\(\/usr\/local\/bin\/brew shellenv\)"$/ { next }
            skipping != 1 { print }
        ' "$profile" > "$tmp"
    fi

    {
        echo "$block_start"
        printf 'eval "$(%s shellenv)"\n' "$brew_bin"
        echo "$block_end"
    } >> "$tmp"

    if [[ "$HARD_SETUP" == false && -f "$profile" ]] && cmp -s "$tmp" "$profile"; then
        rm -f "$tmp"
    else
        mv "$tmp" "$profile"
    fi
}

if ! command -v brew >/dev/null 2>&1; then
    if [[ "$(uname -s)" != "Darwin" ]]; then
        echo "Homebrew is not installed and this helper only bootstraps Homebrew on macOS."
        exit 1
    fi

    if [[ "$(uname -m)" != "arm64" ]]; then
        echo "This Mac is not reporting Apple Silicon arm64. Rosetta will not be installed by this script."
    fi

    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

configure_homebrew_shellenv

command -v brew >/dev/null 2>&1 || {
    echo "Homebrew installation did not put brew on PATH."
    exit 1
}

if [[ "$HARD_SETUP" == false ]] && brew bundle check --file="$BREWFILE" >/dev/null 2>&1; then
    echo "Homebrew bundle is already satisfied."
else
    brew bundle --file="$BREWFILE"
fi
