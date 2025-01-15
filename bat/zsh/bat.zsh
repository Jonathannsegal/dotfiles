# Bat Configuration
export BAT_CONFIG_PATH="$HOME/.config/bat/config"

# Bat aliases and functions
alias cat='bat --paging=never'
alias batp='bat --style=plain'
alias batl='bat --style=numbers'
alias batll='bat --style=full'
alias batdiff='bat --diff'

# Preview function for fzf using bat
preview() {
    fzf --preview "bat --color=always --style=numbers --line-range=:500 {}"
}

# Function to highlight help messages
bathelp() {
    "$@" --help 2>&1 | bat --plain --language=help
}

# Show preview of themes
battheme() {
    bat --list-themes | fzf --preview="bat --theme={} --color=always $1"
}alias cat="bat --theme=\$(defaults read -globalDomain AppleInterfaceStyle &> /dev/null && echo TwoDark || echo GitHub)"
alias cat="bat --theme=\$(defaults read -globalDomain AppleInterfaceStyle &> /dev/null && echo TwoDark || echo GitHub)"
