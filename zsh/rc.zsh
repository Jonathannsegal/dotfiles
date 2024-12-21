# Load environment variables
source_if_exists "$HOME/.env.sh"

# Path configuration
export PATH="$HOME/bin:/usr/local/bin:$PATH"

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

# Completion system
autoload -Uz compinit
compinit

# Prompt configuration
autoload -Uz promptinit
promptinit
prompt pure

# Load additional configs
source_if_exists "$DOTFILES/zsh/aliases.zsh"
source_if_exists "$DOTFILES/zsh/functions.zsh"
source_if_exists "$DOTFILES/zsh/keybindings.zsh"

# Check Brewfile status daily
brew_check() {
    local BREW_CHECK_FILE="$HOME/.brew_check"
    local current_date=$(date +%Y-%m-%d)
    
    # Check if we've already run today
    if [ -f "$BREW_CHECK_FILE" ] && [ "$(cat "$BREW_CHECK_FILE")" = "$current_date" ]; then
        return
    fi
    
    echo "🍺 Checking Homebrew bundle status..."
    if ! brew bundle check --file=$HOME/.Brewfile &>/dev/null; then
        echo "⚠️  Some Homebrew packages are out of sync with Brewfile"
        echo "Run 'brew bundle' to install missing packages"
        echo "Run 'brew bundle cleanup' to remove unlisted packages"
    fi
    
    # Update check date
    echo "$current_date" > "$BREW_CHECK_FILE"
}

# Run the check when shell starts
brew_check