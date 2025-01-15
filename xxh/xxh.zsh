# XXH Configuration
export XXH_CONFIG="$HOME/.config/xxh/config.xxhc"

# XXH Aliases
alias xxhl='xxh local'  # Run xxh locally
alias xxhf='xxh +if'    # Force reinstall xxh on remote host
alias xxhq='xxh +q'     # Quiet mode
alias xxhr='xxh +hhr'   # Remove xxh home directory on exit

# Function to update xxh plugins
xxh_update() {
    echo "Updating xxh plugins..."
    xxh +RI xxh-plugin-zsh-ohmyzsh
    xxh +RI xxh-plugin-zsh-powerlevel10k
    xxh +RI xxh-plugin-prerun-dotfiles
    xxh +RI xxh-plugin-prerun-python
    echo "xxh plugins updated!"
}

# Function to reinstall xxh environment
xxh_reinstall() {
    echo "Reinstalling xxh environment..."
    xxh +if "$@"
}