#!/usr/bin/env bash

set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
BREWFILE="$DOTFILES/brew/Brewfile"
LAUNCH_CONFIG="$DOTFILES/macos/launchagents.tsv"
HOME_DIR="$HOME"
DEV_DIR="$HOME/Developer"
DOTFILES_DIR="$HOME/dotfiles"
VIOLATIONS=0
SUDO_KEEPALIVE_PID=""

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
    echo "sudo is required for this privileged operation." >&2
    exit 1
  }

  if [[ -n "$SUDO_KEEPALIVE_PID" ]] && kill -0 "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1; then
    return 0
  fi

  if sudo -n true >/dev/null 2>&1; then
    :
  else
    echo "Requesting administrator password once..."
    sudo -v
  fi

  while true; do
    sudo -n true >/dev/null 2>&1 || exit
    sleep 60
    kill -0 "$$" >/dev/null 2>&1 || exit
  done 2>/dev/null &
  SUDO_KEEPALIVE_PID="$!"
}

usage() {
  cat <<EOF
Usage: ./run/setup.sh standards <command> [options]

Commands:
  audit                       Full strict clean-computer audit.
  apps                        Compare installed apps/packages to brew/Brewfile.
  settings                    Compare live macOS defaults to macos/settings.sh.
  home [--dry-run|--apply]    Enforce top-level home folder organization.
  launchagents [audit|apply]  Audit or disable managed background items.
  purge-unwanted [--dry-run]  Remove banned app families and helper services.

The full audit is read-only. Commands ending in apply or purge-unwanted can
change machine state and may ask macOS for an administrator password.
EOF
}

section() {
  printf "\n=== %s ===\n" "$1"
}

violation() {
  VIOLATIONS=$((VIOLATIONS + 1))
  printf "VIOLATION\t%s\n" "$1"
}

brewfile_entries() {
  local kind="$1"
  case "$kind" in
    formula) sed -n 's/^brew "\([^"]*\)".*/\1/p' "$BREWFILE" | sort ;;
    cask) sed -n 's/^cask "\([^"]*\)".*/\1/p' "$BREWFILE" | sort ;;
    vscode) sed -n 's/^vscode "\([^"]*\)".*/\1/p' "$BREWFILE" | sort ;;
    npm) sed -n 's/^npm "\([^"]*\)".*/\1/p' "$BREWFILE" | sort ;;
  esac
}

installed_formulas() {
  brew leaves 2>/dev/null | sort || true
}

installed_formulae_all() {
  brew list --formula 2>/dev/null | sort || true
}

installed_casks() {
  brew list --cask --full-name 2>/dev/null |
    sed 's#^.*/##' |
    sort || true
}

installed_vscode() {
  NODE_NO_WARNINGS=1 code --list-extensions 2>/dev/null | sort || true
}

installed_npm() {
  NODE_NO_WARNINGS=1 npm list -g --depth=0 --parseable 2>/dev/null |
    sed '1d; s#.*/node_modules/##' |
    sed '/^npm$/d' |
    sort || true
}

installed_apps() {
  find /Applications "$HOME/Applications" -maxdepth 2 -name "*.app" -type d 2>/dev/null |
    sed 's#/$##' |
    sort -f
}

expected_cask_apps() {
  local casks
  casks="$(brewfile_entries cask | tr '\n' ' ')"
  [[ -n "${casks// }" ]] || return 0

  if command -v jq >/dev/null 2>&1; then
    brew info --cask --json=v2 $casks 2>/dev/null |
      jq -r '.casks[].artifacts[]? | select(type == "object") | .app? // empty | if type == "array" then .[1].target? // .[0] else empty end' |
      sed 's#^/Applications/##; s#^~/Applications/##; s#\.app$##' |
      sort -u
  else
    brewfile_entries cask
  fi
}

compare_set_report() {
  local title="$1"
  local installed_cmd="$2"
  local expected_cmd="$3"
  local installed expected

  installed="$(mktemp)"
  expected="$(mktemp)"

  eval "$installed_cmd" > "$installed"
  eval "$expected_cmd" > "$expected"

  section "$title: installed but not in Brewfile"
  comm -23 "$installed" "$expected" || true

  section "$title: in Brewfile but not installed"
  comm -13 "$installed" "$expected" || true

  rm -f "$installed" "$expected"
}

formula_report() {
  local installed expected

  installed="$(mktemp)"
  expected="$(mktemp)"

  installed_formulas > "$installed"
  brewfile_entries formula > "$expected"
  section "Formula leaves: installed but not in Brewfile"
  comm -23 "$installed" "$expected" || true

  installed_formulae_all > "$installed"
  section "Formulae: in Brewfile but not installed"
  comm -13 "$installed" "$expected" || true

  rm -f "$installed" "$expected"
}

check_formula_drift() {
  local installed expected extra missing

  installed="$(mktemp)"
  expected="$(mktemp)"

  installed_formulas > "$installed"
  brewfile_entries formula > "$expected"
  extra="$(comm -23 "$installed" "$expected" || true)"

  if [[ -n "$extra" ]]; then
    while IFS= read -r item; do
      [[ -n "$item" ]] && violation "formula installed but not repo-managed: $item"
    done <<< "$extra"
  fi

  installed_formulae_all > "$installed"
  missing="$(comm -13 "$installed" "$expected" || true)"

  if [[ -n "$missing" ]]; then
    while IFS= read -r item; do
      [[ -n "$item" ]] && violation "formula repo-managed but not installed: $item"
    done <<< "$missing"
  fi

  rm -f "$installed" "$expected"
}

check_set_drift() {
  local label="$1"
  local installed_cmd="$2"
  local expected_cmd="$3"
  local installed expected extra missing

  installed="$(mktemp)"
  expected="$(mktemp)"

  eval "$installed_cmd" > "$installed"
  eval "$expected_cmd" > "$expected"

  extra="$(comm -23 "$installed" "$expected" || true)"
  missing="$(comm -13 "$installed" "$expected" || true)"

  if [[ -n "$extra" ]]; then
    while IFS= read -r item; do
      [[ -n "$item" ]] && violation "$label installed but not repo-managed: $item"
    done <<< "$extra"
  fi

  if [[ -n "$missing" ]]; then
    while IFS= read -r item; do
      [[ -n "$item" ]] && violation "$label repo-managed but not installed: $item"
    done <<< "$missing"
  fi

  rm -f "$installed" "$expected"
}

apps_report() {
  [[ -f "$BREWFILE" ]] || {
    echo "Brewfile not found: $BREWFILE" >&2
    exit 1
  }

  formula_report
  compare_set_report "Casks" installed_casks "brewfile_entries cask"
  compare_set_report "VS Code extensions" installed_vscode "brewfile_entries vscode"
  compare_set_report "Global npm packages" installed_npm "brewfile_entries npm"

  section "Visible /Applications inventory"
  installed_apps

  section "Expected cask app names from Brewfile metadata"
  expected_cask_apps || true
}

check_apps() {
  section "Apps And Packages"
  check_formula_drift
  check_set_drift "cask" installed_casks "brewfile_entries cask"
  check_set_drift "VS Code extension" installed_vscode "brewfile_entries vscode"
  check_set_drift "global npm package" installed_npm "brewfile_entries npm"
}

expected_bool() {
  case "$1" in
    true|1) echo 1 ;;
    false|0) echo 0 ;;
    *) echo "$1" ;;
  esac
}

read_default() {
  local domain="$1"
  local key="$2"

  defaults read "$domain" "$key" 2>/dev/null || echo "<unset>"
}

check_default() {
  local domain="$1"
  local key="$2"
  local type="$3"
  local expected="$4"
  local current

  current="$(read_default "$domain" "$key")"
  if [[ "$type" == "bool" ]]; then
    expected="$(expected_bool "$expected")"
    current="$(expected_bool "$current")"
  fi

  if [[ "$current" == "$expected" ]]; then
    printf "OK\t%s\t%s\t%s\n" "$domain" "$key" "$current"
  else
    printf "DIFF\t%s\t%s\texpected=%s\tcurrent=%s\n" "$domain" "$key" "$expected" "$current"
    return 1
  fi
}

check_default_bool_unset_false() {
  local domain="$1"
  local key="$2"
  local current

  current="$(read_default "$domain" "$key")"
  current="$(expected_bool "$current")"

  if [[ "$current" == "0" || "$current" == "<unset>" ]]; then
    printf "OK\t%s\t%s\t%s\n" "$domain" "$key" "$current"
  else
    printf "DIFF\t%s\t%s\texpected=0-or-unset\tcurrent=%s\n" "$domain" "$key" "$current"
    return 1
  fi
}

check_default_unset() {
  local domain="$1"
  local key="$2"
  local current

  current="$(read_default "$domain" "$key")"

  if [[ "$current" == "<unset>" ]]; then
    printf "OK\t%s\t%s\t<unset>\n" "$domain" "$key"
  else
    printf "DIFF\t%s\t%s\texpected=<unset>\tcurrent=%s\n" "$domain" "$key" "$current"
    return 1
  fi
}

check_default_if_set() {
  local domain="$1"
  local key="$2"
  local type="$3"
  local expected="$4"
  local current

  current="$(read_default "$domain" "$key")"
  if [[ "$current" == "<unset>" ]]; then
    printf "OK\t%s\t%s\t<unset accepted>\n" "$domain" "$key"
    return 0
  fi

  if [[ "$type" == "bool" ]]; then
    expected="$(expected_bool "$expected")"
    current="$(expected_bool "$current")"
  fi

  if [[ "$current" == "$expected" ]]; then
    printf "OK\t%s\t%s\t%s\n" "$domain" "$key" "$current"
  else
    printf "DIFF\t%s\t%s\texpected=%s\tcurrent=%s\n" "$domain" "$key" "$expected" "$current"
    return 1
  fi
}

check_current_host_default() {
  local domain="$1"
  local key="$2"
  local type="$3"
  local expected="$4"
  local current

  current="$(defaults -currentHost read "$domain" "$key" 2>/dev/null || echo "<unset>")"
  if [[ "$type" == "bool" ]]; then
    expected="$(expected_bool "$expected")"
    current="$(expected_bool "$current")"
  fi

  if [[ "$current" == "$expected" ]]; then
    printf "OK\t-currentHost %s\t%s\t%s\n" "$domain" "$key" "$current"
  else
    printf "DIFF\t-currentHost %s\t%s\texpected=%s\tcurrent=%s\n" "$domain" "$key" "$expected" "$current"
    return 1
  fi
}

audit_dock() {
  local expected current

  expected="$(grep -vE '^[[:space:]]*(#|$)' "$DOTFILES/macos/dock-items.txt" |
    sed "s#^~/#$HOME/#" |
    tr '\n' '|')"
  current="$(defaults read com.apple.dock persistent-apps 2>/dev/null |
    awk -F'= ' '/"_CFURLString" =/{gsub(/[\";]/,"",$2); gsub("^file://","",$2); gsub("%20"," ",$2); sub("/$","",$2); print $2}' |
    tr '\n' '|')"

  if [[ "$current" == "$expected" ]]; then
    printf "OK\tDock\tpersistent-apps\tmatches %s\n" "$DOTFILES/macos/dock-items.txt"
  else
    printf "DIFF\tDock\tpersistent-apps\texpected=%s\tcurrent=%s\n" "$expected" "$current"
    return 1
  fi
}

settings_audit() {
  local failures=0

  check_default NSGlobalDomain KeyRepeat int 6 || failures=$((failures + 1))
  check_default NSGlobalDomain InitialKeyRepeat int 25 || failures=$((failures + 1))
  check_default NSGlobalDomain ApplePressAndHoldEnabled bool false || failures=$((failures + 1))
  check_default NSGlobalDomain AppleShowAllExtensions bool true || failures=$((failures + 1))
  check_default NSGlobalDomain NSDocumentSaveNewDocumentsToCloud bool false || failures=$((failures + 1))
  check_default NSGlobalDomain NSAutomaticCapitalizationEnabled bool false || failures=$((failures + 1))
  check_default NSGlobalDomain NSAutomaticDashSubstitutionEnabled bool false || failures=$((failures + 1))
  check_default NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled bool false || failures=$((failures + 1))
  check_default NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled bool false || failures=$((failures + 1))
  check_default NSGlobalDomain NSAutomaticSpellingCorrectionEnabled bool false || failures=$((failures + 1))
  check_default_unset NSGlobalDomain AppleInterfaceStyle || failures=$((failures + 1))
  check_default NSGlobalDomain AppleInterfaceStyleSwitchesAutomatically bool false || failures=$((failures + 1))
  check_default NSGlobalDomain _HIHideMenuBar bool false || failures=$((failures + 1))
  check_default NSGlobalDomain AppleMenuBarVisibleInFullscreen bool false || failures=$((failures + 1))
  check_default NSGlobalDomain com.apple.mouse.tapBehavior int 0 || failures=$((failures + 1))
  check_default NSGlobalDomain com.apple.trackpad.forceClick bool true || failures=$((failures + 1))

  check_default com.apple.AppleMultitouchTrackpad Clicking bool false || failures=$((failures + 1))
  check_default com.apple.AppleMultitouchTrackpad TrackpadRightClick bool true || failures=$((failures + 1))
  check_default com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick bool false || failures=$((failures + 1))
  check_default com.apple.AppleMultitouchTrackpad ForceSuppressed bool false || failures=$((failures + 1))

  check_current_host_default com.apple.screensaver idleTime int 180 || failures=$((failures + 1))
  check_default com.apple.screensaver askForPassword int 1 || failures=$((failures + 1))
  check_default com.apple.screensaver askForPasswordDelay int 300 || failures=$((failures + 1))
  check_default com.apple.screencapture target string clipboard || failures=$((failures + 1))
  check_default_unset com.apple.screencapture location || failures=$((failures + 1))
  check_default com.apple.screencapture type string png || failures=$((failures + 1))

  check_default com.apple.finder FXPreferredViewStyle string Nlsv || failures=$((failures + 1))
  check_default com.apple.finder FXPreferredSearchViewStyle string Nlsv || failures=$((failures + 1))
  check_default com.apple.finder SearchRecentsSavedViewStyle string Nlsv || failures=$((failures + 1))
  check_default com.apple.finder FXPreferredSearchViewStyleVersion string "%00%00%00%01" || failures=$((failures + 1))
  check_default com.apple.finder SearchRecentsSavedViewStyleVersion string "%00%00%00%01" || failures=$((failures + 1))
  check_default com.apple.finder CreateDesktop bool false || failures=$((failures + 1))
  check_default com.apple.finder ShowPathbar bool true || failures=$((failures + 1))
  check_default com.apple.finder ShowStatusBar bool true || failures=$((failures + 1))
  check_default com.apple.finder AppleShowAllFiles bool true || failures=$((failures + 1))
  check_default com.apple.finder _FXSortFoldersFirst bool true || failures=$((failures + 1))
  check_default com.apple.finder FinderSpawnTab bool true || failures=$((failures + 1))
  check_default com.apple.finder NewWindowTarget string PfAF || failures=$((failures + 1))
  check_default com.apple.finder ShowRecentTags bool true || failures=$((failures + 1))
  check_default com.apple.finder SidebarWidth int 132 || failures=$((failures + 1))
  check_default com.apple.finder SidebarWidth2 int 160 || failures=$((failures + 1))
  check_default com.apple.finder SidebarDevicesSectionDisclosedState bool true || failures=$((failures + 1))
  check_default com.apple.finder SidebarMediaBrowserSectionDisclosedState bool true || failures=$((failures + 1))
  check_default com.apple.finder SidebarPlacesSectionDisclosedState bool true || failures=$((failures + 1))
  check_default com.apple.finder SidebariCloudDriveSectionDisclosedState bool false || failures=$((failures + 1))
  check_default com.apple.finder SidebarShowingSignedIntoiCloud bool true || failures=$((failures + 1))
  check_default com.apple.finder SidebarShowingiCloudDesktop bool false || failures=$((failures + 1))

  check_default com.apple.dock orientation string right || failures=$((failures + 1))
  check_default com.apple.dock tilesize int 26 || failures=$((failures + 1))
  check_default com.apple.dock minimize-to-application bool true || failures=$((failures + 1))
  check_default com.apple.dock expose-animation-duration float 0.1 || failures=$((failures + 1))
  check_default com.apple.dock mru-spaces bool false || failures=$((failures + 1))
  check_default com.apple.dock autohide bool false || failures=$((failures + 1))
  check_default com.apple.dock showhidden bool true || failures=$((failures + 1))
  check_default com.apple.dock show-recents bool false || failures=$((failures + 1))
  check_default com.apple.dock size-immutable bool true || failures=$((failures + 1))
  check_default com.apple.dock magnification bool false || failures=$((failures + 1))
  audit_dock || failures=$((failures + 1))

  check_default com.apple.controlcenter "NSStatusItem Visible Weather" bool true || failures=$((failures + 1))
  check_default_bool_unset_false com.apple.controlcenter "NSStatusItem Visible WiFi" || failures=$((failures + 1))
  check_default com.apple.controlcenter "NSStatusItem Visible Bluetooth" bool false || failures=$((failures + 1))
  check_default com.apple.controlcenter "NSStatusItem Visible Sound" bool false || failures=$((failures + 1))
  check_default_bool_unset_false com.apple.controlcenter "NSStatusItem Visible Battery" || failures=$((failures + 1))
  check_default com.apple.controlcenter "NSStatusItem Visible AccessibilityShortcuts" bool false || failures=$((failures + 1))
  check_default com.apple.controlcenter "NSStatusItem Visible BentoBox" bool true || failures=$((failures + 1))
  check_default com.apple.controlcenter "NSStatusItem Visible MusicRecognition" bool false || failures=$((failures + 1))
  check_default com.apple.controlcenter "NSStatusItem Visible Item-0" bool false || failures=$((failures + 1))
  check_default com.apple.controlcenter "NSStatusItem Visible Item-1" bool false || failures=$((failures + 1))
  check_default com.apple.controlcenter "NSStatusItem Visible Item-2" bool false || failures=$((failures + 1))
  check_default com.apple.controlcenter "NSStatusItem Visible Item-3" bool false || failures=$((failures + 1))
  check_default com.apple.controlcenter "NSStatusItem Visible Item-4" bool false || failures=$((failures + 1))
  check_default com.apple.controlcenter "NSStatusItem Visible Item-5" bool false || failures=$((failures + 1))
  check_default com.apple.controlcenter "NSStatusItem Visible Item-6" bool false || failures=$((failures + 1))
  check_default com.apple.controlcenter "NSStatusItem Visible Item-7" bool false || failures=$((failures + 1))
  check_default com.apple.controlcenter "NSStatusItem Visible Item-8" bool false || failures=$((failures + 1))
  check_default com.apple.controlcenter "NSStatusItem VisibleCC Battery" bool true || failures=$((failures + 1))
  check_default com.apple.controlcenter "NSStatusItem VisibleCC Clock" bool true || failures=$((failures + 1))
  check_default com.apple.controlcenter "NSStatusItem VisibleCC BentoBox-0" bool true || failures=$((failures + 1))
  check_default com.apple.controlcenter "NSStatusItem Preferred Position BentoBox-0" float 105 || failures=$((failures + 1))
  check_default com.apple.controlcenter "NSStatusItem Preferred Position BentoBox" float 127 || failures=$((failures + 1))
  check_default com.apple.controlcenter "NSStatusItem Preferred Position Battery" float 195 || failures=$((failures + 1))
  check_default com.apple.controlcenter "NSStatusItem Preferred Position Clock" float 200 || failures=$((failures + 1))
  check_default com.apple.controlcenter "NSStatusItem Preferred Position AccessibilityShortcuts" float 211 || failures=$((failures + 1))
  check_default com.apple.menuextra.battery ShowPercent bool false || failures=$((failures + 1))
  check_default com.apple.menuextra.clock DateFormat string "EEE MMM d  h:mm a" || failures=$((failures + 1))
  check_default com.apple.menuextra.clock FlashDateSeparators bool false || failures=$((failures + 1))
  check_default com.apple.menuextra.clock IsAnalog bool false || failures=$((failures + 1))
  check_default com.apple.menuextra.clock Show24Hour bool true || failures=$((failures + 1))
  check_default com.apple.menuextra.clock ShowAMPM bool false || failures=$((failures + 1))
  check_default com.apple.menuextra.clock ShowDate bool false || failures=$((failures + 1))
  check_default com.apple.menuextra.clock ShowDayOfWeek bool false || failures=$((failures + 1))
  check_default com.apple.menuextra.clock ShowSeconds bool false || failures=$((failures + 1))
  check_default com.apple.menuextra.clock TimeAnnouncementsEnabled bool false || failures=$((failures + 1))
  check_default com.apple.menuextra.clock TimeAnnouncementsIntervalIdentifier string EveryHourInterval || failures=$((failures + 1))
  check_default com.apple.Spotlight "NSStatusItem Visible Item-0" bool false || failures=$((failures + 1))

  check_default_if_set com.apple.Safari DownloadsPath string "$HOME/Downloads" || failures=$((failures + 1))
  check_default_if_set com.apple.Safari ShowFullURLInSmartSearchField bool true || failures=$((failures + 1))
  check_default_if_set com.apple.Safari AutoOpenSafeDownloads bool false || failures=$((failures + 1))
  check_default_if_set com.apple.Safari AlwaysRestoreSessionAtLaunch bool true || failures=$((failures + 1))
  check_default_if_set com.apple.Safari ShowFavoritesBar bool true || failures=$((failures + 1))
  check_default_if_set com.apple.Safari ShowSidebarInNewWindows bool false || failures=$((failures + 1))
  check_default_if_set com.apple.Safari ShowSidebarInNewTabs bool false || failures=$((failures + 1))
  check_default_if_set com.apple.Safari UniversalSearchEnabled bool true || failures=$((failures + 1))
  check_default_if_set com.apple.Safari SuppressSearchSuggestions bool false || failures=$((failures + 1))
  check_default_if_set com.apple.Safari ShowDevelopMenu bool true || failures=$((failures + 1))
  check_default_if_set com.apple.Safari IncludeDevelopMenu bool true || failures=$((failures + 1))
  check_default_if_set com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey bool true || failures=$((failures + 1))
  check_default NSGlobalDomain WebKitDeveloperExtras bool true || failures=$((failures + 1))

  check_default io.tailscale.ipn.macsys HideDockIcon bool true || failures=$((failures + 1))
  check_default io.tailscale.ipn.macsys TailscaleStartOnLogin bool false || failures=$((failures + 1))
  check_default io.tailscale.ipn.macsys AppIntroShown bool true || failures=$((failures + 1))
  check_default io.tailscale.ipn.macsys OnboardingFlow string hide || failures=$((failures + 1))
  check_default io.tailscale.ipn.macsys OccludedIconAlertSuppressed bool true || failures=$((failures + 1))

  check_default com.apple.ActivityMonitor ShowCategory int 0 || failures=$((failures + 1))
  check_default com.apple.ActivityMonitor SortColumn string CPUUsage || failures=$((failures + 1))
  check_default com.apple.ActivityMonitor SortDirection int 0 || failures=$((failures + 1))

  if [[ "$failures" -gt 0 ]]; then
    echo
    echo "$failures managed settings differ from this repo."
    return 1
  fi

  echo
  echo "All audited settings match this repo."
}

check_settings() {
  section "Managed Settings"
  local output

  if output="$(settings_audit 2>&1)"; then
    echo "Settings match."
    return 0
  fi

  while IFS= read -r line; do
    if [[ -n "$line" ]]; then
      VIOLATIONS=$((VIOLATIONS + 1))
      echo "$line"
    fi
  done < <(echo "$output" | sed -n '/^DIFF/p')
}

rel_home() {
  local path="$1"
  printf "~%s" "${path#$HOME_DIR}"
}

unique_dest() {
  local src="$1"
  local base dest suffix

  base="$(basename "$src")"
  dest="$DEV_DIR/$base"
  suffix=1

  while [[ -e "$dest" ]]; do
    dest="$DEV_DIR/${base}-${suffix}"
    suffix=$((suffix + 1))
  done

  printf "%s" "$dest"
}

move_repo() {
  local src="$1"
  local apply="$2"
  local dest

  dest="$(unique_dest "$src")"
  if [[ "$apply" == true ]]; then
    mkdir -p "$DEV_DIR"
    mv "$src" "$dest"
    printf "MOVED\t%s -> %s\n" "$(rel_home "$src")" "$(rel_home "$dest")"
  else
    printf "WOULD_MOVE_REPO\t%s -> %s\n" "$(rel_home "$src")" "$(rel_home "$dest")"
  fi
}

is_allowed_top_level() {
  case "$(basename "$1")" in
    Applications|CleanupStaging|Desktop|Developer|Documents|Downloads|Library|Lightroom|Movies|Music|Personal|Pictures|Public|School|"Unity user templates"|Zotero|dotfiles)
      return 0
      ;;
    "Creative Cloud Files"*|*" - Google Drive")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

print_cloud_roots() {
  echo
  echo "Cloud roots:"
  for path in "$HOME_DIR/Library/CloudStorage"/* "$HOME_DIR"/*" - Google Drive"; do
    [[ -e "$path" ]] || continue
    printf "  %s\n" "$(rel_home "$path")"
  done
}

home_audit() {
  local apply="${1:-false}"
  local dotfiles_real expected_dotfiles_real

  echo "Home organization audit"
  echo "Mode: $([[ "$apply" == true ]] && echo apply || echo dry-run)"
  echo

  dotfiles_real="$(cd "$DOTFILES" 2>/dev/null && pwd -P || printf "%s" "$DOTFILES")"
  expected_dotfiles_real="$(cd "$DOTFILES_DIR" 2>/dev/null && pwd -P || printf "%s" "$DOTFILES_DIR")"

  if [[ "$dotfiles_real" != "$expected_dotfiles_real" ]]; then
    printf "DOTFILES_LOCATION_DRIFT\tDOTFILES=%s\texpected ~/dotfiles\n" "$dotfiles_real"
  fi

  find "$HOME_DIR" -maxdepth 1 -mindepth 1 -type d -print 2>/dev/null | sort |
  while read -r dir; do
    [[ "$dir" == "$HOME_DIR/Library" || "$dir" == "$HOME_DIR/.Trash" ]] && continue

    case "$(basename "$dir")" in
      .anaconda|.continuum|.oh-my-zsh|.rbenv|.rvm|powerlevel10k)
        printf "DEV_TOOL_DRIFT\t%s\treview whether this should still exist\n" "$(rel_home "$dir")"
        continue
        ;;
      .*)
        continue
        ;;
      zotero-build)
        printf "STALE_APP_BUILD\t%s\told Zotero source-build folder; likely removable after review\n" "$(rel_home "$dir")"
        continue
        ;;
    esac

    if [[ "$dir" == "$DOTFILES_DIR" ]]; then
      continue
    fi

    if [[ -d "$dir/.git" && "$dir" != "$DEV_DIR" && "$dir" != "$DEV_DIR/"* ]]; then
      move_repo "$dir" "$apply"
      continue
    fi

    if ! is_allowed_top_level "$dir" && [[ "$(basename "$dir")" != .* ]]; then
      printf "REVIEW_TOP_LEVEL\t%s\n" "$(rel_home "$dir")"
    fi
  done

  echo
  echo "Allowed local data roots:"
  echo "  ~/Personal"
  echo "  ~/School"
  echo "  ~/Pictures"
  echo "  ~/Documents"
  echo "  ~/Zotero"
  echo "  ~/Downloads"
  echo "  ~/CleanupStaging"
  echo "  ~/dotfiles"
  print_cloud_roots
}

check_home() {
  section "Home Folder"
  local output

  output="$(home_audit false)"
  echo "$output" | awk -F '\t' '$1 == "DEV_TOOL_DRIFT" || $1 == "REVIEW_TOP_LEVEL" || $1 == "DOTFILES_LOCATION_DRIFT" || $1 == "STALE_APP_BUILD" || $1 == "WOULD_MOVE_REPO" { print }'

  while IFS= read -r line; do
    [[ -n "$line" ]] && violation "home organization drift: $line"
  done < <(echo "$output" | awk -F '\t' '$1 == "DEV_TOOL_DRIFT" || $1 == "REVIEW_TOP_LEVEL" || $1 == "DOTFILES_LOCATION_DRIFT" || $1 == "STALE_APP_BUILD" || $1 == "WOULD_MOVE_REPO" { print }')
}

plist_label() {
  local plist="$1"
  defaults read "${plist%.plist}" Label 2>/dev/null || basename "$plist" .plist
}

plist_program() {
  local plist="$1"
  local program args
  program="$(defaults read "${plist%.plist}" Program 2>/dev/null || true)"
  args="$(defaults read "${plist%.plist}" ProgramArguments 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]][[:space:]]*/ /g' || true)"
  if [[ -n "$program" ]]; then
    printf "%s" "$program"
  else
    printf "%s" "$args"
  fi
}

config_action() {
  local label="$1"
  awk -F '\t' -v label="$label" '
    $0 !~ /^[[:space:]]*#/ && $2 == label { print $1; found=1; exit }
    END { if (!found) print "unmanaged" }
  ' "$LAUNCH_CONFIG"
}

config_note() {
  local label="$1"
  awk -F '\t' -v label="$label" '
    $0 !~ /^[[:space:]]*#/ && $2 == label { print $3; found=1; exit }
    END { if (!found) print "" }
  ' "$LAUNCH_CONFIG"
}

launch_inventory() {
  local dir scope plist label program

  for scope_dir in \
    "user|$HOME/Library/LaunchAgents" \
    "system-agent|/Library/LaunchAgents" \
    "system-daemon|/Library/LaunchDaemons"; do
    scope="${scope_dir%%|*}"
    dir="${scope_dir#*|}"
    [[ -d "$dir" ]] || continue

    find "$dir" -maxdepth 1 -name "*.plist" -print 2>/dev/null | sort |
    while read -r plist; do
      label="$(plist_label "$plist")"
      program="$(plist_program "$plist")"
      printf "%s\t%s\t%s\t%s\n" "$scope" "$label" "$plist" "$program"
    done
  done
}

launchagents_audit() {
  local scope label plist program action note

  printf "action\tscope\tlabel\tplist\tnote\n"
  launch_inventory | while IFS=$'\t' read -r scope label plist program; do
    action="$(config_action "$label")"
    note="$(config_note "$label")"
    printf "%s\t%s\t%s\t%s\t%s\n" "$action" "$scope" "$label" "$plist" "$note"
  done
}

disable_launch_item() {
  local scope="$1"
  local label="$2"
  local plist="$3"

  case "$scope" in
    user)
      launchctl bootout "gui/$(id -u)/$label" >/dev/null 2>&1 || true
      launchctl disable "gui/$(id -u)/$label" >/dev/null 2>&1 || true
      ;;
    system-agent|system-daemon)
      ensure_sudo_keepalive
      sudo launchctl bootout system "$plist" >/dev/null 2>&1 || true
      sudo launchctl disable "system/$label" >/dev/null 2>&1 || true
      ;;
  esac
}

launchagents_apply() {
  local scope label plist program action

  launch_inventory | while IFS=$'\t' read -r scope label plist program; do
    action="$(config_action "$label")"
    case "$action" in
      disable)
        echo "Disabling $label ($plist)"
        disable_launch_item "$scope" "$label" "$plist"
        ;;
      keep|review|unmanaged)
        :
        ;;
      *)
        echo "Unknown action for $label: $action" >&2
        exit 1
        ;;
    esac
  done
}

check_launchagents() {
  section "Startup And Background Items"
  local output

  output="$(launchagents_audit)"
  echo "$output" | awk -F '\t' 'NR > 1 && ($1 == "review" || $1 == "unmanaged") { print }'

  while IFS= read -r line; do
    [[ -n "$line" ]] && violation "startup/background item needs decision: $line"
  done < <(echo "$output" | awk -F '\t' 'NR > 1 && ($1 == "review" || $1 == "unmanaged") { print }')
}

check_installer_guard() {
  section "Installer Guard"

  if launchctl print "gui/$(id -u)/com.jsegal.dotfiles-installer-guard" >/dev/null 2>&1; then
    echo "Installer guard is loaded."
    return 0
  fi

  violation "installer guard is not loaded; run ./macos/installer-guard.sh install or ./run/setup.sh"
}

check_desktop() {
  section "Desktop"
  local files

  files="$(find "$HOME/Desktop" -maxdepth 1 -mindepth 1 \
    -not -name ".DS_Store" \
    -not -name ".localized" \
    -print 2>/dev/null | sort || true)"

  if [[ -z "$files" ]]; then
    echo "Desktop is clean."
    return 0
  fi

  echo "$files"
  while IFS= read -r file; do
    [[ -n "$file" ]] && violation "Desktop file should be moved or deleted: ${file#$HOME/}"
  done <<< "$files"
}

check_downloads() {
  section "Downloads Inbox"
  local old_files

  old_files="$(find "$HOME/Downloads" -maxdepth 1 -mindepth 1 \
    -not -name ".DS_Store" \
    -not -name ".localized" \
    -mtime +14 \
    -print 2>/dev/null | sort || true)"

  if [[ -z "$old_files" ]]; then
    echo "No Downloads files older than 14 days."
    return 0
  fi

  echo "$old_files"
  while IFS= read -r file; do
    [[ -n "$file" ]] && violation "Downloads item older than 14 days: ${file#$HOME/}"
  done <<< "$old_files"
}

unwanted_paths() {
  cat <<EOF
/Applications/Docker.app
/Applications/Ghostty.app
/Applications/Maxon.app
/Applications/Steam.app
/Applications/logioptionsplus.app
/Applications/Utilities/Logi Options+ Driver Installer.bundle
/Applications/Utilities/LogiPluginService.app
/Library/Application Support/Logi
/Library/Application Support/Logitech.localized
/Library/LaunchAgents/com.logi.optionsplus.plist
/Library/LaunchAgents/com.logitech.LogiRightSight.Agent.plist
/Library/LaunchDaemons/com.docker.socket.plist
/Library/LaunchDaemons/com.docker.vmnetd.plist
/Library/LaunchDaemons/com.logi.optionsplus.updater.plist
/Library/LaunchDaemons/net.maxon.deployservice.plist
/Library/PrivilegedHelperTools/com.docker.socket
/Library/PrivilegedHelperTools/com.docker.vmnetd
/Library/PrivilegedHelperTools/net.maxon.deployservice
$HOME/Library/Application Support/Docker Desktop
$HOME/Library/Application Support/Maxon
$HOME/Library/Application Support/LogiOptionsPlus
$HOME/Library/Application Support/com.logitech.logiaipromptbuilder
$HOME/Library/Application Support/Steam
$HOME/Library/Containers/com.docker.docker
$HOME/Library/Group Containers/group.com.docker
$HOME/Library/HTTPStorages/com.docker.docker
$HOME/Library/LaunchAgents/com.github.facebook.watchman.plist
$HOME/Library/LaunchAgents/com.valvesoftware.steamclean.plist
$HOME/Library/Preferences/com.docker.docker.plist
$HOME/Library/Preferences/com.valvesoftware.steam.plist
$HOME/Library/Saved Application State/com.docker.docker.savedState
$HOME/Library/Saved Application State/com.valvesoftware.steam.savedState
/opt/homebrew/Caskroom/docker
/opt/homebrew/Caskroom/docker-desktop
/opt/homebrew/Caskroom/ghostty
/opt/homebrew/Caskroom/logi-options+
/opt/homebrew/Caskroom/maxon
/opt/homebrew/Caskroom/steam
EOF
}

unmanaged_homebrew_casks() {
  local installed expected

  installed="$(mktemp)"
  expected="$(mktemp)"

  installed_casks > "$installed"
  brewfile_entries cask > "$expected"
  comm -23 "$installed" "$expected" || true

  rm -f "$installed" "$expected"
}

unmanaged_homebrew_formula_leaves() {
  local installed expected

  installed="$(mktemp)"
  expected="$(mktemp)"

  installed_formulas > "$installed"
  brewfile_entries formula > "$expected"
  comm -23 "$installed" "$expected" || true

  rm -f "$installed" "$expected"
}

disabled_launch_items() {
  local scope label plist program

  launch_inventory | while IFS=$'\t' read -r scope label plist program; do
    if [[ "$(config_action "$label")" == "disable" ]]; then
      printf "%s\t%s\t%s\t%s\n" "$scope" "$label" "$plist" "$program"
    fi
  done
}

check_unwanted_artifacts() {
  section "Unwanted App Artifacts"
  local path formula cask found_any=0

  while IFS= read -r path; do
    if [[ "$path" == "$HOME/Library/Containers/com.docker.docker" ]] &&
       [[ -d "$path" ]] &&
       [[ "$(find "$path" -mindepth 1 -maxdepth 1 -not -name ".com.apple.containermanagerd.metadata.plist" -print -quit 2>/dev/null)" == "" ]]; then
      continue
    fi

    if [[ -e "$path" || -L "$path" ]]; then
      found_any=1
      violation "unwanted artifact remains: ${path#$HOME/}"
    fi
  done < <(unwanted_paths)

  while IFS= read -r formula; do
    [[ -n "$formula" ]] || continue
    found_any=1
    violation "formula installed but not repo-managed: $formula"
  done < <(unmanaged_homebrew_formula_leaves)

  while IFS= read -r cask; do
    [[ -n "$cask" ]] || continue
    found_any=1
    violation "cask installed but not repo-managed: $cask"
  done < <(unmanaged_homebrew_casks)

  if [[ "$found_any" -eq 0 ]]; then
    echo "No unwanted app artifacts found."
  else
    echo "Run ./run/setup.sh standards purge-unwanted from Terminal to purge these."
  fi
}

run_or_print() {
  local dry_run="$1"
  shift

  if [[ "$dry_run" == true ]]; then
    printf "Would run:"
    printf " %q" "$@"
    printf "\n"
  else
    "$@"
  fi
}

remove_paths() {
  local dry_run="$1"
  shift
  local existing=()
  local path

  for path in "$@"; do
    [[ -e "$path" || -L "$path" ]] && existing+=("$path")
  done

  [[ "${#existing[@]}" -gt 0 ]] || return 0

  if [[ "$dry_run" == true ]]; then
    printf "Would remove paths:\n"
    printf "  %s\n" "${existing[@]}"
    return 0
  fi

  if rm -rf "${existing[@]}" 2>/dev/null; then
    return 0
  fi

  ensure_sudo_keepalive
  sudo rm -rf "${existing[@]}"
}

purge_unwanted() {
  local dry_run="${1:-false}"
  local scope label plist program cask formula
  local paths=()
  local path

  echo "Removing Homebrew items not in $BREWFILE"

  if command -v brew >/dev/null 2>&1; then
    while IFS= read -r cask; do
      [[ -n "$cask" ]] || continue
      run_or_print "$dry_run" brew uninstall --force --zap --cask "$cask" || true
    done < <(unmanaged_homebrew_casks)

    while IFS= read -r formula; do
      [[ -n "$formula" ]] || continue
      run_or_print "$dry_run" brew uninstall --force "$formula" || true
    done < <(unmanaged_homebrew_formula_leaves)

    run_or_print "$dry_run" brew autoremove || true
    run_or_print "$dry_run" brew cleanup || true
  fi

  while IFS=$'\t' read -r scope label plist program; do
    [[ -n "$label" ]] || continue
    if [[ "$dry_run" == false ]]; then
      echo "Disabling launch service: $label"
      disable_launch_item "$scope" "$label" "$plist"
    else
      echo "Would disable launch service: $label"
    fi
  done < <(disabled_launch_items)

  while IFS= read -r path; do
    paths+=("$path")
  done < <(unwanted_paths)

  remove_paths "$dry_run" "${paths[@]}"
  echo "Done."
}

run_audit_category() {
  local before output_file

  before="$VIOLATIONS"
  output_file="$(mktemp)"

  "$@" > "$output_file"

  if [[ "$VIOLATIONS" -gt "$before" ]]; then
    cat "$output_file"
  fi

  rm -f "$output_file"
}

full_audit() {
  run_audit_category check_apps
  run_audit_category check_settings
  run_audit_category check_home
  run_audit_category check_launchagents
  run_audit_category check_installer_guard
  run_audit_category check_desktop
  run_audit_category check_downloads
  run_audit_category check_unwanted_artifacts

  section "Result"
  if [[ "$VIOLATIONS" -eq 0 ]]; then
    echo "PASS: machine matches the strict clean-computer standard."
    exit 0
  fi

  echo "FAIL: $VIOLATIONS strict-standard violation(s)."
  exit 1
}

main() {
  local command="${1:-audit}"
  shift || true

  case "$command" in
    audit)
      full_audit
      ;;
    apps)
      apps_report
      ;;
    settings)
      settings_audit
      ;;
    home)
      case "${1:---dry-run}" in
        --dry-run|"") home_audit false ;;
        --apply) home_audit true ;;
        --help|-h|help) usage ;;
        *) usage >&2; exit 1 ;;
      esac
      ;;
    launchagents)
      case "${1:-audit}" in
        audit) launchagents_audit ;;
        apply) launchagents_apply ;;
        --help|-h|help) usage ;;
        *) usage >&2; exit 1 ;;
      esac
      ;;
    purge-unwanted)
      case "${1:-}" in
        --dry-run) purge_unwanted true ;;
        "") purge_unwanted false ;;
        --help|-h|help) usage ;;
        *) usage >&2; exit 1 ;;
      esac
      ;;
    --help|-h|help)
      usage
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
