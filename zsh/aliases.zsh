# Navigation
alias ..='cd ..'
alias ...='cd ../..'
# Replace ls with eza
alias ls='eza --icons --git'
alias l='eza -l --icons --git'
alias ll='eza -l --icons --git'
alias la='eza -la --icons --git'
alias lt='eza --tree --icons'
alias llt='eza -l --tree --icons --git'

# More detailed views
alias lg='eza -l --icons --git-ignore --git'  # List and show git status, ignoring .gitignored files
alias lh='eza -l --icons --git --header'      # List with header
alias laa='eza -la --icons --git --header'    # List all with header
alias lm='eza -l --icons --git --sort=modified' # List by modified date
alias lk='eza -l --icons --git --sort=size'    # List by size
alias lr='eza -lR --icons --git'              # Recursive list

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