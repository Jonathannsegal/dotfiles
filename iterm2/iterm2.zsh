# iTerm2 Shell Integration
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

# Add iTerm2 utilities to PATH
if [ -d "$HOME/.iterm2" ]; then
    export PATH="$HOME/.iterm2:$PATH"
fi

# Enable shell integration features
iterm2_print_user_vars() {
    # Display git branch and status in iTerm2 status bar
    if [ -n "$(git rev-parse --git-dir 2>/dev/null)" ]; then
        local branch=$(git_info)
        local status=$(git_status)
        iterm2_set_user_var gitBranch "$branch"
        iterm2_set_user_var gitStatus "$status"
    fi
    
    # Display Python virtual env in status bar
    if [ -n "$VIRTUAL_ENV" ]; then
        iterm2_set_user_var pythonVenv "${VIRTUAL_ENV##*/}"
    fi
}

# Configure word navigation
bindkey "^[[1;5D" backward-word
bindkey "^[[1;5C" forward-word