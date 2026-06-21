#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."
DOTFILES="$(pwd -P)"
export DOTFILES

BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"
BREWFILE="$DOTFILES/brew/Brewfile"
RUN_BREW=true
RUN_MACOS=true
ASK_MACOS=true
RUN_TERMINAL=true
RUN_PYTHON=true
RUN_VSCODE=true
RUN_ICONS=true
RUN_SHELL_PLUGINS=true
RUN_JDK=true
RUN_INSTALLER_GUARD=true
INSTALL_ICON_AGENT=true
ASSUME_YES=false
BACKUP_EXISTING=true

info() {
    printf "\r [ \033[00;34m..\033[0m ] %s\n" "$1"
}

success() {
    printf "\r\033[2K [ \033[00;32mOK\033[0m ] %s\n" "$1"
}

warn() {
    printf "\r\033[2K [ \033[00;33mWARN\033[0m ] %s\n" "$1"
}

fail() {
    printf "\r\033[2K [\033[0;31mFAIL\033[0m] %s\n" "$1"
    exit 1
}

usage() {
    cat <<EOF
Usage: ./run/setup.sh [options]

Repeatable macOS bootstrap for this dotfiles repo.

Options:
  --yes             Run non-interactively where possible.
  --no-brew         Skip Homebrew installation and brew bundle.
  --no-icons        Skip custom application icons.
  --no-icon-agent   Do not install the LaunchAgent that reapplies icons.
  --macos           Apply macOS defaults without prompting.
  --no-macos        Skip macOS defaults.
  --terminal        Import Terminal.app profiles. This is the default.
  --no-terminal     Skip Terminal.app profile import.
  --python          Run the Python package installer. This is the default.
  --no-python       Skip the Python package installer.
  --no-vscode       Skip VS Code extension installation.
  --no-shell-plugins
                    Skip zsh plugin installation/update.
  --no-jdk          Skip the Homebrew OpenJDK system link.
  --no-installer-guard
                    Skip the LaunchAgent that blocks unmanaged installers.
  --no-backup       Replace conflicting dotfiles instead of backing them up.
  -h, --help        Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes|-y) ASSUME_YES=true ;;
        --no-brew) RUN_BREW=false ;;
        --no-icons) RUN_ICONS=false ;;
        --no-icon-agent) INSTALL_ICON_AGENT=false ;;
        --macos) RUN_MACOS=true; ASK_MACOS=false ;;
        --no-macos) RUN_MACOS=false; ASK_MACOS=false ;;
        --terminal) RUN_TERMINAL=true ;;
        --no-terminal) RUN_TERMINAL=false ;;
        --python) RUN_PYTHON=true ;;
        --no-python) RUN_PYTHON=false ;;
        --no-vscode) RUN_VSCODE=false ;;
        --no-shell-plugins) RUN_SHELL_PLUGINS=false ;;
        --no-jdk) RUN_JDK=false ;;
        --no-installer-guard) RUN_INSTALLER_GUARD=false ;;
        --no-backup) BACKUP_EXISTING=false ;;
        --help|-h) usage; exit 0 ;;
        *) fail "Unknown option: $1" ;;
    esac
    shift
done

is_macos() {
    [[ "$(uname -s)" == "Darwin" ]]
}

confirm() {
    local prompt="$1"

    if [[ "$ASSUME_YES" == true ]]; then
        return 0
    fi

    printf "\r [ \033[0;33m??\033[0m ] %s [y/N] " "$prompt"
    read -r reply < /dev/tty
    [[ "$reply" =~ ^[Yy]$ ]]
}

confirm_yes() {
    local prompt="$1"

    if [[ "$ASSUME_YES" == true ]]; then
        return 0
    fi

    printf "\r [ \033[0;33m??\033[0m ] %s [Y/n] " "$prompt"
    read -r reply < /dev/tty
    [[ -z "$reply" || "$reply" =~ ^[Yy]$ ]]
}

strip_quotes() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    value="${value%\"}"
    value="${value#\"}"
    printf "%s" "$value"
}

expand_path() {
    local value
    value="$(strip_quotes "$1")"
    value="${value//\$DOTFILES/$DOTFILES}"
    value="${value//\$HOME/$HOME}"
    value="${value/#\~/$HOME}"
    printf "%s" "$value"
}

link_file() {
    local src="$1"
    local dst="$2"

    if [[ ! -e "$src" && ! -L "$src" ]]; then
        warn "Skipping missing source: $src"
        return 0
    fi

    mkdir -p "$(dirname "$dst")"

    if [[ -L "$dst" ]]; then
        local current
        current="$(readlink "$dst")"
        if [[ "$current" == "$src" ]]; then
            success "Already linked $dst"
            return 0
        fi
    fi

    if [[ -e "$dst" || -L "$dst" ]]; then
        if [[ "$BACKUP_EXISTING" == true ]]; then
            local backup_path="$BACKUP_DIR${dst#$HOME}"
            mkdir -p "$(dirname "$backup_path")"
            mv "$dst" "$backup_path"
            success "Backed up $dst"
        else
            rm -rf "$dst"
            success "Removed existing $dst"
        fi
    fi

    ln -s "$src" "$dst"
    success "Linked $dst"
}

install_dotfiles() {
    info "Linking dotfiles"

    while IFS= read -r linkfile; do
        info "Processing $(basename "$(dirname "$linkfile")") links"

        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            [[ "$line" != *"="* ]] && {
                warn "Ignoring invalid link line in $linkfile: $line"
                continue
            }

            local src_raw="${line%%=*}"
            local dst_raw="${line#*=}"
            local src dst
            src="$(expand_path "$src_raw")"
            dst="$(expand_path "$dst_raw")"
            link_file "$src" "$dst"
        done < "$linkfile"
    done < <(find -H "$DOTFILES" -maxdepth 2 -name "links.prop" -not -path "*/.git/*" | sort)
}

create_env_file() {
    if [[ -f "$HOME/.env.sh" ]]; then
        local tmp
        tmp="$(mktemp)"
        awk -v dotfiles="$DOTFILES" '
            BEGIN { updated = 0 }
            /^export DOTFILES=/ {
                print "export DOTFILES=\"" dotfiles "\""
                updated = 1
                next
            }
            { print }
            END {
                if (updated == 0) {
                    print ""
                    print "export DOTFILES=\"" dotfiles "\""
                }
            }
        ' "$HOME/.env.sh" > "$tmp"
        mv "$tmp" "$HOME/.env.sh"
        success "Updated ~/.env.sh"
        return 0
    fi

    cat > "$HOME/.env.sh" <<EOF
# Environment variables for dotfiles
export DOTFILES="$DOTFILES"

# Add machine-specific configuration below.

source_if_exists() {
    if test -r "\$1"; then
        source "\$1"
    fi
}
EOF
    success "Created ~/.env.sh"
}

ensure_homebrew() {
    export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

    if command -v brew >/dev/null 2>&1; then
        success "Homebrew is installed"
        return 0
    fi

    if ! is_macos; then
        fail "Homebrew is not installed and this setup only bootstraps Homebrew on macOS"
    fi

    if [[ "$(uname -m)" != "arm64" ]]; then
        warn "This Mac is not reporting Apple Silicon arm64. No Rosetta setup will be attempted."
    fi

    info "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [[ -x "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x "/usr/local/bin/brew" ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    command -v brew >/dev/null 2>&1 || fail "Homebrew installation did not put brew on PATH"
    success "Homebrew installed"
}

install_brew_bundle() {
    [[ "$RUN_BREW" == true ]] || {
        success "Skipped Homebrew"
        return 0
    }

    ensure_homebrew
    [[ -f "$BREWFILE" ]] || fail "Missing Brewfile: $BREWFILE"

    info "Installing/updating Homebrew bundle"
    brew bundle --file="$BREWFILE"
    success "Homebrew bundle is up to date"
}

setup_shell_plugins() {
    [[ "$RUN_SHELL_PLUGINS" == true ]] || {
        success "Skipped shell plugins"
        return 0
    }

    local plugin_dir="$HOME/.zsh/plugins"
    mkdir -p "$plugin_dir"

    if [[ ! -d "$plugin_dir/zsh-syntax-highlighting/.git" ]]; then
        info "Installing zsh-syntax-highlighting"
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugin_dir/zsh-syntax-highlighting"
    else
        git -C "$plugin_dir/zsh-syntax-highlighting" pull --ff-only >/dev/null 2>&1 || warn "Could not update zsh-syntax-highlighting"
    fi

    if [[ ! -d "$plugin_dir/zsh-autosuggestions/.git" ]]; then
        info "Installing zsh-autosuggestions"
        git clone https://github.com/zsh-users/zsh-autosuggestions.git "$plugin_dir/zsh-autosuggestions"
    else
        git -C "$plugin_dir/zsh-autosuggestions" pull --ff-only >/dev/null 2>&1 || warn "Could not update zsh-autosuggestions"
    fi

    success "Shell plugins are installed"
}

setup_jdk() {
    [[ "$RUN_JDK" == true ]] || {
        success "Skipped OpenJDK system link"
        return 0
    }

    if ! is_macos || [[ ! -d "/opt/homebrew/opt/openjdk/libexec/openjdk.jdk" ]]; then
        return 0
    fi

    local target="/Library/Java/JavaVirtualMachines/openjdk.jdk"
    if [[ -L "$target" && "$(readlink "$target")" == "/opt/homebrew/opt/openjdk/libexec/openjdk.jdk" ]]; then
        success "OpenJDK is linked"
        return 0
    fi

    if confirm "Link Homebrew OpenJDK into /Library/Java/JavaVirtualMachines?"; then
        sudo ln -sfn /opt/homebrew/opt/openjdk/libexec/openjdk.jdk "$target"
        success "OpenJDK linked"
    else
        warn "Skipped OpenJDK system link"
    fi
}

setup_vscode() {
    [[ "$RUN_VSCODE" == true ]] || {
        success "Skipped VS Code extensions"
        return 0
    }

    if [[ -x "$DOTFILES/vscode/install.sh" ]]; then
        bash "$DOTFILES/vscode/install.sh"
    else
        warn "VS Code installer not executable or missing"
    fi
}

setup_icons() {
    [[ "$RUN_ICONS" == true ]] || {
        success "Skipped custom icons"
        return 0
    }

    if ! is_macos; then
        success "Skipped custom icons outside macOS"
        return 0
    fi

    bash "$DOTFILES/macos/icons/setup.sh"

    if [[ "$INSTALL_ICON_AGENT" == true ]]; then
        bash "$DOTFILES/macos/icons/install_auto_reapply.sh"
    fi
}

setup_installer_guard() {
    [[ "$RUN_INSTALLER_GUARD" == true ]] || {
        success "Skipped installer guard"
        return 0
    }

    if ! is_macos; then
        success "Skipped installer guard outside macOS"
        return 0
    fi

    bash "$DOTFILES/macos/installer-guard.sh" install
    success "Installer guard configured"
}

setup_terminal() {
    [[ "$RUN_TERMINAL" == true ]] || return 0
    is_macos || {
        success "Skipped Terminal.app settings outside macOS"
        return 0
    }

    # shellcheck source=/dev/null
    source "$DOTFILES/terminal/settings.sh"
    setup_terminal_profiles
    setup_theme_switcher
}

setup_python() {
    [[ "$RUN_PYTHON" == true ]] || return 0
    bash "$DOTFILES/python/install.sh" --no-confirm
}

setup_macos() {
    [[ "$RUN_MACOS" == true ]] || return 0
    is_macos || {
        success "Skipped macOS defaults outside macOS"
        return 0
    }

    if [[ "$ASK_MACOS" == true ]] && ! confirm_yes "Apply macOS defaults from macos/settings.sh?"; then
        warn "Skipped macOS defaults"
        return 0
    fi

    bash "$DOTFILES/macos/settings.sh"
}

main() {
    create_env_file
    install_dotfiles
    install_brew_bundle
    setup_shell_plugins
    setup_jdk
    setup_vscode
    setup_terminal
    setup_python
    setup_macos
    setup_installer_guard
    setup_icons
    success "Setup complete"
}

main "$@"
