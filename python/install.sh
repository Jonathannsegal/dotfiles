#!/usr/bin/env bash

set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
HARD_SETUP="${DOTFILES_HARD_SETUP:-false}"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

print_status() {
    printf "\r [ \033[00;34m..\033[0m ] %s\n" "$1"
}

print_success() {
    printf "\r\033[2K [ \033[00;32mOK\033[0m ] %s\n" "$1"
}

print_warning() {
    printf "\r\033[2K [ \033[00;33mWARN\033[0m ] %s\n" "$1"
}

print_error() {
    printf "\r\033[2K [\033[0;31mFAIL\033[0m] %s\n" "$1"
}

if ! command -v brew >/dev/null 2>&1; then
    print_error "Homebrew is required before Python setup"
    exit 1
fi

print_status "Ensuring Homebrew Python is installed"
if brew list --formula python@3.14 >/dev/null 2>&1; then
    print_success "python@3.14 is already installed"
elif brew install python@3.14 >/dev/null 2>&1; then
    :
elif brew list --formula python >/dev/null 2>&1; then
    print_success "python is already installed"
else
    brew install python >/dev/null
fi

BREW_PREFIX="$(brew --prefix)"
PYTHON_BIN="$BREW_PREFIX/bin/python3"

if [[ ! -x "$PYTHON_BIN" ]]; then
    PYTHON_BIN="$(command -v python3 || true)"
fi

if [[ -z "$PYTHON_BIN" || ! -x "$PYTHON_BIN" ]]; then
    print_error "Could not find Homebrew python3"
    exit 1
fi

mkdir -p "$DOTFILES/python/zsh"
python_zsh="$DOTFILES/python/zsh/python.zsh"
python_zsh_tmp="$(mktemp)"
cat > "$python_zsh_tmp" <<'EOF'
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
EOF

if [[ -f "$python_zsh" ]] && cmp -s "$python_zsh_tmp" "$python_zsh"; then
    rm -f "$python_zsh_tmp"
else
    mv "$python_zsh_tmp" "$python_zsh"
fi

PIP_FLAGS=()
if "$PYTHON_BIN" -m pip --version >/dev/null 2>&1; then
    PIP_FLAGS=(--break-system-packages)
else
    "$PYTHON_BIN" -m ensurepip --upgrade >/dev/null 2>&1 || true
fi

packages=(
    pip
    setuptools
    wheel
    pipenv
    poetry
    black
    flake8
    mypy
    pytest
    jupyter
    notebook
    pandas
    numpy
    matplotlib
    seaborn
    scikit-learn
    scipy
    requests
    pylint
)

failed_packages=()
for package in "${packages[@]}"; do
    if [[ "$HARD_SETUP" == false ]] && "$PYTHON_BIN" -m pip show "$package" >/dev/null 2>&1; then
        print_success "$package is already installed"
        continue
    fi

    if [[ "$HARD_SETUP" == true ]]; then
        print_status "Repairing $package"
        pip_args=(install --upgrade)
    else
        print_status "Installing $package"
        pip_args=(install)
    fi

    log_file="$(mktemp "${TMPDIR:-/tmp}/dotfiles-pip-${package//[^A-Za-z0-9_.-]/_}.XXXXXX.log")"
    if "$PYTHON_BIN" -m pip "${pip_args[@]}" "${PIP_FLAGS[@]}" "$package" >"$log_file" 2>&1; then
        rm -f "$log_file"
        print_success "$package is installed"
    else
        print_warning "Failed to install $package; log: $log_file"
        tail -n 20 "$log_file" >&2 || true
        failed_packages+=("$package")
    fi
done

if [[ ${#failed_packages[@]} -gt 0 ]]; then
    print_error "Some Python packages failed: ${failed_packages[*]}"
    exit 1
fi

print_success "Python setup complete: $("$PYTHON_BIN" --version 2>&1) at $PYTHON_BIN"
