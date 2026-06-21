#!/usr/bin/env bash

set -euo pipefail

APP_PATH="/Applications/Lens Studio.app"
DOWNLOAD_PAGE="https://ar.snap.com/download"
DOWNLOAD_API="https://ar-web-api.snapchat.com/api/ls-download/"
PLATFORM="MAC_OS_ARM"
CACHE_DIR="${HOME}/Library/Caches/dotfiles/lens-studio"

info() {
    printf "\r [ \033[00;34m..\033[0m ] %s\n" "$1"
}

success() {
    printf "\r\033[2K [ \033[00;32mOK\033[0m ] %s\n" "$1"
}

warn() {
    printf "\r\033[2K [ \033[00;33mWARN\033[0m ] %s\n" "$1"
}

fail() {
    printf "\r\033[2K [\033[0;31mFAIL\033[0m] %s\n" "$1"
    exit 1
}

usage() {
    cat <<EOF
Usage: macos/lens-studio.sh [--force] [--dry-run]

Install or update Snap Lens Studio for Apple Silicon from Snap's official
download API. Skips installation when the current app already matches the
latest version.

Options:
  --force   Reinstall even when the current version is already installed.
  --dry-run Report the current/latest versions and download URL without installing.
  -h, --help
            Show this help.
EOF
}

FORCE=false
DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force) FORCE=true ;;
        --dry-run) DRY_RUN=true ;;
        -h|--help) usage; exit 0 ;;
        *) fail "Unknown option: $1" ;;
    esac
    shift
done

if [[ "$(uname -s)" != "Darwin" ]]; then
    success "Skipped Lens Studio outside macOS"
    exit 0
fi

if [[ "$(uname -m)" != "arm64" ]]; then
    warn "Lens Studio installer is configured for Apple Silicon only; skipping"
    exit 0
fi

run_sudo() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

current_version() {
    if [[ ! -d "$APP_PATH" ]]; then
        return 0
    fi

    /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
        "$APP_PATH/Contents/Info.plist" 2>/dev/null || true
}

public_version() {
    printf "%s" "$1" | sed -E 's/^([0-9]+[.][0-9]+[.][0-9]+).*/\1/'
}

latest_version() {
    curl -fsSL "$DOWNLOAD_PAGE" | perl -0ne '
        while (/"initialValue":"([0-9]+(?:\.[0-9]+){1,3})"/g) {
            $seen{$1} = 1;
        }
        END {
            @versions = sort {
                @aa = split(/\./, $a);
                @bb = split(/\./, $b);
                for ($i = 0; $i < 4; $i++) {
                    $cmp = (($aa[$i] // 0) <=> ($bb[$i] // 0));
                    return $cmp if $cmp != 0;
                }
                0;
            } keys %seen;
            if (@versions) {
                print $versions[-1];
            }
        }
    '
}

json_url() {
    if command -v jq >/dev/null 2>&1; then
        jq -r ".url"
    elif command -v plutil >/dev/null 2>&1; then
        plutil -extract url raw -o - -
    else
        perl -0ne 'print "$1\n" if /"url"\s*:\s*"([^"]+)"/'
    fi
}

download_url_for_version() {
    local version="$1"
    local payload
    payload="$(printf '{"eula":true,"platform":"%s","version":"%s","locale":"en-US","country":"US"}' "$PLATFORM" "$version")"

    curl -fsSL -X POST "$DOWNLOAD_API" \
        -H "Content-Type: application/json" \
        --data "$payload" | json_url
}

install_lens_studio() {
    local version="$1"
    local url="$2"
    local tmp_dir dmg_path cached_dmg mount_dir source_app

    tmp_dir="$(mktemp -d)"
    dmg_path="$tmp_dir/lens-studio.dmg"
    cached_dmg="$CACHE_DIR/Lens_Studio_${version}_mac_arm64.dmg"
    mount_dir="$tmp_dir/mount"
    mkdir -p "$mount_dir"
    mkdir -p "$CACHE_DIR"

    cleanup() {
        if mount | grep -Fq "$mount_dir"; then
            hdiutil detach "$mount_dir" -quiet || true
        fi
        rm -rf "$tmp_dir"
    }
    trap cleanup EXIT

    info "Downloading Lens Studio $version (about 1 GB; resumable)"
    curl --fail --location --continue-at - \
        --retry 5 --retry-delay 5 --retry-all-errors \
        --connect-timeout 30 \
        "$url" -o "$cached_dmg"
    cp "$cached_dmg" "$dmg_path"

    info "Mounting Lens Studio installer"
    hdiutil attach "$dmg_path" -nobrowse -readonly -mountpoint "$mount_dir" -quiet

    source_app="$(find "$mount_dir" -maxdepth 2 -name "Lens Studio.app" -type d | head -n 1)"
    [[ -n "$source_app" ]] || fail "Lens Studio.app was not found in the DMG"

    if pgrep -x "Lens Studio" >/dev/null 2>&1; then
        warn "Quitting Lens Studio before update"
        osascript -e 'tell application "Lens Studio" to quit' >/dev/null 2>&1 || true
        sleep 3
    fi

    info "Installing Lens Studio $version"
    run_sudo rm -rf "$APP_PATH"
    run_sudo ditto "$source_app" "$APP_PATH"
    success "Lens Studio $version installed"
}

main() {
    local installed installed_public latest url

    installed="$(current_version)"
    installed_public="$(public_version "$installed")"
    latest="$(latest_version)"
    [[ -n "$latest" ]] || fail "Could not determine the latest Lens Studio version"

    if [[ "$FORCE" == false && "$installed_public" == "$latest" ]]; then
        success "Lens Studio $installed is already installed"
        return 0
    fi

    url="$(download_url_for_version "$latest")"
    [[ "$url" == https://* ]] || fail "Could not get Lens Studio download URL"

    if [[ "$DRY_RUN" == true ]]; then
        info "Installed Lens Studio: ${installed:-not installed}"
        info "Latest Lens Studio: $latest"
        info "Download URL resolved for $PLATFORM"
        return 0
    fi

    install_lens_studio "$latest" "$url"
}

main "$@"
