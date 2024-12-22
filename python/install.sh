#!/usr/bin/env bash

# Function to get latest stable Python version
get_latest_python_version() {
    pyenv install --list | grep -E "^\s*[0-9]+\.[0-9]+\.[0-9]+$" | tail -1 | tr -d '[:space:]'
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

# Check if pyenv is installed
if ! command -v pyenv >/dev/null; then
    print_error "pyenv is not installed. Please install it first using Homebrew."
    exit 1
fi

# Get the latest Python version
PYTHON_VERSION=$(get_latest_python_version)

# Clean up existing Python installations
print_status "Checking for existing Python installations..."

# Remove Homebrew Python if installed
if brew list | grep -q "python@"; then
    print_status "Removing Homebrew Python installations..."
    brew list | grep "python@" | while read formula; do
        if brew uninstall --force "$formula"; then
            print_success "Removed Homebrew Python: $formula"
        else
            print_error "Failed to remove Homebrew Python: $formula"
        fi
    done
fi

# Remove other pyenv Python versions except the target version
print_status "Cleaning up pyenv Python versions..."
current_versions=$(pyenv versions --bare | grep -v "$PYTHON_VERSION")
if [ ! -z "$current_versions" ]; then
    echo "$current_versions" | while read -r version; do
        if pyenv uninstall -f "$version" 2>/dev/null; then
            print_success "Removed Python $version"
        else
            print_error "Failed to remove Python $version"
        fi
    done
fi

print_status "Installing Python $PYTHON_VERSION..."

if ! pyenv versions | grep -q "$PYTHON_VERSION"; then
    if CFLAGS="-I$(brew --prefix openssl)/include" \
       LDFLAGS="-L$(brew --prefix openssl)/lib" \
       pyenv install "$PYTHON_VERSION" 2>/dev/null; then
        print_success "Installed Python $PYTHON_VERSION"
    else
        print_error "Failed to install Python $PYTHON_VERSION"
        exit 1
    fi
else
    print_success "Python $PYTHON_VERSION already installed"
fi

# Set global Python version
pyenv global $PYTHON_VERSION

# Install Python packages
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
    "streamlit"
)
failed_packages=()
total=${#packages[@]}
current=0

# Upgrade pip first
python -m pip install --upgrade pip

for package in "${packages[@]}"; do
    ((current++))
    print_status "($current/$total) Installing $package..."
    if python -m pip install "$package" &>/dev/null; then
        print_success "($current/$total) Installed $package"
    else
        print_error "($current/$total) Failed to install $package"
        failed_packages+=("$package")
    fi
done

if [ ${#failed_packages[@]} -eq 0 ]; then
    print_success "Python development environment configured successfully!"
    exit 0
else
    print_error "Failed to install the following Python packages:"
    printf '%s\n' "${failed_packages[@]}"
    exit 1
fi