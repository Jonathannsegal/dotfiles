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
print_warning() {
    printf "\r\033[2K [ \033[00;33mWARN\033[0m ] $1\n"
}

# Ask for confirmation
confirm() {
    read -p " [ ?? ] $1 (y/n) " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Store dependencies using a simple array
DEPS_LIST=()
get_all_dependencies() {
    local package="$1"
    local deps
    
    brew deps --installed "$package" 2>/dev/null | while read -r dep; do
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
    if brew uninstall "$formula" 2>/dev/null; then
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
        if brew uninstall --ignore-dependencies "$formula"; then
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
    # Get the latest Python version
    PYTHON_VERSION=$(get_latest_python_version)

    # Clean up existing Python installations
    print_status "Checking for existing Python installations..."

    # Remove Homebrew Python if installed
    if brew list | grep -q "python@"; then
        print_status "Removing Homebrew Python installations..."
        brew list | grep "python@" | while read formula; do
            version=$(echo "$formula" | sed 's/python@//')
            if ! remove_python_safely "$version"; then
                print_error "Failed to handle Python removal: $formula"
                if [ "$NO_CONFIRM" = true ] || confirm "Continue anyway?"; then
                    return 0
                else
                    exit 1
                fi
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

# Check if pyenv is installed
if ! command -v pyenv >/dev/null; then
    print_error "pyenv is not installed. Please install it first using Homebrew."
    exit 1
fi

# Handle command line arguments
NO_CONFIRM=false
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --no-confirm) NO_CONFIRM=true; shift ;;
        *) print_error "Unknown parameter: $1"; exit 1 ;;
    esac
done

# Only show prompts and info messages if running standalone
if [ "$NO_CONFIRM" = false ]; then
    print_status "setting up python environment"
    if ! confirm "Do you want to set up Python environment?"; then
        exit 0
    fi
    print_status "running python setup script"
fi

setup_python_environment