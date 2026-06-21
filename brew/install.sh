#!/usr/bin/env bash

set -euo pipefail

DOTFILES="${DOTFILES:-$(cd "$(dirname "$0")/.." && pwd)}"
BREWFILE="$DOTFILES/brew/Brewfile"

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

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

if [[ -x "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x "/usr/local/bin/brew" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

command -v brew >/dev/null 2>&1 || {
    echo "Homebrew installation did not put brew on PATH."
    exit 1
}

brew bundle --file="$BREWFILE"
