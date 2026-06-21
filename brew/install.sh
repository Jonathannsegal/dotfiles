#!/usr/bin/env bash

set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
BREWFILE="$DOTFILES/brew/Brewfile"
HARD_SETUP="${DOTFILES_HARD_SETUP:-false}"
SUDO_KEEPALIVE_PID=""

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
export NODE_NO_WARNINGS="${NODE_NO_WARNINGS:-1}"

stop_sudo_keepalive() {
    if [[ -n "$SUDO_KEEPALIVE_PID" ]]; then
        kill "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1 || true
    fi
}

trap stop_sudo_keepalive EXIT

ensure_sudo_keepalive() {
    if [[ "$(id -u)" -eq 0 ]]; then
        return 0
    fi

    command -v sudo >/dev/null 2>&1 || {
        echo "sudo is required for privileged Homebrew setup."
        exit 1
    }

    if [[ -n "$SUDO_KEEPALIVE_PID" ]] && kill -0 "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1; then
        return 0
    fi

    if ! sudo -n true >/dev/null 2>&1; then
        echo "Requesting administrator password once for Homebrew setup..."
        sudo -v
    fi

    while true; do
        sudo -n true >/dev/null 2>&1 || exit
        sleep 60
        kill -0 "$$" >/dev/null 2>&1 || exit
    done 2>/dev/null &
    SUDO_KEEPALIVE_PID="$!"
}

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

    ensure_sudo_keepalive
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
    ensure_sudo_keepalive
    brew bundle --file="$BREWFILE"
fi
