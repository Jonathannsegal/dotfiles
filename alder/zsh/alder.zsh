# Alder aliases and functions
alias tree='alder --exclude="^.*\.(alias)$"'
alias treef='alder --full'
alias trees='alder --sizes'
alias treed='alder --directories'
alias treei='alder --git-ignore'

# Function to show tree with common excludes
tree_clean() {
    alder --exclude=".git|node_modules|.DS_Store|^.*\.(alias)$" "$@"
}