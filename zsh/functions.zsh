# Create a new directory and enter it
mkcd() {
    mkdir -p "$@" && cd "$@"
}

# Git branch cleanup
git_cleanup() {
    git branch --merged | grep -v '\*\|master\|main\|dev' | xargs -n 1 git branch -d
}

# Extract various archive types
extract() {
    if [ -f $1 ]; then
        case $1 in
            *.tar.bz2)   tar xjf $1     ;;
            *.tar.gz)    tar xzf $1     ;;
            *.bz2)       bunzip2 $1     ;;
            *.rar)       unrar e $1     ;;
            *.gz)        gunzip $1      ;;
            *.tar)       tar xf $1      ;;
            *.tbz2)      tar xjf $1     ;;
            *.tgz)       tar xzf $1     ;;
            *.zip)       unzip $1       ;;
            *.Z)         uncompress $1  ;;
            *.7z)        7z x $1        ;;
            *)          echo "'$1' cannot be extracted" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Wrap brew command to auto-sync Brewfile
brew() {
    # Execute the original brew command
    command brew "$@"
    
    # Get the exit status of brew command
    local exit_status=$?
    
    # Only proceed if brew command was successful
    if [ $exit_status -eq 0 ]; then
        # Check if the command was install, uninstall, or upgrade
        case "$1" in
            install|uninstall|upgrade)
                echo "🍺 Updating Brewfile..."
                command brew bundle dump --force --file=$HOME/.Brewfile
                echo "✅ Brewfile updated!"
                ;;
        esac
    fi
    
    return $exit_status
}

# --- keybindings.zsh ---
# Use emacs key bindings
bindkey -e

# Fuzzy finding
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Custom key bindings
bindkey '^[^[[D' backward-word
bindkey '^[^[[C' forward-word
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line