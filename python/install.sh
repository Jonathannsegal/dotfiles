#!/usr/bin/env bash

# (Deprecated) pyenv-based latest version lookup removed. We will use Homebrew Python only.
get_latest_python_version() {
    echo "" # unused
}

print_status() {
    printf "\r [ \033[00;34m..\033[0m ] $1\n"
}
print_success() {
    printf "\r\033[2K [ \033[00;32mOK\033[0m ] $1\n"
}
print_error() {
    printf "\r\033[2K [\033[0;31mFAIL\033[0m] $1\n"
}
print_warning() {
    printf "\r\033[2K [ \033[00;33mWARN\033[0m ] $1\n"
}

# Try to locate Homebrew if it's not in PATH. Sets BREW_CMD if found.
find_brew() {
    if command -v brew >/dev/null 2>&1; then
        BREW_CMD="brew"
        return 0
    fi

    # Common Homebrew locations on macOS
    local candidates=("/opt/homebrew/bin/brew" "/usr/local/bin/brew" "/home/linuxbrew/.linuxbrew/bin/brew")
    for p in "${candidates[@]}"; do
        if [ -x "$p" ]; then
            BREW_CMD="$p"
            return 0
        fi
    done

    # Not found; leave BREW_CMD unset
    return 1
}

# pyenv detection removed (we are uninstalling pyenv in this flow)

# No pyenv activation; we are removing pyenv in this setup

# Handle command line arguments (kept for backwards compatibility)
NO_CONFIRM=false
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --no-confirm) NO_CONFIRM=true; shift ;;
        --help) echo "Usage: install.sh [--no-confirm]"; exit 0 ;;
        *) print_error "Unknown parameter: $1"; exit 1 ;;
    esac
done

# Store dependencies using a simple array
DEPS_LIST=()
get_all_dependencies() {
    local package="$1"
    local deps
    
    ${BREW_CMD:-brew} deps --installed "$package" 2>/dev/null | while read -r dep; do
        if [[ ! " ${DEPS_LIST[@]} " =~ " ${dep} " ]]; then
            DEPS_LIST+=("$dep")
            get_all_dependencies "$dep"
        fi
    done
}

# Safely remove Python with force if needed
remove_python_safely() {
    local python_version="$1"
    local formula="python@$python_version"
    
    print_status "Attempting to remove $formula..."
    
    # Try normal uninstall first
    if ${BREW_CMD:-brew} uninstall "$formula" 2>/dev/null; then
        print_success "Removed $formula normally"
        return 0
    fi
    
    # If normal uninstall fails, ask for forced removal
    print_warning "$formula has dependencies. Checking impact..."
    
    # Reset and get all dependencies
    DEPS_LIST=()
    get_all_dependencies "$formula"
    
    # Print all affected packages
    if [ ${#DEPS_LIST[@]} -gt 0 ]; then
        print_warning "The following packages depend on $formula or its dependencies:"
        printf " [ \033[00;33mWARN\033[0m ] - %s\n" "${DEPS_LIST[@]}"
    fi
    
    if [ "$NO_CONFIRM" = true ] || confirm "Do you want to force remove Python? This won't remove other packages but might temporarily break them"; then
        if ${BREW_CMD:-brew} uninstall --ignore-dependencies "$formula"; then
            print_success "Forcefully removed $formula"
            print_warning "Some packages might need to be rebuilt later"
            return 0
        else
            print_error "Failed to remove $formula even with force"
            return 1
        fi
    else
        print_warning "Skipping Python removal"
        return 0
    fi
}

setup_python_environment() {
    # This function will: completely remove existing Pythons (Homebrew formulas and pyenv versions),
    # remove streamlit and tcl-tk (Homebrew) if present, then install a clean tcl-tk and a fresh
    # pyenv Python (latest stable).

    # Remove any Anaconda/Miniconda installations (we don't want conda)
    remove_conda() {
        print_status "Removing Anaconda/Miniconda installations if present..."
        # Try uninstalling Homebrew anaconda cask if installed
        if ${BREW_CMD:-brew} list --cask 2>/dev/null | grep -q "^anaconda$"; then
            ${BREW_CMD:-brew} uninstall --cask anaconda >/dev/null 2>&1 && print_success "Uninstalled Homebrew cask 'anaconda'" || print_warning "Failed to uninstall Homebrew cask 'anaconda'"
        fi
        # Known conda locations
        local conda_paths=("$HOME/anaconda3" "$HOME/miniconda3" "$HOME/miniconda" "$HOME/.conda" "/opt/homebrew/anaconda3" "/usr/local/anaconda3")
        local removed_any=false
        for p in "${conda_paths[@]}"; do
            if [ -d "$p" ]; then
                # best-effort to clear protection and perms
                chmod -R u+w "$p" 2>/dev/null || true
                chmod -RN "$p" 2>/dev/null || true
                chflags -R nouchg "$p" 2>/dev/null || true
                if rm -rf "$p" 2>/dev/null; then
                    print_success "Removed $p"
                else
                    print_warning "Failed to remove $p without privileges; attempting with sudo"
                    # Pre-authenticate once if possible
                    if command -v sudo >/dev/null 2>&1; then
                        sudo -v 2>/dev/null || true
                        sudo chmod -R u+w "$p" 2>/dev/null || true
                        sudo chmod -RN "$p" 2>/dev/null || true
                        sudo chflags -R nouchg "$p" 2>/dev/null || true
                        if sudo rm -rf "$p" 2>/dev/null; then
                            print_success "Removed $p with sudo"
                        else
                            print_warning "Failed to remove $p even with sudo"
                        fi
                    else
                        print_warning "sudo not available; cannot remove $p"
                    fi
                fi
                removed_any=true
            fi
        done
    # Remove conda init lines from common shell profiles (include .zprofile)
    local profiles=("$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.bash_profile" "$HOME/.bashrc" "$HOME/.profile")
        for prof in "${profiles[@]}"; do
            if [ -f "$prof" ]; then
                # remove lines added by conda init
                if grep -q "# >>> conda initialize >>>" "$prof" 2>/dev/null; then
                    awk '/# >>> conda initialize >>>/{p=1} p && /# <<< conda initialize <<</{p=0; next} !p{print}' "$prof" > "$prof.tmp" && mv "$prof.tmp" "$prof" && print_success "Removed conda init from $prof"
                fi
                # strip any lingering anaconda paths from PATH exports
                if grep -q "anaconda3" "$prof" 2>/dev/null; then
                    grep -v "anaconda3" "$prof" > "$prof.tmp" && mv "$prof.tmp" "$prof" && print_success "Removed anaconda paths from $prof"
                fi
            fi
        done
        # Sanitize PATH for this session (remove any anaconda entries)
        PATH=$(echo "$PATH" | awk -v RS=: -v ORS=: '$0!~/anaconda3/' | sed 's/:$//')
        if [ "$removed_any" = false ]; then
            print_status "No Anaconda/Miniconda installations found"
        fi
    }

    # Remove Homebrew tcl-tk (Tk) and streamlit if installed to ensure a clean reinstall
    print_status "Cleaning Python-related tooling (conda, pyenv) and any installed streamlit package..."

    # Run conda removal first to ensure no conda exists
    remove_conda

    # Remove any pyenv installation (brew and ~/.pyenv) and init lines from profiles
    remove_pyenv() {
        print_status "Removing pyenv and its Python versions..."
        # Remove pyenv via Homebrew if installed
        if ${BREW_CMD:-brew} list --formula | grep -q "^pyenv$"; then
            ${BREW_CMD:-brew} uninstall pyenv >/dev/null 2>&1 && print_success "Uninstalled Homebrew 'pyenv'" || print_warning "Failed to uninstall Homebrew 'pyenv'"
        fi
        # Remove ~/.pyenv directory and make writable if needed
        if [ -d "$HOME/.pyenv" ]; then
            chmod -R u+w "$HOME/.pyenv" 2>/dev/null || true
            chflags -R nouchg "$HOME/.pyenv" 2>/dev/null || true
            rm -rf "$HOME/.pyenv" && print_success "Removed $HOME/.pyenv" || print_warning "Failed to remove $HOME/.pyenv"
        fi
    # Strip pyenv init lines from shell profiles (include .zprofile)
    local profiles=("$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.bash_profile" "$HOME/.bashrc" "$HOME/.profile")
        for prof in "${profiles[@]}"; do
            if [ -f "$prof" ]; then
                if grep -q "pyenv init" "$prof" 2>/dev/null; then
                    # remove any lines containing 'pyenv init'
                    grep -v "pyenv init" "$prof" > "$prof.tmp" && mv "$prof.tmp" "$prof" && print_success "Removed pyenv init from $prof"
                fi
                if grep -q "PYENV_ROOT" "$prof" 2>/dev/null; then
                    grep -v "PYENV_ROOT" "$prof" > "$prof.tmp" && mv "$prof.tmp" "$prof" && print_success "Removed PYENV_ROOT from $prof"
                fi
                if grep -q "\.pyenv/shims" "$prof" 2>/dev/null; then
                    grep -v "\.pyenv/shims" "$prof" > "$prof.tmp" && mv "$prof.tmp" "$prof" && print_success "Removed pyenv shims from PATH in $prof"
                fi
            fi
        done
        # Sanitize PATH for this session
        PATH=$(echo "$PATH" | awk -v RS=: -v ORS=: '$0!~/\.pyenv\/shims/' | sed 's/:$//')
    }
    remove_pyenv

    # Note: pyenv is removed in this flow; do not attempt to activate it

    # Skipping any removal or installation of Homebrew 'tcl-tk' per request
    print_status "Skipping Homebrew 'tcl-tk' operations (user requested no tcl-tk)"

    # Ensure only Homebrew Python remains and is up to date
    print_status "Preparing Homebrew Python (removing old formulas, installing latest 'python')"
    # Remove all versioned python formulas first
    ${BREW_CMD:-brew} list --formula | grep -E '^python@' | while read -r formula; do
        ${BREW_CMD:-brew} uninstall --ignore-dependencies "$formula" >/dev/null 2>&1 && print_success "Uninstalled $formula" || print_warning "Failed to uninstall $formula"
    done
    # Remove generic python to reinstall cleanly
    if ${BREW_CMD:-brew} list --formula | grep -q '^python$'; then
        ${BREW_CMD:-brew} uninstall --ignore-dependencies python >/dev/null 2>&1 && print_success "Uninstalled Homebrew 'python'" || print_status "Homebrew 'python' not uninstalled (may not be installed)"
    fi
    # Install latest python
    if ${BREW_CMD:-brew} install python >/dev/null 2>&1 || ${BREW_CMD:-brew} upgrade python >/dev/null 2>&1; then
        print_success "Installed/Upgraded Homebrew 'python'"
    else
        print_error "Failed to install/upgrade Homebrew 'python'"
        exit 1
    fi
    # Ensure Homebrew bin directory is in PATH for this session and persistently
    BREW_PREFIX="$(${BREW_CMD:-brew} --prefix 2>/dev/null)"
    BREW_BIN="$BREW_PREFIX/bin"
    
    # Export PATH for current session, prioritizing Homebrew
    export PATH="$BREW_BIN:$PATH"
    
    # Create Python zsh configuration file
    DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
    mkdir -p "$DOTFILES/python/zsh"
    cat > "$DOTFILES/python/zsh/python.zsh" << 'EOF'
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
EOF
    print_success "Created Python zsh configuration at $DOTFILES/python/zsh/python.zsh"
    # Resolve python3 path - force Homebrew Python
    PYTHON_BIN="$BREW_PREFIX/bin/python3"
    if [ ! -x "$PYTHON_BIN" ]; then
        print_error "Homebrew python3 not found at $PYTHON_BIN"
        exit 1
    fi
    print_success "Using $("$PYTHON_BIN" --version 2>&1) at $PYTHON_BIN"
    print_status "This is your primary Python - all pip packages will install here"

    # Determine pip flags for Homebrew's externally managed environment
    PIP_FLAGS=""
    BREW_PREFIX="$(${BREW_CMD:-brew} --prefix 2>/dev/null)"
    case "$PYTHON_BIN" in
        "$BREW_PREFIX"*/bin/python3|/opt/homebrew/bin/python3|/usr/local/bin/python3)
            # Homebrew Python enforces externally-managed site-packages
            PIP_FLAGS="--break-system-packages"
            ;;
    esac

    # Best-effort removal of streamlit if present (user requested it's removed)
    if "$PYTHON_BIN" -m pip show streamlit >/dev/null 2>&1; then
        if "$PYTHON_BIN" -m pip uninstall -y streamlit $PIP_FLAGS >/dev/null 2>&1; then
            print_success "Uninstalled pip package 'streamlit'"
        else
            print_warning "Failed to uninstall 'streamlit' (may not be present or permission denied)"
        fi
    fi

    # Remove all Homebrew python formulas (python, python@X.Y)
    # No additional removal here; handled above

    # pyenv already removed above

    # Brew Python ready; no pyenv global needed

    # Skipping Tkinter verification as requested; do not fail if tkinter is unavailable
    print_status "Skipping Tkinter import verification (per request)"

    # Install Python packages (streamlit removed intentionally)
    packages=(
        "pip"
        "setuptools"
        "wheel"
        "pipenv"
        "poetry"
        "black"
        "flake8"
        "mypy"
        "pytest"
        "jupyter"
        "notebook"
        "pandas"
        "numpy"
        "matplotlib"
        "seaborn"
        "scikit-learn"
        "scipy"
        "requests"
        "pylint"
    )
    failed_packages=()
    total=${#packages[@]}
    current=0

    # Upgrade pip first using brew python (respect externally-managed policy)
    "$PYTHON_BIN" -m ensurepip --upgrade >/dev/null 2>&1 || true
    "$PYTHON_BIN" -m pip install --upgrade pip $PIP_FLAGS >/dev/null 2>&1 || true

    for package in "${packages[@]}"; do
        ((current++))
        print_status "($current/$total) Installing $package..."
        if "$PYTHON_BIN" -m pip install $PIP_FLAGS "$package" &>/dev/null; then
            print_success "($current/$total) Installed $package"
        else
            print_error "($current/$total) Failed to install $package"
            failed_packages+=("$package")
        fi
    done

    if [ ${#failed_packages[@]} -eq 0 ]; then
        print_success "Python development environment configured successfully!"
        echo ""
        print_status "=== Python Installation Summary ==="
        print_success "Python location: $PYTHON_BIN"
        print_success "Python version: $("$PYTHON_BIN" --version 2>&1)"
        print_success "Pip location: $("$PYTHON_BIN" -m pip --version | awk '{print $NF}' | sed 's/[()]//g')"
        echo ""
        
        # Create symlinks for python and pip (without the '3' suffix)
        print_status "Creating 'python' and 'pip' symlinks..."
        if [ -w "$BREW_PREFIX/bin" ]; then
            ln -sf "$BREW_PREFIX/bin/python3" "$BREW_PREFIX/bin/python" 2>/dev/null && print_success "Created symlink: python -> python3"
            ln -sf "$BREW_PREFIX/bin/pip3" "$BREW_PREFIX/bin/pip" 2>/dev/null && print_success "Created symlink: pip -> pip3"
        else
            sudo ln -sf "$BREW_PREFIX/bin/python3" "$BREW_PREFIX/bin/python" && print_success "Created symlink: python -> python3"
            sudo ln -sf "$BREW_PREFIX/bin/pip3" "$BREW_PREFIX/bin/pip" && print_success "Created symlink: pip -> pip3"
        fi
        
        echo ""
        print_status "All pip packages will install to this single Python installation."
        print_status "You can now use 'python' and 'pip' commands directly (no need for 'python3' or 'pip3')."
        echo ""
        
        if [ -f "$DOTFILES/brew/rebuild.sh" ]; then
            print_status "Rebuilding affected Homebrew packages..."
            bash "$DOTFILES/brew/rebuild.sh"
        else
            print_warning "Rebuild packages script not found at $DOTFILES/brew/rebuild.sh"
            print_warning "Some Homebrew packages might need to be rebuilt."
            print_warning "You can rebuild them with: brew pristine <package-name>"
        fi
        return 0
    else
        print_error "Failed to install the following Python packages:"
        printf '%s\n' "${failed_packages[@]}"
        return 1
    fi
}

find_brew || true
setup_python_environment