#!/bin/bash

set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

AUTO_MODE=false
SKIP_PRIVILEGED=false
CLEAR_CACHE=true
APPLIED_ANY=false
FORCE_ICON_APPLY=false
TERMINAL_RELAUNCH=false
SUDO_KEEPALIVE_PID=""
ORIGINAL_ARGS=("$@")

stop_sudo_keepalive() {
    if [[ -n "$SUDO_KEEPALIVE_PID" ]]; then
        kill "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1 || true
    fi
}

trap stop_sudo_keepalive EXIT

ensure_sudo_keepalive() {
    if [[ "$(id -u)" -eq 0 ]]; then
        return 0
    fi

    command -v sudo >/dev/null 2>&1 || {
        echo "sudo is required for privileged icon setup"
        exit 1
    }

    if [[ -n "$SUDO_KEEPALIVE_PID" ]] && kill -0 "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1; then
        return 0
    fi

    if ! sudo -n true >/dev/null 2>&1; then
        echo "Requesting administrator password once for icon setup..."
        sudo -v
    fi

    while true; do
        sudo -n true >/dev/null 2>&1 || exit
        sleep 60
        kill -0 "$$" >/dev/null 2>&1 || exit
    done 2>/dev/null &
    SUDO_KEEPALIVE_PID="$!"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto)
            AUTO_MODE=true
            SKIP_PRIVILEGED=true
            CLEAR_CACHE=false
            shift
            ;;
        --skip-privileged)
            SKIP_PRIVILEGED=true
            shift
            ;;
        --no-cache-clear)
            CLEAR_CACHE=false
            shift
            ;;
        --force)
            FORCE_ICON_APPLY=true
            shift
            ;;
        --terminal-relaunch)
            TERMINAL_RELAUNCH=true
            shift
            ;;
        --no-terminal-relaunch)
            TERMINAL_RELAUNCH=false
            shift
            ;;
        --help|-h)
            echo "Usage: setup.sh [--auto] [--skip-privileged] [--no-cache-clear] [--force] [--terminal-relaunch]"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ "$SKIP_PRIVILEGED" == true ]]; then
    CLEAR_CACHE=false
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Skipping icon setup outside macOS"
    exit 0
fi

process_tree_contains() {
    local pattern="$1"
    local pid="$PPID"
    local parent command

    while [[ -n "$pid" && "$pid" != "0" ]]; do
        command="$(ps -p "$pid" -o command= 2>/dev/null || true)"
        [[ -n "$command" ]] || break
        if [[ "$command" == *"$pattern"* ]]; then
            return 0
        fi
        parent="$(ps -p "$pid" -o ppid= 2>/dev/null | tr -d ' ' || true)"
        pid="$parent"
    done

    return 1
}

running_from_app_managed_terminal() {
    [[ "${TERM_PROGRAM:-}" == "vscode" ]] && return 0
    process_tree_contains "Visual Studio Code" && return 0
    process_tree_contains "Code Helper" && return 0
    process_tree_contains ".vscode/extensions" && return 0
    return 1
}

relaunch_in_terminal_if_needed() {
    local script_path script_dir command arg quoted

    [[ "$AUTO_MODE" == false ]] || return 0
    [[ "$TERMINAL_RELAUNCH" == true ]] || return 0
    running_from_app_managed_terminal || return 0
    command -v osascript >/dev/null 2>&1 || return 0

    script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    script_dir="$(cd "$(dirname "$script_path")/../.." && pwd)"
    printf -v command "cd %q && /bin/bash %q" "$script_dir" "$script_path"
    for arg in "${ORIGINAL_ARGS[@]}"; do
        [[ "$arg" == "--no-terminal-relaunch" ]] && continue
        printf -v quoted "%q" "$arg"
        command+=" $quoted"
    done
    command+=" --no-terminal-relaunch"

    echo "Relaunching icon setup in Terminal.app."
    osascript - "$command" <<'APPLESCRIPT' >/dev/null
on run argv
  tell application "Terminal"
    activate
    do script (item 1 of argv)
  end tell
end run
APPLESCRIPT
    echo "Continue in the Terminal.app window that just opened."
    exit 0
}

relaunch_in_terminal_if_needed

if ! command -v fileicon >/dev/null 2>&1; then
    if [[ "$AUTO_MODE" == true ]]; then
        echo "Skipping icon setup because fileicon is not available in auto mode"
        exit 0
    fi

    if ! command -v brew >/dev/null 2>&1; then
        echo "Homebrew is required to install fileicon"
        exit 1
    fi

    echo "Installing fileicon..."
    brew install fileicon
fi

# Directory containing icons
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ICONS_DIR="$SCRIPT_DIR/icons"

fileicon_set_quiet() {
    local output

    if output="$("$@" 2>&1)"; then
        [[ -n "$output" ]] && printf "%s\n" "$output"
        return 0
    fi

    return 1
}

icon_file_path() {
    printf "%s/Icon\r" "$1"
}

run_maybe_sudo() {
    local use_sudo="$1"
    shift

    if [[ "$use_sudo" == true ]]; then
        sudo "$@"
    else
        "$@"
    fi
}

clear_icon_state() {
    local app_path="$1"
    local use_sudo="${2:-false}"
    local icon_file

    icon_file="$(icon_file_path "$app_path")"

    if [[ "$use_sudo" == true ]]; then
        fileicon_set_quiet sudo fileicon rm "$app_path" || true
        sudo xattr -d com.apple.FinderInfo "$app_path" >/dev/null 2>&1 || true
        sudo rm -f "$icon_file" >/dev/null 2>&1 || true
    else
        fileicon_set_quiet fileicon rm "$app_path" || true
        xattr -d com.apple.FinderInfo "$app_path" >/dev/null 2>&1 || true
        rm -f "$icon_file" >/dev/null 2>&1 || true
    fi
}

repair_app_write_barriers() {
    local app_path="$1"
    local use_sudo="${2:-true}"

    run_maybe_sudo "$use_sudo" chflags -R nouchg,noschg "$app_path" >/dev/null 2>&1 || true
    run_maybe_sudo "$use_sudo" xattr -dr com.apple.macl "$app_path" >/dev/null 2>&1 || true
    run_maybe_sudo "$use_sudo" xattr -dr com.apple.provenance "$app_path" >/dev/null 2>&1 || true
    run_maybe_sudo "$use_sudo" xattr -dr com.apple.quarantine "$app_path" >/dev/null 2>&1 || true
    run_maybe_sudo "$use_sudo" chmod u+w "$app_path" >/dev/null 2>&1 || true
}

can_modify_app_bundle() {
    local app_path="$1"
    local use_sudo="${2:-false}"
    local test_file

    test_file="$app_path/.dotfiles-icon-write-test.$$"
    if run_maybe_sudo "$use_sudo" touch "$test_file" >/dev/null 2>&1; then
        run_maybe_sudo "$use_sudo" rm -f "$test_file" >/dev/null 2>&1 || true
        return 0
    fi

    return 1
}

verify_custom_icon() {
    local app_path="$1"
    local attempt

    for attempt in 1 2 3 4 5; do
        if fileicon test "$app_path" >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.2
    done

    return 1
}

bundle_icon_resource_update_needed() {
    case "$1" in
        *"/Xcode.app"|*"/Adobe Illustrator.app"|*"/Adobe Lightroom Classic.app")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

create_icns_from_png() {
    local icon_path="$1"
    local icns_path="$2"
    local iconset iconset_dir

    iconset_dir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-iconset.XXXXXX")"
    iconset="$iconset_dir/icon.iconset"
    mkdir -p "$iconset"

    /usr/bin/sips -z 16 16 "$icon_path" --out "$iconset/icon_16x16.png" >/dev/null 2>&1
    /usr/bin/sips -z 32 32 "$icon_path" --out "$iconset/icon_16x16@2x.png" >/dev/null 2>&1
    /usr/bin/sips -z 32 32 "$icon_path" --out "$iconset/icon_32x32.png" >/dev/null 2>&1
    /usr/bin/sips -z 64 64 "$icon_path" --out "$iconset/icon_32x32@2x.png" >/dev/null 2>&1
    /usr/bin/sips -z 128 128 "$icon_path" --out "$iconset/icon_128x128.png" >/dev/null 2>&1
    /usr/bin/sips -z 256 256 "$icon_path" --out "$iconset/icon_128x128@2x.png" >/dev/null 2>&1
    /usr/bin/sips -z 256 256 "$icon_path" --out "$iconset/icon_256x256.png" >/dev/null 2>&1
    /usr/bin/sips -z 512 512 "$icon_path" --out "$iconset/icon_256x256@2x.png" >/dev/null 2>&1
    /usr/bin/sips -z 512 512 "$icon_path" --out "$iconset/icon_512x512.png" >/dev/null 2>&1
    /usr/bin/sips -z 1024 1024 "$icon_path" --out "$iconset/icon_512x512@2x.png" >/dev/null 2>&1

    if /usr/bin/iconutil -c icns "$iconset" -o "$icns_path" >/dev/null 2>&1; then
        rm -rf "$iconset_dir"
        return 0
    fi

    rm -rf "$iconset_dir"
    return 1
}

bundle_icon_resource_path() {
    local app_path="$1"
    local icon_name target

    icon_name="$(/usr/bin/defaults read "$app_path/Contents/Info" CFBundleIconFile 2>/dev/null || true)"
    [[ -n "$icon_name" ]] || icon_name="$(/usr/bin/defaults read "$app_path/Contents/Info" CFBundleIconName 2>/dev/null || true)"
    [[ -n "$icon_name" ]] || return 1

    [[ "$icon_name" == *.icns ]] || icon_name="${icon_name}.icns"
    target="$app_path/Contents/Resources/$icon_name"

    [[ -f "$target" ]] || return 1
    printf "%s" "$target"
}

replace_bundle_icon_resource() {
    local app_path="$1"
    local icon_path="$2"
    local use_sudo="${3:-false}"
    local target generated generated_dir backup

    bundle_icon_resource_update_needed "$app_path" || return 1
    target="$(bundle_icon_resource_path "$app_path")" || return 1
    generated_dir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-bundle-icon.XXXXXX")"
    generated="$generated_dir/icon.icns"

    if ! create_icns_from_png "$icon_path" "$generated"; then
        rm -rf "$generated_dir"
        return 1
    fi

    backup="${target}.dotfiles-original"
    if [[ "$use_sudo" == true ]]; then
        sudo /bin/bash -s -- "$app_path" "$target" "$generated" "$backup" <<'ROOTSCRIPT'
set -euo pipefail
app_path="$1"
target="$2"
generated="$3"
backup="$4"

/usr/bin/chflags nouchg,noschg "$target" >/dev/null 2>&1 || true
if [[ ! -f "$backup" ]]; then
  /bin/cp -p "$target" "$backup"
fi
/bin/cp "$generated" "$target"
/usr/sbin/chown root:wheel "$target" >/dev/null 2>&1 || true
/bin/chmod 0644 "$target" >/dev/null 2>&1 || true
/usr/bin/touch "$target" "$app_path" >/dev/null 2>&1 || true
ROOTSCRIPT
    else
        chflags nouchg,noschg "$target" >/dev/null 2>&1 || true
        [[ -f "$backup" ]] || cp -p "$target" "$backup"
        cp "$generated" "$target"
        touch "$target" "$app_path" >/dev/null 2>&1 || true
    fi

    local result=$?
    rm -rf "$generated_dir"
    [[ "$result" -eq 0 ]]
}

apply_icon_resource_fork() {
    local app_path="$1"
    local icon_path="$2"
    local use_sudo="${3:-false}"
    local tmp_icon tmp_rsrc icon_file

    command -v sips >/dev/null 2>&1 || return 1
    command -v DeRez >/dev/null 2>&1 || return 1
    command -v Rez >/dev/null 2>&1 || return 1
    command -v SetFile >/dev/null 2>&1 || return 1

    tmp_icon="$(mktemp "${TMPDIR:-/tmp}/dotfiles-icon-png.XXXXXX")"
    tmp_rsrc="$(mktemp "${TMPDIR:-/tmp}/dotfiles-icon-rsrc.XXXXXX")"
    icon_file="$(icon_file_path "$app_path")"

    cp "$icon_path" "$tmp_icon" || {
        rm -f "$tmp_icon" "$tmp_rsrc"
        return 1
    }
    xattr -c "$tmp_icon" >/dev/null 2>&1 || true

    if ! sips -i "$tmp_icon" >/dev/null 2>&1 ||
       ! DeRez -only icns "$tmp_icon" > "$tmp_rsrc" 2>/dev/null; then
        rm -f "$tmp_icon" "$tmp_rsrc"
        return 1
    fi

    if [[ "$use_sudo" == true ]]; then
        if sudo /bin/bash -s -- "$app_path" "$tmp_rsrc" <<'ROOTSCRIPT'
set -euo pipefail
app_path="$1"
tmp_rsrc="$2"
icon_file="${app_path}/Icon"$'\r'

/usr/bin/chflags -R nouchg,noschg "$app_path" >/dev/null 2>&1 || true
/usr/bin/xattr -dr com.apple.macl "$app_path" >/dev/null 2>&1 || true
/usr/bin/xattr -dr com.apple.provenance "$app_path" >/dev/null 2>&1 || true
/usr/bin/xattr -dr com.apple.quarantine "$app_path" >/dev/null 2>&1 || true
/bin/chmod u+w "$app_path" >/dev/null 2>&1 || true
/usr/bin/xattr -d com.apple.FinderInfo "$app_path" >/dev/null 2>&1 || true
/bin/rm -f "$icon_file" >/dev/null 2>&1 || true
/usr/bin/touch "$icon_file"
/usr/bin/Rez -append "$tmp_rsrc" -o "$icon_file" >/dev/null 2>&1
/usr/bin/SetFile -a V "$icon_file" >/dev/null 2>&1
/usr/bin/SetFile -a C "$app_path" >/dev/null 2>&1
ROOTSCRIPT
        then
            if verify_custom_icon "$app_path"; then
                rm -f "$tmp_icon" "$tmp_rsrc"
                return 0
            fi
        fi

        rm -f "$tmp_icon" "$tmp_rsrc"
        return 1
    fi

    run_maybe_sudo "$use_sudo" touch "$icon_file" >/dev/null 2>&1 || {
        rm -f "$tmp_icon" "$tmp_rsrc"
        return 1
    }

    if run_maybe_sudo "$use_sudo" Rez -append "$tmp_rsrc" -o "$icon_file" >/dev/null 2>&1 &&
       run_maybe_sudo "$use_sudo" SetFile -a V "$icon_file" >/dev/null 2>&1 &&
       run_maybe_sudo "$use_sudo" SetFile -a C "$app_path" >/dev/null 2>&1 &&
       verify_custom_icon "$app_path"; then
        rm -f "$tmp_icon" "$tmp_rsrc"
        return 0
    fi

    rm -f "$tmp_icon" "$tmp_rsrc"
    return 1
}

set_icon_verified() {
    local app_path="$1"
    local icon_path="$2"
    local use_sudo="${3:-false}"
    local folder_icon_set=false

    if apply_icon_resource_fork "$app_path" "$icon_path" "$use_sudo"; then
        echo "Custom icon assigned to folder '$app_path' based on '$icon_path'."
        folder_icon_set=true
    fi

    if bundle_icon_resource_update_needed "$app_path" &&
       replace_bundle_icon_resource "$app_path" "$icon_path" "$use_sudo"; then
        echo "Bundle icon resource updated for '$app_path'."
        return 0
    fi

    if [[ "$folder_icon_set" == true ]]; then
        return 0
    fi

    clear_icon_state "$app_path" "$use_sudo"

    if [[ "$use_sudo" == true ]]; then
        fileicon_set_quiet sudo fileicon set "$app_path" "$icon_path" || return 1
    else
        fileicon_set_quiet fileicon set "$app_path" "$icon_path" || return 1
    fi

    if verify_custom_icon "$app_path"; then
        return 0
    fi

    if bundle_icon_resource_update_needed "$app_path" &&
       replace_bundle_icon_resource "$app_path" "$icon_path" "$use_sudo"; then
        echo "Bundle icon resource updated for '$app_path'."
        return 0
    fi

    return 1
}

# Function to apply icon
apply_icon() {
    local app_path="$1"
    local icon_path="$2"
    local needs_sudo=false
    
    if [ -e "$app_path" ] && [ -f "$icon_path" ]; then
        if [[ "$FORCE_ICON_APPLY" == false ]] && fileicon test "$app_path" >/dev/null 2>&1; then
            echo "Skipping $app_path (custom icon already set)"
            return 0
        fi

        echo "Applying $icon_path to $app_path"

        if [[ "$app_path" != "/System/"* ]]; then
            repair_app_write_barriers "$app_path" false
        fi

        if [[ "$app_path" == "/System/"* ]] || ! can_modify_app_bundle "$app_path"; then
            needs_sudo=true
        fi

        if [[ "$needs_sudo" == true ]]; then
            if [[ "$SKIP_PRIVILEGED" == true ]]; then
                echo "Skipping app that needs elevated icon permissions in auto mode: $app_path"
            else
                ensure_sudo_keepalive
                repair_app_write_barriers "$app_path" true
                if [[ "$app_path" != "/System/"* ]] && ! can_modify_app_bundle "$app_path" true; then
                    echo "Skipping $app_path (macOS denied administrator writes into this app; allow your terminal in Privacy & Security app management settings)"
                    return 0
                fi
                clear_icon_state "$app_path" true
                if set_icon_verified "$app_path" "$icon_path" true; then
                    APPLIED_ANY=true
                else
                    echo "Skipping $app_path (custom icon could not be applied; the app may be protected by macOS)"
                    return 0
                fi
            fi
        else
            if [[ "$FORCE_ICON_APPLY" == true ]]; then
                clear_icon_state "$app_path" false
            fi

            if ! set_icon_verified "$app_path" "$icon_path" false; then
                if [[ "$SKIP_PRIVILEGED" == true ]]; then
                    echo "Skipping app that needs elevated icon permissions in auto mode: $app_path"
                    return 0
                fi

                echo "Retrying with administrator permissions: $app_path"
                ensure_sudo_keepalive
                repair_app_write_barriers "$app_path" true
                if [[ "$app_path" != "/System/"* ]] && ! can_modify_app_bundle "$app_path" true; then
                    echo "Skipping $app_path (macOS denied administrator writes into this app; allow your terminal in Privacy & Security app management settings)"
                    return 0
                fi
                clear_icon_state "$app_path" true
                if ! set_icon_verified "$app_path" "$icon_path" true; then
                    echo "Skipping $app_path (custom icon could not be applied)"
                    return 0
                fi
            fi
            APPLIED_ANY=true
        fi
    else
        echo "Skipping $app_path (app or icon not found)"
    fi
}

apply_first_found() {
    local icon_path="$1"
    shift

    local candidate
    for candidate in "$@"; do
        if [[ -e "$candidate" ]]; then
            apply_icon "$candidate" "$icon_path"
            return 0
        fi
    done

    echo "Skipping $(basename "$icon_path" .png) (app not found)"
}

# Apply icons
apply_icon "/Applications/Google Chrome.app" "$ICONS_DIR/chrome.png"

# Resolve Adobe Illustrator path dynamically (handles different yearly versions)
shopt -s nullglob
ILLUSTRATOR_CANDIDATES=(/Applications/Adobe\ Illustrator*/Adobe\ Illustrator*.app)
shopt -u nullglob
if [ ${#ILLUSTRATOR_CANDIDATES[@]} -gt 0 ]; then
    apply_icon "${ILLUSTRATOR_CANDIDATES[0]}" "$ICONS_DIR/illustrator.png"
else
    echo "Skipping Adobe Illustrator (app not found)"
fi
apply_icon "/Applications/iTerm.app" "$ICONS_DIR/iterm2.png"
apply_icon "/Applications/Adobe Lightroom Classic/Adobe Lightroom Classic.app" "$ICONS_DIR/lightroom.png"
apply_icon "/Applications/Notion.app" "$ICONS_DIR/notion.png"
apply_icon "/Applications/Slack.app" "$ICONS_DIR/slack.png"
apply_icon "/Applications/Unity Hub.app" "$ICONS_DIR/unityhub.png"
apply_icon "/Applications/Visual Studio Code.app" "$ICONS_DIR/vscode.png"
apply_icon "/Applications/zoom.us.app" "$ICONS_DIR/zoom.png"
apply_first_found "$ICONS_DIR/zotero.png" "/Applications/Zotero.app" "/Applications/zotero.app"
apply_icon "/Applications/ATLAS.ti.app" "$ICONS_DIR/atlasti.png"
apply_icon "/Applications/Blender.app" "$ICONS_DIR/blender.png"
apply_icon "/Applications/Lens Studio.app" "$ICONS_DIR/lense.png"
apply_icon "/Applications/Xcode.app" "$ICONS_DIR/xcode.png"
apply_first_found "$ICONS_DIR/messages.png" "/System/Applications/Messages.app" "/Applications/Messages.app"
apply_first_found "$ICONS_DIR/mail.png" "/System/Applications/Mail.app" "/Applications/Mail.app"
apply_first_found "$ICONS_DIR/photos.png" "/System/Applications/Photos.app" "/Applications/Photos.app"
apply_first_found "$ICONS_DIR/facetime.png" "/System/Applications/FaceTime.app" "/Applications/FaceTime.app"

if [[ "$CLEAR_CACHE" == true && "$APPLIED_ANY" == true ]]; then
    # Clear icon cache with sudo
    echo "Clearing icon cache..."
    ensure_sudo_keepalive
    sudo rm -rf /Library/Caches/com.apple.iconservices.store || true
    sudo find /private/var/folders/ \
        -name com.apple.iconservices -exec sudo rm -rf {} \; >/dev/null 2>&1 || true

    # Restart Finder to refresh icons
    killall Finder >/dev/null 2>&1 || true
    killall Dock >/dev/null 2>&1 || true
else
    echo "Skipping cache clear"
fi

killall Dock >/dev/null 2>&1 || true

echo "Icon setup complete!"
