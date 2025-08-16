#!/usr/bin/env bash

set -E
trap cleanup SIGINT SIGTERM ERR EXIT

# Enable extended pattern matching
shopt -s extglob

# Script initialization and utilities
cleanup() {
    trap - SIGINT SIGTERM ERR EXIT
    # Disable extended pattern matching
    shopt -u extglob
}

setup_colors() {
    if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
        NOFORMAT='\033[0m' 
        RED='\033[0;31m' 
        GREEN='\033[0;32m' 
        BLUE='\033[0;34m'
    else
        NOFORMAT='' RED='' GREEN='' BLUE=''
    fi
}

# Script options
usage() {
    cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-d] [-v]

Mac Cleanup Utility

Available options:
-h, --help      Print this help and exit
-d, --dry-run   Print approximate space to be cleaned
-v, --verbose   Print script debug info
EOF
    exit
}

msg() {
    echo >&2 -e "${1-}"
}

die() {
    local msg=$1
    local code=${2-1}
    msg "$msg"
    exit "$code"
}

parse_params() {
    while :; do
        case "${1-}" in
        -h | --help) usage ;;
        -v | --verbose) set -x ;;
        -d | --dry-run) dry_run=true ;;
        --no-color) NO_COLOR=1 ;;
        -?*) die "Unknown option: $1" ;;
        *) break ;;
        esac
        shift
    done
    return 0
}

# Utility functions
bytesToHuman() {
    b=${1:-0}
    d=''
    s=1
    S=(Bytes {K,M,G,T,E,P,Y,Z}iB)
    while ((b > 1024)); do
        d="$(printf ".%02d" $((b % 1024 * 100 / 1024)))"
        b=$((b / 1024))
        ((s++))
    done
    msg "$b$d ${S[$s]} of space was cleaned up"
}

collect_paths() {
    path_list+=("$@")
}

remove_paths() {
    if [ -z "$dry_run" ]; then
        for path in "${path_list[@]}"; do
            if [ -e "$path" ]; then
                rm -rfv "$path" &>/dev/null || msg "Failed to remove: $path"
            fi
        done
        unset path_list
    fi
}

# Cleanup functions
cleanup_system_caches() {
    msg 'Cleaning System Cache Files...'
    
    # Clean user caches except protected ones
    find ~/Library/Caches -mindepth 1 -maxdepth 1 \
        ! -name "com.apple.*" \
        ! -name "CloudKit" \
        ! -name "FamilyCircle" \
        ! -name "HomeKit" \
        ! -name "Safari" \
        -exec echo {} \; \
        -exec rm -rf {} \; 2>/dev/null

    # Clean logs
    find ~/Library/Logs -mindepth 1 -maxdepth 1 \
        ! -name "com.apple.*" \
        -exec echo {} \; \
        -exec rm -rf {} \; 2>/dev/null
}

cleanup_development_tools() {
    # Clean Xcode
    if [[ -d ~/Library/Developer/Xcode ]]; then
        msg 'Cleaning Xcode caches...'
        collect_paths ~/Library/Developer/Xcode/DerivedData/*
        collect_paths ~/Library/Developer/Xcode/Archives/*
        collect_paths ~/Library/Developer/Xcode/iOS\ Device\ Logs/*
        remove_paths
    fi

    # Clean npm
    if command -v npm &>/dev/null; then
        msg 'Cleaning npm cache...'
        if [ -z "$dry_run" ]; then
            npm cache clean --force &>/dev/null
        fi
    fi

    # Clean yarn
    if command -v yarn &>/dev/null; then
        msg 'Cleaning yarn cache...'
        if [ -z "$dry_run" ]; then
            yarn cache clean --force &>/dev/null
        fi
    fi

    # Clean pip
    if command -v pip3 &>/dev/null; then
        msg 'Cleaning pip cache...'
        if [ -z "$dry_run" ]; then
            pip3 cache purge &>/dev/null
        fi
    fi

    # Clean Gradle
    if [[ -d ~/.gradle ]]; then
        msg 'Cleaning Gradle cache...'
        collect_paths ~/.gradle/caches
        remove_paths
    fi

    # Clean Go cache
    if command -v go &>/dev/null; then
        msg 'Cleaning Go module cache...'
        if [ -z "$dry_run" ]; then
            go clean -modcache &>/dev/null
        fi
    fi
}

cleanup_applications() {
    # Clean Chrome
    if [[ -d ~/Library/Application\ Support/Google/Chrome ]]; then
        msg 'Cleaning Chrome cache...'
        collect_paths ~/Library/Application\ Support/Google/Chrome/Default/Application\ Cache/*
        remove_paths
    fi

    # Clean VS Code
    if [[ -d ~/Library/Application\ Support/Code ]]; then
        msg 'Cleaning VS Code cache...'
        collect_paths ~/Library/Application\ Support/Code/Cache/*
        collect_paths ~/Library/Application\ Support/Code/CachedData/*
        remove_paths
    fi

    # Clean Teams
    if [[ -d ~/Library/Application\ Support/Microsoft/Teams ]]; then
        msg 'Cleaning Teams cache...'
        collect_paths ~/Library/Application\ Support/Microsoft/Teams/Cache
        collect_paths ~/Library/Application\ Support/Microsoft/Teams/Application\ Cache
        collect_paths ~/Library/Application\ Support/Microsoft/Teams/Code\ Cache
        remove_paths
    fi

    # Clean Steam
    if [[ -d ~/Library/Application\ Support/Steam ]]; then
        msg 'Cleaning Steam cache...'
        collect_paths ~/Library/Application\ Support/Steam/appcache
        collect_paths ~/Library/Application\ Support/Steam/depotcache
        collect_paths ~/Library/Application\ Support/Steam/logs
        remove_paths
    fi
}

cleanup_docker() {
    if command -v docker &>/dev/null; then
        msg 'Cleaning Docker system...'
        if [ -z "$dry_run" ]; then
            if ! docker ps >/dev/null 2>&1; then
                open --background -a Docker
                sleep 20  # Wait for Docker to start
            fi
            docker system prune -af &>/dev/null
        fi
    fi
}

cleanup_homebrew() {
    if command -v brew &>/dev/null; then
        msg 'Cleaning Homebrew cache...'
        if [ -z "$dry_run" ]; then
            brew cleanup -s &>/dev/null
            brew tap --repair &>/dev/null
        fi
    fi
}

main() {
    setup_colors
    parse_params "$@"

    # Ask for sudo password upfront
    sudo -v

    # Keep sudo alive
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" || exit
    done 2>/dev/null &

    msg "${BLUE}Starting Mac cleanup...${NOFORMAT}"
    oldAvailable=$(df / | tail -1 | awk '{print $4}')

    # Run cleanup functions
    cleanup_system_caches
    cleanup_development_tools
    cleanup_applications
    cleanup_docker
    cleanup_homebrew

    # Final system cleanup
    if [ -z "$dry_run" ]; then
        msg 'Cleaning up DNS cache...'
        sudo dscacheutil -flushcache &>/dev/null
        sudo killall -HUP mDNSResponder &>/dev/null

        msg 'Purging inactive memory...'
        sudo purge &>/dev/null
    fi

    # Calculate space saved
    newAvailable=$(df / | tail -1 | awk '{print $4}')
    count=$((newAvailable - oldAvailable))
    
    msg "${GREEN}Cleanup complete!${NOFORMAT}"
    bytesToHuman $count
}

main "$@"