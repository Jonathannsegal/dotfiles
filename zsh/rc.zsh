# Function to source files if they exist
source_if_exists() {
    if [ -f "$1" ]; then
        source "$1"
    fi
}

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

# Load and configure agnoster theme
if [ ! -d "${HOME}/.zsh/themes" ]; then
    mkdir -p "${HOME}/.zsh/themes"
fi

# Download agnoster theme if not present
if [ ! -f "${HOME}/.zsh/themes/agnoster.zsh-theme" ]; then
    curl -o "${HOME}/.zsh/themes/agnoster.zsh-theme" \
        https://raw.githubusercontent.com/agnoster/agnoster-zsh-theme/master/agnoster.zsh-theme
fi

# Source agnoster theme
source "${HOME}/.zsh/themes/agnoster.zsh-theme"

# Set default Brewfile location for Homebrew
export HOMEBREW_BUNDLE_FILE="$HOME/.Brewfile"

# Source environment file first to get DOTFILES path
source_if_exists "$HOME/.env.sh"

# Configure agnoster theme settings
AGNOSTER_PROMPT_SEGMENTS=(
    prompt_status
    prompt_context
    prompt_virtualenv
    prompt_dir
    prompt_git
    prompt_end
)

# Theme settings
DEFAULT_USER=$USER
AGNOSTER_PATH_STYLE="full"
ZSH_THEME="agnoster"

# Initialize plugins directory
mkdir -p "${HOME}/.zsh/plugins"

# Install and source zsh-syntax-highlighting
if [ ! -d "${HOME}/.zsh/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
        "${HOME}/.zsh/plugins/zsh-syntax-highlighting"
fi
source "${HOME}/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# Configure highlighting colors
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)
typeset -A ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[command]='fg=green'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=red'

# Run the Brewfile check if it exists
if typeset -f brew_check > /dev/null; then
    brew_check
fi
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

# jdk configuration
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
export CPPFLAGS="-I/opt/homebrew/opt/openjdk/include"

# pnpm from homebrew
export PNPM_HOME="/opt/homebrew/bin"

# zoxide
eval "$(zoxide init --cmd cd zsh)"
