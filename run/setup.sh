#!/usr/bin/env bash

# Move to dotfiles directory
cd "$(dirname "$0")/.."
DOTFILES=$(pwd -P)
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

set -e

# Status indicators with colors
info() {
    printf "\r [ \033[00;34m..\033[0m ] $1\n"
}

user() {
    printf "\r [ \033[0;33m??\033[0m ] $1\n"
}

success() {
    printf "\r\033[2K [ \033[00;32mOK\033[0m ] $1\n"
}

fail() {
    printf "\r\033[2K [\033[0;31mFAIL\033[0m] $1\n"
    echo ''
    exit 1
}

link_file() {
    local src=$1 dst=$2
    local overwrite= backup= skip=
    local action=

    if [ -f "$dst" ] || [ -d "$dst" ] || [ -L "$dst" ]; then
        if [ "$overwrite_all" == "false" ] && [ "$backup_all" == "false" ] && [ "$skip_all" == "false" ]; then
            # Check if it's already the correct symlink
            local currentSrc="$(readlink "$dst")"
            if [ "$currentSrc" == "$src" ]; then
                skip=true
                success "Already linked $src to $dst"
            else
                user "File already exists: $dst ($(basename "$src")), what do you want to do?
 [s]kip, [S]kip all, [o]verwrite, [O]verwrite all, [b]ackup, [B]ackup all?"
                read -n 1 action < /dev/tty
                case "$action" in
                    o ) overwrite=true;;
                    O ) overwrite_all=true;;
                    b ) backup=true;;
                    B ) backup_all=true;;
                    s ) skip=true;;
                    S ) skip_all=true;;
                    * ) ;;
                esac
            fi
        fi

        overwrite=${overwrite:-$overwrite_all}
        backup=${backup:-$backup_all}
        skip=${skip:-$skip_all}

        if [ "$overwrite" == "true" ]; then
            rm -rf "$dst"
            success "removed $dst"
        fi

        if [ "$backup" == "true" ]; then
            mkdir -p "$BACKUP_DIR"
            mv "$dst" "$BACKUP_DIR/$(basename "$dst")"
            success "moved $dst to $BACKUP_DIR/$(basename "$dst")"
        fi

        if [ "$skip" == "true" ]; then
            success "skipped $src"
        fi
    fi

    if [ "$skip" != "true" ]; then
        mkdir -p "$(dirname "$dst")"
        ln -s "$src" "$dst"
        success "linked $src to $dst"
    fi
}

setup_terminal() {
    info 'configuring terminal settings'
    
    if [ "$(uname -s)" == "Darwin" ]; then
        if [ -f "$DOTFILES/terminal/settings.sh" ]; then
            # Close System Preferences to prevent overriding changes
            osascript -e 'tell application "System Preferences" to quit'
            
            # Source the terminal settings
            source "$DOTFILES/terminal/settings.sh"
            
            # Run the setup functions
            setup_terminal_profiles
            setup_theme_switcher
            
            success 'terminal settings configured'
        else
            fail 'terminal settings script not found'
        fi
    else
        success 'skipped terminal settings (not on macOS)'
    fi
}

setup_gitconfig() {
    info 'setting up gitconfig'
    
    if [ ! -f "$DOTFILES/git/config.local.git" ]; then
        user ' - What is your git author name?'
        read -r git_authorname
        user ' - What is your git author email?'
        read -r git_authoremail
        
        sed -e "s/AUTHORNAME/$git_authorname/g" -e "s/AUTHOREMAIL/$git_authoremail/g" \
            "$DOTFILES/git/config.local.example.git" > "$DOTFILES/git/config.local.git"
        
        success 'generated git config'
    else
        success 'existing git config found'
    fi
}

setup_python() {
    info 'setting up python environment'
    
    if [ "$(uname -s)" == "Darwin" ]; then
        if [ -f "$DOTFILES/python/install.sh" ]; then
            user 'Do you want to set up Python environment? (y/n)'
            read -n 1 should_setup_python
            echo ''
            
            if [ "$should_setup_python" == "y" ]; then
                info 'running python setup script'
                bash "$DOTFILES/python/install.sh"
                success 'python environment configured'
            else
                success 'skipped python setup'
            fi
        else
            fail 'python setup script not found'
        fi
    else
        success 'skipped python setup (not on macOS)'
    fi
}

setup_vscode() {
    info 'setting up VSCode configuration'
    
    if [ "$(uname -s)" == "Darwin" ]; then
        if [ -f "$DOTFILES/vscode/install.sh" ]; then
            user 'Do you want to configure VSCode settings? (y/n)'
            read -n 1 should_setup_vscode
            echo ''
            
            if [ "$should_setup_vscode" == "y" ]; then
                info 'running VSCode setup script'
                bash "$DOTFILES/vscode/install.sh"
                success 'VSCode settings configured'
            else
                success 'skipped VSCode setup'
            fi
        else
            fail 'VSCode setup script not found'
        fi
    else
        success 'skipped VSCode setup (not on macOS)'
    fi
}

setup_dotnet() {
    info 'setting up dotnet environment'
    
    if [ -f "$DOTFILES/dotnet/install.sh" ]; then
        user 'Do you want to set up .NET environment? (y/n)'
        read -n 1 should_setup_dotnet
        echo ''
        
        if [ "$should_setup_dotnet" == "y" ]; then
            info 'running dotnet setup script'
            bash "$DOTFILES/dotnet/install.sh"
            success 'dotnet environment configured'
        else
            success 'skipped dotnet setup'
        fi
    else
        fail 'dotnet setup script not found'
    fi
}

setup_macos() {
    info 'configuring macOS settings'
    
    if [ "$(uname -s)" == "Darwin" ]; then
        if [ -f "$DOTFILES/macos/settings.sh" ]; then
            user 'Do you want to configure macOS settings? (y/n)'
            read -n 1 should_setup_macos
            echo ''
            
            if [ "$should_setup_macos" == "y" ]; then
                info 'running macOS settings script'
                bash "$DOTFILES/macos/settings.sh"
                success 'macOS settings configured'
            else
                success 'skipped macOS settings'
            fi
        else
            warn 'macOS settings script not found'
        fi
    else
        success 'skipped macOS settings (not on macOS)'
    fi
}

install_dotfiles() {
    info 'installing dotfiles'
    local overwrite_all=false backup_all=false skip_all=false

    # Find all links.prop files, excluding .git directory
    find -H "$DOTFILES" -maxdepth 2 -name 'links.prop' -not -path '*.git*' | while read -r linkfile; do
        info "Processing $(basename $(dirname "$linkfile"))"
        
        # Process each line in the links.prop file
        while read -r line || [ -n "$line" ]; do
            # Skip empty lines and comments
            if [[ -z "$line" || "$line" =~ ^# ]]; then
                continue
            fi
            
            local src dst
            src=$(eval echo "$line" | cut -d '=' -f 1)
            dst=$(eval echo "$line" | cut -d '=' -f 2)
            
            link_file "$src" "$dst"
        done < "$linkfile"
    done
}

create_env_file() {
    if test -f "$HOME/.env.sh"; then
        success "$HOME/.env.sh file already exists, skipping"
    else
        cat > "$HOME/.env.sh" << EOF
# Environment variables for dotfiles
export DOTFILES=$DOTFILES

# Add your machine-specific configuration below
# Example: export PATH=\$PATH:/usr/local/bin

# Source helper function for optional includes
source_if_exists() {
    if test -r "\$1"; then
        source "\$1"
    fi
}
EOF
        success 'created ~/.env.sh'
    fi
}

# Run all the installers
setup_gitconfig
install_dotfiles
create_env_file
setup_terminal
setup_python
setup_dotnet
setup_vscode
setup_macos

echo ''
success 'All installed!'