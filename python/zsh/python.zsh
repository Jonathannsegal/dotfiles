# Python environment configuration
# Prioritize Homebrew Python over system Python

# Get Homebrew prefix (works for both Intel and Apple Silicon Macs)
if command -v brew >/dev/null 2>&1; then
    BREW_PREFIX="$(brew --prefix)"
    
    # Put Homebrew bin at the front of PATH
    export PATH="$BREW_PREFIX/bin:$PATH"
    
    # Ensure python3 and pip3 from Homebrew are used
    alias python="$BREW_PREFIX/bin/python3"
    alias pip="$BREW_PREFIX/bin/pip3"
fi
