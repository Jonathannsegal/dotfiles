# Function to source files if they exist
source_if_exists() {
    if [ -f "$1" ]; then
        source "$1"
    fi
}

# Source environment file first to get DOTFILES path
source_if_exists "$HOME/.env.sh"

if [ -z "${DOTFILES:-}" ]; then
    if [ -d "$HOME/Developer/dotfiles" ]; then
        export DOTFILES="$HOME/Developer/dotfiles"
    else
        export DOTFILES="$HOME/.dotfiles"
    fi
fi

if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi

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
# Ensure Homebrew bin comes first on Apple Silicon
if [ -d "/opt/homebrew/bin" ]; then
    export PATH="/opt/homebrew/bin:$PATH"
fi
export PATH="$HOME/bin:/usr/local/bin:$PATH"

# Remove any pyenv initialization (we manage a single Homebrew Python now)
# Also ensure pyenv paths are stripped from PATH
PATH=$(echo "$PATH" | awk -v RS=: -v ORS=: '$0!~/\.pyenv\/bin/ && $0!~/\.pyenv\/shims/' | sed 's/:$//')

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

# Source zsh plugins installed by run/setup.sh
source_if_exists "${HOME}/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
source_if_exists "${HOME}/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"

# Configure highlighting colors
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)
typeset -A ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[command]='fg=green'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=red'

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

# jdk configuration
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
export CPPFLAGS="-I/opt/homebrew/opt/openjdk/include"

# pnpm from homebrew
export PNPM_HOME="/opt/homebrew/bin"

# zoxide (if installed)
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init --cmd cd zsh)"
fi

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

source_if_exists "$DOTFILES/iterm2/zsh/iterm2.zsh"
source_if_exists "$DOTFILES/python/zsh/python.zsh"
source_if_exists "$DOTFILES/xxh/zsh/xxh.zsh"
source_if_exists "$DOTFILES/eza/zsh/eza.zsh"
source_if_exists "$DOTFILES/tmux/zsh/tmux.zsh"
source_if_exists "$DOTFILES/alder/zsh/alder.zsh"
source_if_exists "$DOTFILES/bat/zsh/bat.zsh"

zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
if [ -d "$HOME/.zsh/completions" ]; then
    export FPATH="$HOME/.zsh/completions:$FPATH"
fi

# Finally, strip any remaining Anaconda paths from PATH (defensive)
PATH=$(echo "$PATH" | awk -v RS=: -v ORS=: '$0!~/anaconda3/' | sed 's/:$//')
