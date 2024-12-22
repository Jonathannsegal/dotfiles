# Create a new directory and enter it
mkcd() {
    mkdir -p "$@" && cd "$@"
}

# Function to source files if they exist
source_if_exists() {
    if [ -f "$1" ]; then
        source "$1"
    fi
}

# Git branch cleanup
git_cleanup() {
    git branch --merged | grep -v '\*\|master\|main\|dev' | xargs -n 1 git branch -d
}

# Extract various archive types
extract() {
    if [ -f $1 ]; then
        case $1 in
            *.tar.bz2) tar xjf $1 ;;
            *.tar.gz) tar xzf $1 ;;
            *.bz2) bunzip2 $1 ;;
            *.rar) unrar e $1 ;;
            *.gz) gunzip $1 ;;
            *.tar) tar xf $1 ;;
            *.tbz2) tar xjf $1 ;;
            *.tgz) tar xzf $1 ;;
            *.zip) unzip $1 ;;
            *.Z) uncompress $1 ;;
            *.7z) 7z x $1 ;;
            *) echo "'$1' cannot be extracted" ;;
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

# Wrap mas command to auto-sync Brewfile
mas() {
    # Execute the original mas command
    command mas "$@"
    # Get the exit status of mas command
    local exit_status=$?
    # Only proceed if mas command was successful
    if [ $exit_status -eq 0 ]; then
        # Check if the command was install, uninstall, or purchase
        case "$1" in
            install|uninstall|purchase)
                echo "🍎 Updating Brewfile with Mac App Store changes..."
                command brew bundle dump --force --file=$HOME/.Brewfile
                echo "✅ Brewfile updated!"
                ;;
        esac
    fi
    return $exit_status
}

# Brewfile check function
brew_check() {
    local BREW_CHECK_FILE="$HOME/.brew_check"
    local current_date=$(date +%Y-%m-%d)
    # Check if we've already run today
    if [ -f "$BREW_CHECK_FILE" ] && [ "$(cat "$BREW_CHECK_FILE")" = "$current_date" ]; then
        return
    fi
    echo "🍺 Checking Homebrew bundle status..."
    if ! brew bundle check --file=$HOME/.Brewfile &>/dev/null; then
        echo "⚠️ Some Homebrew packages are out of sync with Brewfile"
        echo "Run 'brew bundle' to install missing packages"
        echo "Run 'brew bundle cleanup' to remove unlisted packages"
    fi
    # Update check date
    echo "$current_date" > "$BREW_CHECK_FILE"
}

# Wrap pip command to auto-sync requirements.txt
pip() {
    # Store the path to requirements.txt
    local requirements_file="$DOTFILES/python/requirements.txt"
    
    # Execute the original pip command
    command pip "$@"
    
    # Get the exit status of pip command
    local exit_status=$?
    
    # Only proceed if pip command was successful
    if [ $exit_status -eq 0 ]; then
        # Check if the command was install or uninstall
        case "$1" in
            install|uninstall)
                echo "📦 Updating requirements.txt..."
                # Get all installed packages with versions
                command pip freeze > "$requirements_file"
                # Remove pip, setuptools, and wheel as they are base packages
                sed -i '' '/^pip==/d' "$requirements_file"
                sed -i '' '/^setuptools==/d' "$requirements_file"
                sed -i '' '/^wheel==/d' "$requirements_file"
                echo "✅ requirements.txt updated!"
                ;;
        esac
    fi
    return $exit_status
}

# Git information for prompt
git_info() {
    local ref
    ref=$(command git symbolic-ref HEAD 2> /dev/null) || \
    ref=$(command git rev-parse --short HEAD 2> /dev/null) || return 0
    echo "${ref#refs/heads/}"
}

# Git status indicators for prompt
git_status() {
    local indicators=""
    # Check for uncommitted changes
    if [[ $(git status --porcelain 2> /dev/null) ]]; then
        indicators+="*"
    fi
    # Check for unpushed commits
    if command git rev-parse --verify @{u} >/dev/null 2>&1; then
        local ahead=$(command git rev-list @{u}..HEAD 2>/dev/null | wc -l)
        local behind=$(command git rev-list HEAD..@{u} 2>/dev/null | wc -l)
        if [[ $ahead -gt 0 ]]; then
            indicators+="↑"
        fi
        if [[ $behind -gt 0 ]]; then
            indicators+="↓"
        fi
    fi
    echo $indicators
}

# Enhanced fuzzy history search
fh() {
    print -z $( ([ -n "$ZSH_NAME" ] && fc -l 1 || history) | fzf +s --tac | sed 's/ *[0-9]* *//')
}

# Fuzzy directory jumping
fj() {
    cd "$(find . -type d | fzf)"
}

# Python configuration
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv 1>/dev/null 2>&1; then
    eval "$(pyenv init -)"
fi

# Virtual environments directory
export WORKON_HOME=$HOME/.virtualenvs
export PROJECT_HOME=$HOME/Projects

# Poetry configuration
export POETRY_HOME="$HOME/.poetry"
export PATH="$POETRY_HOME/bin:$PATH"

# Pip configuration
export PIP_REQUIRE_VIRTUALENV=false
export PIP_DOWNLOAD_CACHE="$HOME/.pip/cache"

# Python development settings
export PYTHONDONTWRITEBYTECODE=1  # Prevent Python from writing .pyc files
export PYTHONUNBUFFERED=1         # Force Python output to be unbuffered