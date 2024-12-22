#!/usr/bin/env bash

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

# Get all installed packages
print_status "Finding packages that depend on Python..."

DEPENDENT_PACKAGES=()
# Loop through all installed formulae
while read -r formula; do
    # Check if this formula depends on any python version
    if brew deps --installed "$formula" | grep -q "python@"; then
        DEPENDENT_PACKAGES+=("$formula")
    fi
done < <(brew list --formula)

if [ ${#DEPENDENT_PACKAGES[@]} -eq 0 ]; then
    print_warning "No packages found that depend on Python"
    exit 0
fi

print_status "Found ${#DEPENDENT_PACKAGES[@]} packages to rebuild"

# Rebuild each package
for package in "${DEPENDENT_PACKAGES[@]}"; do
    print_status "Rebuilding $package..."
    if brew pristine "$package" &>/dev/null; then
        print_success "Rebuilt $package"
    else
        print_error "Failed to rebuild $package"
    fi
done

print_success "Finished rebuilding packages"