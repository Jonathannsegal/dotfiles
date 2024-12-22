# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ll='ls -la'
alias l='ls -l'
alias la='ls -la'

# Git shortcuts
alias g='git'
alias ga='git add'
alias gc='git commit'
alias gco='git checkout'
alias gp='git push'
alias gl='git pull'
alias gs='git status'

# Directory shortcuts
alias dotfiles='cd $DOTFILES'
alias projects='cd $HOME/Projects'

# Common operations
alias zshrc='$EDITOR $DOTFILES/zsh/rc.zsh'
alias reload='source $HOME/.zshrc'

# Homebrew shortcuts
alias brews='brew bundle dump --force --file=$HOME/.Brewfile' # Manual Brewfile update
alias brewc='brew bundle check --file=$HOME/.Brewfile' # Check status
alias brewi='brew bundle --file=$HOME/.Brewfile' # Install everything
alias brewcl='brew bundle cleanup --file=$HOME/.Brewfile' # Remove unlisted packages

# Directory stack navigation
alias d='dirs -v'
for index ({1..9}) alias "$index"="cd +${index}"; unset index