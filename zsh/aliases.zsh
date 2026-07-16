# Navigation
alias ..='cd ..'
alias ...='cd ../..'
if command -v eza >/dev/null 2>&1; then
    # Replace ls with eza
    alias ls='eza --icons --git'
    alias l='eza -l --icons --git'
    alias ll='eza -l --icons --git'
    alias la='eza -la --icons --git'
    alias lt='eza --tree --icons'
    alias llt='eza -l --tree --icons --git'

    # More detailed views
    alias lg='eza -l --icons --git-ignore --git'
    alias lh='eza -l --icons --git --header'
    alias laa='eza -la --icons --git --header'
    alias lm='eza -l --icons --git --sort=modified'
    alias lk='eza -l --icons --git --sort=size'
    alias lr='eza -lR --icons --git'
else
    alias l='ls -la'
    alias ll='ls -l'
    alias la='ls -la'
fi

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
alias projects='cd $HOME/Developer'

# Common operations
alias zshrc='$EDITOR $DOTFILES/zsh/rc.zsh'
alias reload='source $HOME/.zshrc'
alias maintain='$DOTFILES/run/maintain.sh'
alias health="$DOTFILES/run/maintain.sh check"
alias snapshot='$DOTFILES/run/maintain.sh snapshot'
alias restore-dotfiles='$DOTFILES/run/maintain.sh restore'
alias project-report='$DOTFILES/run/cleanup.sh projects'

# Homebrew shortcuts
alias brews='brew bundle dump --force --file=$HOME/.Brewfile' # Manual Brewfile update
alias brewc='brew bundle check --file=$HOME/.Brewfile' # Check status
alias brewi='brew bundle --file=$HOME/.Brewfile' # Install everything
alias brewcl='brew bundle cleanup --file=$HOME/.Brewfile' # Remove unlisted packages

# Directory stack navigation
alias d='dirs -v'
for index ({1..9}) alias "$index"="cd +${index}"; unset index
