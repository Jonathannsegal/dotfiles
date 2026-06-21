# Python environment configuration
if command -v brew >/dev/null 2>&1; then
    BREW_PREFIX="$(brew --prefix)"
    export PATH="$BREW_PREFIX/bin:$PATH"

    if [ -x "$BREW_PREFIX/bin/python3" ]; then
        alias python="$BREW_PREFIX/bin/python3"
    fi

    if [ -x "$BREW_PREFIX/bin/pip3" ]; then
        alias pip="$BREW_PREFIX/bin/pip3"
    fi
fi
