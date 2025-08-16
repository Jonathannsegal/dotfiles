# Function to source files if they exist
source_if_exists() {
    if [ -f "$1" ]; then
        source "$1"
    fi
}

eval "$(starship init zsh)"

# Source environment file first to get DOTFILES path
source_if_exists "$HOME/.env.sh"

# Load functions after environment is sourced
source_if_exists "$DOTFILES/zsh/functions.zsh"

# History configuration
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_VERIFY
setopt INC_APPEND_HISTORY

# Directory stack configuration
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT

# Path configuration
export PATH="$HOME/bin:/usr/local/bin:$PATH"

# Initialize pyenv
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# Load aliases
source_if_exists "$DOTFILES/zsh/aliases.zsh"

# Load dotnet
source_if_exists "$DOTFILES/dotnet/path.zsh"

# Completion system
autoload -Uz compinit
compinit

# Key bindings
bindkey -e
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
bindkey '^[^[[D' backward-word
bindkey '^[^[[C' forward-word
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line

# Load colors
autoload -U colors && colors

# Enable prompt substitution
setopt PROMPT_SUBST

# Set default Brewfile location for Homebrew
export HOMEBREW_BUNDLE_FILE="$HOME/.Brewfile"

# Source environment file first to get DOTFILES path
source_if_exists "$HOME/.env.sh"

# Install and source zsh-syntax-highlighting
if [ ! -d "${HOME}/.zsh/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
        "${HOME}/.zsh/plugins/zsh-syntax-highlighting"
fi
source "${HOME}/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# Install zsh-autosuggestions
if [ ! -d "${HOME}/.zsh/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions.git \
        "${HOME}/.zsh/plugins/zsh-autosuggestions"
fi
source "${HOME}/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"

# Configure highlighting colors
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)
typeset -A ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[command]='fg=green'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=red'

# Run the Brewfile check if it exists
if typeset -f brew_check > /dev/null; then
    brew_check

    # Also run the cleaner
    if [ -x "$DOTFILES/run/clean.sh" ]; then
        "$DOTFILES/run/clean.sh"
    fi
fi
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

# jdk configuration
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
export CPPFLAGS="-I/opt/homebrew/opt/openjdk/include"

# pnpm from homebrew
export PNPM_HOME="/opt/homebrew/bin"

# zoxide
eval "$(zoxide init --cmd cd zsh)"

# Show execution time for long-running commands
REPORTTIME=10

# Suggest package that might have the command
command_not_found_handler() {
    local pkgs cmd="$1"
    
    pkgs=(${(f)"$(pkgfile -b -v -- "$cmd" 2>/dev/null)"})
    if [[ -n "$pkgs" ]]; then
        printf 'The application %s is not installed. It may be found in the following packages:\n' "$cmd"
        printf '  %s\n' $pkgs[@]
        return 127
    fi
    
    return 127
}

setup_eza() {
    # Install shell completions if not already installed
    local COMPLETIONS_DIR="$HOME/.zsh/completions"
    mkdir -p "$COMPLETIONS_DIR"
    
    if [ ! -f "$COMPLETIONS_DIR/_eza" ]; then
        echo "Installing eza completions..."
        curl -L https://raw.githubusercontent.com/eza-community/eza/main/completions/zsh/_eza \
            -o "$COMPLETIONS_DIR/_eza"
    fi
    
    # Ensure completions directory is in FPATH
    if [[ ! "$FPATH" == *"$COMPLETIONS_DIR"* ]]; then
        echo "Adding completions to FPATH..."
        echo "export FPATH=\"$COMPLETIONS_DIR:\$FPATH\"" >> "$HOME/.zshrc"
    fi
    
    success "eza configured successfully"
}

source_if_exists "$DOTFILES/iterm2/zsh/iterm2.zsh"
source_if_exists "$DOTFILES/xxh/zsh/xxh.zsh"
source_if_exists "$DOTFILES/eza/zsh/eza.zsh"
source_if_exists "$DOTFILES/tmux/zsh/tmux.zsh"
source_if_exists "$DOTFILES/alder/zsh/alder.zsh"
source_if_exists "$DOTFILES/bat/zsh/bat.zsh"

zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
export FPATH="/Users/jsegal/.zsh/completions:$FPATH"

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/opt/homebrew/anaconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/opt/homebrew/anaconda3/etc/profile.d/conda.sh" ]; then
        . "/opt/homebrew/anaconda3/etc/profile.d/conda.sh"
    else
        export PATH="/opt/homebrew/anaconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <eval "$(rbenv init - zsh)"
eval "$(rbenv init -)"
