# eza configuration and aliases

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
