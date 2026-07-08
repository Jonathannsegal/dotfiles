#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."
DOTFILES="$(pwd -P)"
export DOTFILES
export NODE_NO_WARNINGS="${NODE_NO_WARNINGS:-1}"

if [[ "${1:-}" == "standards" ]]; then
    shift
    exec bash "$DOTFILES/run/.standards.sh" "$@"
fi

if [[ "${1:-}" == "icons" ]]; then
    shift
    install_icon_agent=true
    icon_args=(--force)
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                exec bash "$DOTFILES/macos/icons/setup.sh" --help
                ;;
            --no-icon-agent)
                install_icon_agent=false
                ;;
            *)
                icon_args+=("$1")
                ;;
        esac
        shift
    done

    bash "$DOTFILES/macos/icons/setup.sh" "${icon_args[@]}"
    if [[ "$install_icon_agent" == true ]]; then
        if [[ "$(uname -s)" == "Darwin" ]]; then
            DOTFILES_HARD_SETUP=true bash "$DOTFILES/macos/icons/install_auto_reapply.sh"
        else
            echo "Skipped icon LaunchAgent outside macOS"
        fi
    fi
    exit 0
fi

BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"
BREWFILE="$DOTFILES/brew/Brewfile"
RUN_BREW=true
RUN_MACOS=true
ASK_MACOS=true
RUN_TERMINAL=true
RUN_PYTHON=true
RUN_VSCODE=true
RUN_LENS_STUDIO=true
RUN_ICONS=true
RUN_SHELL_PLUGINS=true
RUN_JDK=true
RUN_INSTALLER_GUARD=true
RUN_STANDARDS=true
INSTALL_ICON_AGENT=true
ASSUME_YES=false
BACKUP_EXISTING=true
HARD_SETUP=false
SUDO_KEEPALIVE_PID=""

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
Usage:
  ./run/setup.sh [options]
  ./run/setup.sh standards <command> [options]
  ./run/setup.sh icons [icon-options]

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
  --no-lens-studio  Skip Snap Lens Studio install/update.
  --no-shell-plugins
                    Skip zsh plugin installation/update.
  --no-jdk          Skip the Homebrew OpenJDK system link.
  --no-installer-guard
                    Skip the LaunchAgent that blocks unmanaged installers.
  --no-standards    Skip applying enforceable clean-computer standards.
  --no-backup       Replace conflicting dotfiles instead of backing them up.
  --hard            Repair mode: overwrite managed dotfiles and re-run managed
                    installers/configuration even when already present.
  -h, --help        Show this help.

Icon-only setup:
  ./run/setup.sh icons
                    Reapply custom app icons without running the full setup.
                    Also refreshes the automatic icon LaunchAgent.
                    Extra icon-options are passed to macos/icons/setup.sh.
  ./run/setup.sh icons --no-icon-agent
                    Reapply icons without installing/reloading the LaunchAgent.
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
        --no-lens-studio) RUN_LENS_STUDIO=false ;;
        --no-shell-plugins) RUN_SHELL_PLUGINS=false ;;
        --no-jdk) RUN_JDK=false ;;
        --no-installer-guard) RUN_INSTALLER_GUARD=false ;;
        --no-standards) RUN_STANDARDS=false ;;
        --no-backup) BACKUP_EXISTING=false ;;
        --hard)
            HARD_SETUP=true
            ASSUME_YES=true
            ASK_MACOS=false
            BACKUP_EXISTING=false
            ;;
        --help|-h) usage; exit 0 ;;
        *) fail "Unknown option: $1" ;;
    esac
    shift
done

export DOTFILES_HARD_SETUP="$HARD_SETUP"

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

    command -v sudo >/dev/null 2>&1 || fail "sudo is required for this privileged setup step"

    if [[ -n "$SUDO_KEEPALIVE_PID" ]] && kill -0 "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1; then
        return 0
    fi

    if sudo -n true >/dev/null 2>&1; then
        success "Administrator credentials are already cached"
    else
        info "Requesting administrator password once for setup"
        sudo -v || fail "Administrator authentication failed"
        success "Administrator credentials cached"
    fi

    while true; do
        sudo -n true >/dev/null 2>&1 || exit
        sleep 60
        kill -0 "$$" >/dev/null 2>&1 || exit
    done 2>/dev/null &
    SUDO_KEEPALIVE_PID="$!"
}

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
        if [[ "$current" == "$src" && "$HARD_SETUP" == false ]]; then
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

        if [[ "$HARD_SETUP" == false ]] && cmp -s "$tmp" "$HOME/.env.sh"; then
            rm -f "$tmp"
            success "~/.env.sh is already configured"
        else
            mv "$tmp" "$HOME/.env.sh"
            success "Updated ~/.env.sh"
        fi
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
        success "Homebrew shellenv is already configured in ~/.zprofile"
    else
        mv "$tmp" "$profile"
        success "Homebrew shellenv is configured in ~/.zprofile"
    fi
}

ensure_homebrew() {
    export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

    if command -v brew >/dev/null 2>&1; then
        configure_homebrew_shellenv
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
    ensure_sudo_keepalive
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    configure_homebrew_shellenv

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

    if [[ "$HARD_SETUP" == false ]] && brew bundle check --file="$BREWFILE" >/dev/null 2>&1; then
        success "Homebrew bundle is already satisfied"
    else
        if [[ "$HARD_SETUP" == true ]]; then
            info "Running Homebrew bundle in repair mode"
        else
            info "Installing missing Homebrew bundle dependencies"
        fi
        if is_macos; then
            ensure_sudo_keepalive
        fi
        brew bundle --file="$BREWFILE"
        success "Homebrew bundle is up to date"
    fi
}

declutter_creative_cloud_apps() {
    is_macos || return 0

    local visible_app="/Applications/Utilities/Adobe Creative Cloud/ACC/Creative Cloud.app"
    local hidden_apps=(
        "/Applications/Utilities/Adobe Creative Cloud/ACC/Creative Cloud Helper.app"
        "/Applications/Utilities/Adobe Creative Cloud/Diagnostics/Adobe Creative Cloud Diagnostics.app"
        "/Applications/Utilities/Adobe Creative Cloud/Utils/Creative Cloud Desktop App.app"
        "/Applications/Utilities/Adobe Creative Cloud/Utils/Creative Cloud Installer.app"
        "/Applications/Utilities/Adobe Creative Cloud/Utils/Creative Cloud Uninstaller.app"
    )
    local changed=false
    local app

    for app in "${hidden_apps[@]}"; do
        [[ -d "$app" ]] || continue
        ensure_sudo_keepalive
        sudo chflags hidden "$app"
        changed=true
    done

    if [[ -d "$visible_app" ]]; then
        ensure_sudo_keepalive
        sudo chflags nohidden "$visible_app"
        changed=true
    fi

    if [[ "$changed" == true ]]; then
        success "Adobe Creative Cloud app search is decluttered"
    fi
}

setup_creative_cloud() {
    [[ "$RUN_BREW" == true ]] || return 0
    grep -q '^cask "adobe-creative-cloud"' "$BREWFILE" || return 0
    command -v brew >/dev/null 2>&1 || return 0

    local launcher="/Applications/Adobe Creative Cloud/Adobe Creative Cloud"
    local target="/Applications/Utilities/Adobe Creative Cloud/ACC/Creative Cloud.app"

    if brew list --cask adobe-creative-cloud >/dev/null 2>&1 &&
       [[ -e "$launcher" && -e "$target" ]]; then
        declutter_creative_cloud_apps
        success "Adobe Creative Cloud is installed"
        return 0
    fi

    info "Repairing Adobe Creative Cloud cask install"
    if is_macos; then
        ensure_sudo_keepalive
    fi

    if brew list --cask adobe-creative-cloud >/dev/null 2>&1; then
        brew reinstall --cask adobe-creative-cloud
    else
        brew install --cask adobe-creative-cloud
    fi

    if [[ -e "$launcher" && -e "$target" ]]; then
        declutter_creative_cloud_apps
        success "Adobe Creative Cloud installed"
    else
        warn "Adobe Creative Cloud cask ran, but the launcher was not found"
    fi
}

setup_shell_plugins() {
    [[ "$RUN_SHELL_PLUGINS" == true ]] || {
        success "Skipped shell plugins"
        return 0
    }

    local plugin_dir="$HOME/.zsh/plugins"
    mkdir -p "$plugin_dir"

    if [[ "$HARD_SETUP" == true && -e "$plugin_dir/zsh-syntax-highlighting" ]]; then
        rm -rf "$plugin_dir/zsh-syntax-highlighting"
    fi
    if [[ ! -d "$plugin_dir/zsh-syntax-highlighting/.git" ]]; then
        rm -rf "$plugin_dir/zsh-syntax-highlighting"
        info "Installing zsh-syntax-highlighting"
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugin_dir/zsh-syntax-highlighting"
    else
        success "zsh-syntax-highlighting is already installed"
    fi

    if [[ "$HARD_SETUP" == true && -e "$plugin_dir/zsh-autosuggestions" ]]; then
        rm -rf "$plugin_dir/zsh-autosuggestions"
    fi
    if [[ ! -d "$plugin_dir/zsh-autosuggestions/.git" ]]; then
        rm -rf "$plugin_dir/zsh-autosuggestions"
        info "Installing zsh-autosuggestions"
        git clone https://github.com/zsh-users/zsh-autosuggestions.git "$plugin_dir/zsh-autosuggestions"
    else
        success "zsh-autosuggestions is already installed"
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
    if [[ "$HARD_SETUP" == false && -L "$target" && "$(readlink "$target")" == "/opt/homebrew/opt/openjdk/libexec/openjdk.jdk" ]]; then
        success "OpenJDK is linked"
        return 0
    fi

    if [[ "$HARD_SETUP" == true && -e "$target" && ! -L "$target" ]]; then
        ensure_sudo_keepalive
        sudo rm -rf "$target"
    fi

    if confirm "Link Homebrew OpenJDK into /Library/Java/JavaVirtualMachines?"; then
        ensure_sudo_keepalive
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
        DOTFILES_HARD_SETUP="$HARD_SETUP" bash "$DOTFILES/vscode/install.sh"
    else
        warn "VS Code installer not executable or missing"
    fi
}

setup_lens_studio() {
    [[ "$RUN_LENS_STUDIO" == true ]] || {
        success "Skipped Lens Studio"
        return 0
    }

    is_macos || {
        success "Skipped Lens Studio outside macOS"
        return 0
    }

    if [[ "$HARD_SETUP" == true ]]; then
        bash "$DOTFILES/macos/lens-studio.sh" --force
    else
        bash "$DOTFILES/macos/lens-studio.sh"
    fi
}

setup_tailscale_app() {
    is_macos || {
        success "Skipped Tailscale app settings outside macOS"
        return 0
    }

    if [[ ! -d "/Applications/Tailscale.app" ]]; then
        success "Skipped Tailscale app settings"
        return 0
    fi

    defaults write io.tailscale.ipn.macsys HideDockIcon -bool true
    defaults write io.tailscale.ipn.macsys TailscaleStartOnLogin -bool false
    defaults write io.tailscale.ipn.macsys AppIntroShown -bool true
    defaults write io.tailscale.ipn.macsys OnboardingFlow -string hide
    defaults write io.tailscale.ipn.macsys OccludedIconAlertSuppressed -bool true

    success "Tailscale app settings configured"
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

    local icon_args=(--force)

    bash "$DOTFILES/macos/icons/setup.sh" "${icon_args[@]}"

    if [[ "$INSTALL_ICON_AGENT" == true ]]; then
        DOTFILES_HARD_SETUP="$HARD_SETUP" bash "$DOTFILES/macos/icons/install_auto_reapply.sh"
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

    DOTFILES_HARD_SETUP="$HARD_SETUP" bash "$DOTFILES/macos/installer-guard.sh" install
    success "Installer guard configured"
}

setup_standards() {
    [[ "$RUN_STANDARDS" == true ]] || {
        success "Skipped standards enforcement"
        return 0
    }

    info "Applying enforceable clean-computer standards"
    bash "$DOTFILES/run/.standards.sh" home --apply

    if is_macos; then
        bash "$DOTFILES/run/.standards.sh" launchagents apply
    fi

    bash "$DOTFILES/run/.standards.sh" purge-unwanted

    if bash "$DOTFILES/run/.standards.sh" audit >/dev/null 2>&1; then
        success "Standards audit passes"
    else
        warn "Standards audit still has review items; run ./run/setup.sh standards audit"
    fi
}

setup_terminal() {
    [[ "$RUN_TERMINAL" == true ]] || return 0
    is_macos || {
        success "Skipped terminal settings outside macOS"
        return 0
    }

    # shellcheck source=/dev/null
    source "$DOTFILES/terminal/settings.sh"
    setup_terminal_profiles
    setup_iterm_preferences
    setup_theme_switcher
}

setup_python() {
    [[ "$RUN_PYTHON" == true ]] || return 0
    DOTFILES_HARD_SETUP="$HARD_SETUP" bash "$DOTFILES/python/install.sh" --no-confirm
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

    if [[ "$HARD_SETUP" == false ]] && bash "$DOTFILES/run/.standards.sh" settings >/dev/null 2>&1; then
        success "macOS defaults already match"
    else
        ensure_sudo_keepalive
        bash "$DOTFILES/macos/settings.sh"
    fi
}

main() {
    create_env_file
    install_dotfiles
    install_brew_bundle
    setup_creative_cloud
    setup_lens_studio
    setup_tailscale_app
    setup_shell_plugins
    setup_jdk
    setup_vscode
    setup_terminal
    setup_python
    setup_macos
    setup_installer_guard
    setup_icons
    setup_standards
    success "Setup complete"
}

main "$@"
