#!/usr/bin/env bash

set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
BREWFILE="${DOTFILES}/brew/Brewfile"
APP_ALLOWLIST="${DOTFILES}/macos/app-allowlist.txt"
REMOVABLE_APPLE_APPS="${DOTFILES}/macos/removable-apple-apps.txt"
HOME_DIR="${HOME}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
STAGING_ROOT="${HOME_DIR}/CleanupStaging"
MODE="staging"
APPLY=false
INCLUDE="all"
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

  command -v sudo >/dev/null 2>&1 || die "sudo is required for privileged cleanup"

  if [[ -n "$SUDO_KEEPALIVE_PID" ]] && kill -0 "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1; then
    return 0
  fi

  if ! sudo -n true >/dev/null 2>&1; then
    echo "Requesting administrator password once for cleanup..."
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
Usage: $(basename "$0") <command> [options]

Commands:
  audit            Read-only storage overview.
  targets          List reversible cleanup target groups.
  move             Dry-run or move selected cleanup targets.
  apps             Dry-run or remove unmanaged installed apps.
  reports          Generate duplicate/app/media review reports.
  lint-personal    Run Johnny.Decimal lint for ~/Personal.

Move options:
  --dry-run         Preview selected targets. This is the default.
  --apply           Move selected targets.
  --mode staging    Move to ~/CleanupStaging. This is the default.
  --mode trash      Move to ~/.Trash.
  --include LIST    Comma-separated groups. Default: all.

Groups:
  podcasts, macwhisper, chrome, app-caches, dev-caches, apps

Examples:
  $(basename "$0") audit
  $(basename "$0") targets
  $(basename "$0") move --dry-run --include chrome,dev-caches
  $(basename "$0") move --apply --mode staging --include podcasts
  $(basename "$0") apps --dry-run
  $(basename "$0") apps --apply --mode staging
  $(basename "$0") reports
  $(basename "$0") lint-personal
EOF
}

apply_standards() {
  section "Standards Enforcement"
  bash "$DOTFILES/run/.standards.sh" home --apply
  if [[ "$(uname -s)" == "Darwin" ]]; then
    bash "$DOTFILES/run/.standards.sh" launchagents apply
  fi
  bash "$DOTFILES/run/.standards.sh" purge-unwanted
  if bash "$DOTFILES/run/.standards.sh" audit >/dev/null 2>&1; then
    echo "Standards audit passes."
  else
    echo "Standards audit still has review items. Run ./run/setup.sh standards audit."
  fi
}

die() {
  echo "error: $*" >&2
  exit 1
}

section() {
  printf "\n=== %s ===\n" "$1"
}

target_table() {
  cat <<EOF
podcasts|${HOME_DIR}/Library/Containers/com.apple.podcasts/Data/tmp/StreamedMedia
macwhisper|${HOME_DIR}/Library/Containers/com.goodsnooze.MacWhisper/Data/tmp
macwhisper|${HOME_DIR}/Library/Containers/com.goodsnooze.MacWhisper/Data/Library/Caches
macwhisper|${HOME_DIR}/Library/Containers/com.goodsnooze.MacWhisper/Data/Library/Application Support/MacWhisper/models
chrome|${HOME_DIR}/Library/Application Support/Google/Chrome/Default/Service Worker
chrome|${HOME_DIR}/Library/Application Support/Google/Chrome/Default/File System
chrome|${HOME_DIR}/Library/Application Support/Google/Chrome/Default/IndexedDB
app-caches|${HOME_DIR}/Library/Application Support/Slack/Cache
app-caches|${HOME_DIR}/Library/Application Support/discord/Cache
app-caches|${HOME_DIR}/Library/Application Support/Code/Cache
app-caches|${HOME_DIR}/Library/Application Support/Code/CachedData
dev-caches|${HOME_DIR}/Library/Caches/Homebrew
dev-caches|${HOME_DIR}/Library/Caches/pnpm
dev-caches|${HOME_DIR}/.npm
dev-caches|${HOME_DIR}/.cache
EOF
}

list_targets() {
  target_table | awk -F '|' '
    last != $1 {
      if (NR > 1) print ""
      print $1 ":"
      last = $1
    }
    { sub("^" ENVIRON["HOME"], "~", $2); print "  " $2 }
  '
  echo
  echo "apps:"
  echo "  unmanaged app bundles in /Applications and ~/Applications"
  echo "  removable Apple apps from macos/removable-apple-apps.txt"
  echo "  source of truth: brew/Brewfile, MAS entries, macos/app-allowlist.txt"
}

contains_group() {
  local group="$1"
  [[ "$INCLUDE" == "all" || ",${INCLUDE}," == *",${group},"* ]]
}

target_size() {
  du -sh "$1" 2>/dev/null | awk '{print $1}'
}

require_app_metadata_tools() {
  [[ -f "$BREWFILE" ]] || die "missing Brewfile: $BREWFILE"
  command -v brew >/dev/null 2>&1 || die "Homebrew is required for app cleanup metadata"
  command -v jq >/dev/null 2>&1 || die "jq is required for app cleanup metadata"
}

brewfile_casks() {
  sed -n 's/^cask "\([^"]*\)".*/\1/p' "$BREWFILE" | sort
}

brewfile_mas_names() {
  sed -n 's/^mas "\([^"]*\)".*/\1/p' "$BREWFILE" | sort
}

installed_casks() {
  brew list --cask --full-name 2>/dev/null |
    sed 's#^.*/##' |
    sort || true
}

managed_cask_app_names() {
  local casks
  casks="$(brewfile_casks | tr '\n' ' ')"
  [[ -n "${casks// }" ]] || return 0

  brew info --cask --json=v2 $casks 2>/dev/null |
    jq -r '
      .casks[].artifacts[]? |
      select(type == "object" and has("app")) |
      .app as $app |
      if ($app | type) == "array" then
        ($app[1].target? // $app[0])
      else
        $app
      end |
      split("/")[-1] |
      sub("\\.app$"; "")
    ' |
    sort -u
}

managed_app_names() {
  {
    managed_cask_app_names
    brewfile_mas_names
  } | sort -u
}

app_allowlist_patterns() {
  [[ -f "$APP_ALLOWLIST" ]] || return 0
  sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$APP_ALLOWLIST"
}

relative_app_path() {
  local app_path="$1"

  case "$app_path" in
    /Applications/*) printf "%s" "${app_path#/Applications/}" ;;
    "$HOME_DIR"/Applications/*) printf "%s" "${app_path#"$HOME_DIR/Applications/"}" ;;
    *) printf "%s" "$app_path" ;;
  esac
}

is_allowlisted_app() {
  local app_path="$1"
  local expected_names="$2"
  local app_name rel pattern

  app_name="$(basename "$app_path" .app)"
  rel="$(relative_app_path "$app_path")"

  if grep -Fxq "$app_name" "$expected_names"; then
    return 0
  fi

  while IFS= read -r pattern; do
    [[ "$app_name" == $pattern || "$rel" == $pattern || "${rel%.app}" == $pattern ]] && return 0
  done < <(app_allowlist_patterns)

  return 1
}

installed_app_paths() {
  find /Applications "$HOME_DIR/Applications" -maxdepth 2 -name "*.app" -type d 2>/dev/null |
    sed 's#/$##' |
    sort -f
}

removable_apple_app_paths() {
  [[ -f "$REMOVABLE_APPLE_APPS" ]] || return 0

  local app_name app_path
  while IFS= read -r app_name; do
    [[ -n "$app_name" ]] || continue

    for app_path in "/Applications/$app_name" "/System/Applications/$app_name"; do
      [[ -d "$app_path" ]] && printf "%s\n" "$app_path"
    done
  done < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$REMOVABLE_APPLE_APPS")
}

unmanaged_app_paths() {
  local expected_names app_path

  expected_names="$(mktemp)"
  managed_app_names > "$expected_names"

  while IFS= read -r app_path; do
    if ! is_allowlisted_app "$app_path" "$expected_names"; then
      printf "%s\n" "$app_path"
    fi
  done < <(installed_app_paths)

  while IFS= read -r app_path; do
    if ! is_allowlisted_app "$app_path" "$expected_names"; then
      printf "%s\n" "$app_path"
    fi
  done < <(removable_apple_app_paths)

  rm -f "$expected_names"
}

unmanaged_casks() {
  local installed expected

  installed="$(mktemp)"
  expected="$(mktemp)"

  installed_casks > "$installed"
  brewfile_casks > "$expected"
  comm -23 "$installed" "$expected" || true

  rm -f "$installed" "$expected"
}

audit_storage() {
  section "Disk Free"
  df -h "$HOME_DIR"

  section "Top-Level Home Usage"
  du -hd 1 "$HOME_DIR" 2>/dev/null | sort -h

  section "Library High-Level"
  for p in \
    "${HOME_DIR}/Library/Application Support" \
    "${HOME_DIR}/Library/Containers" \
    "${HOME_DIR}/Library/Caches" \
    "${HOME_DIR}/Library/CloudStorage" \
    "${HOME_DIR}/Library/Group Containers" \
    "${HOME_DIR}/Library/Developer" \
    "${HOME_DIR}/Library/Logs"; do
    [[ -e "$p" ]] && du -sh "$p" 2>/dev/null
  done | sort -h

  section "Targeted Cleanup Candidates"
  target_table | while IFS='|' read -r _ path; do
    [[ -e "$path" ]] && du -sh "$path" 2>/dev/null
  done | sort -h

  section "Largest Applications"
  find /Applications "$HOME_DIR/Applications" -maxdepth 1 -name "*.app" -type d 2>/dev/null |
  while read -r app; do
    kb="$(du -sk "$app" 2>/dev/null | awk '{print $1}')"
    [[ -n "$kb" ]] && printf "%s\t%s\n" "$kb" "$app"
  done | sort -nr | head -n 50 | awk -F '\t' '{printf "%.2f GiB\t%s\n", $1/1024/1024, $2}'

  section "Unmanaged Applications"
  if command -v brew >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 && [[ -f "$BREWFILE" ]]; then
    unmanaged_app_paths | sed "s#^$HOME_DIR#~#" || true
  else
    echo "Skipped: Homebrew, jq, and brew/Brewfile are required."
  fi
}

parse_move_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) APPLY=false ;;
      --apply) APPLY=true ;;
      --mode)
        shift
        MODE="${1:-}"
        [[ "$MODE" == "staging" || "$MODE" == "trash" ]] || die "invalid --mode: $MODE"
        ;;
      --include)
        shift
        INCLUDE="${1:-all}"
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *) die "unknown move option: $1" ;;
    esac
    shift
  done
}

move_target() {
  local src="$1"
  local dest_root="$2"
  local dest="${dest_root}${src}"

  mkdir -p "$(dirname "$dest")"
  if ! mv "$src" "$dest" 2>/dev/null; then
    ensure_sudo_keepalive
    sudo mkdir -p "$(dirname "$dest")"
    sudo mv "$src" "$dest"
    sudo chown -R "$(id -u):$(id -g)" "$dest" 2>/dev/null || true
  fi
  echo "moved: $src -> $dest"
}

remove_system_app() {
  local app="$1"

  ensure_sudo_keepalive
  if sudo rm -rf "$app"; then
    echo "removed: $app"
    return 0
  fi

  echo "warning: macOS protected this app and it could not be removed: $app" >&2
  return 0
}

parse_apply_mode_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) APPLY=false ;;
      --apply) APPLY=true ;;
      --mode)
        shift
        MODE="${1:-}"
        [[ "$MODE" == "staging" || "$MODE" == "trash" ]] || die "invalid --mode: $MODE"
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *) die "unknown option: $1" ;;
    esac
    shift
  done
}

cleanup_apps() {
  local apply="$1"
  local mode="$2"
  local report_file="${3:-}"
  local show_apply_hint="${4:-true}"
  local dest_root unmanaged cask app size had_any=false

  require_app_metadata_tools

  if [[ "$mode" == "trash" ]]; then
    dest_root="${HOME_DIR}/.Trash/unmanaged_apps_${TIMESTAMP}"
  else
    dest_root="${STAGING_ROOT}/unmanaged_apps_${TIMESTAMP}"
  fi

  section "Unmanaged Homebrew Casks"
  unmanaged="$(unmanaged_casks)"
  if [[ -z "$unmanaged" ]]; then
    echo "No unmanaged Homebrew casks."
  else
    had_any=true
    if [[ "$apply" == true ]]; then
      ensure_sudo_keepalive
    fi

    while IFS= read -r cask; do
      [[ -n "$cask" ]] || continue
      if [[ "$apply" == true ]]; then
        echo "uninstalling cask: $cask"
        brew uninstall --force --zap --cask "$cask" || true
        [[ -n "$report_file" ]] && echo "uninstalled cask: $cask" >> "$report_file"
      else
        echo "Would uninstall cask: $cask"
        [[ -n "$report_file" ]] && echo "Would uninstall cask: $cask" >> "$report_file"
      fi
    done <<< "$unmanaged"
  fi

  section "Unmanaged Application Bundles"
  unmanaged="$(unmanaged_app_paths)"
  if [[ -z "$unmanaged" ]]; then
    echo "No unmanaged app bundles."
  else
    had_any=true
    if [[ "$apply" == true ]]; then
      echo "Moving unmanaged apps to: $dest_root"
      mkdir -p "$dest_root"
    fi

    while IFS= read -r app; do
      [[ -n "$app" ]] || continue
      size="$(target_size "$app")"
      if [[ "$apply" == true ]]; then
        if [[ "$app" == /System/Applications/* ]]; then
          remove_system_app "$app" | tee -a "${report_file:-/dev/null}"
        else
          move_target "$app" "$dest_root" | tee -a "${report_file:-/dev/null}"
        fi
      else
        if [[ "$app" == /System/Applications/* ]]; then
          echo "Would remove: ${size:-unknown}  $app"
          [[ -n "$report_file" ]] && echo "Would remove: ${size:-unknown}  $app" >> "$report_file"
        else
          echo "Would move: ${size:-unknown}  $app -> $dest_root$app"
          [[ -n "$report_file" ]] && echo "Would move: ${size:-unknown}  $app -> $dest_root$app" >> "$report_file"
        fi
      fi
    done <<< "$unmanaged"
  fi

  if [[ "$had_any" == false ]]; then
    echo "Installed apps match the managed lists."
  elif [[ "$apply" != true && "$show_apply_hint" == true ]]; then
    echo
    echo "Dry-run only. No apps were removed."
    echo "To apply: $(basename "$0") apps --apply --mode $mode"
  fi
}

cleanup_apps_command() {
  parse_apply_mode_args "$@"

  local report_file
  mkdir -p "$STAGING_ROOT"
  report_file="${STAGING_ROOT}/unmanaged_apps_report_${TIMESTAMP}.txt"
  {
    echo "app cleanup run: $TIMESTAMP"
    echo "apply: $APPLY"
    echo "mode: $MODE"
    echo "source of truth:"
    echo "  $BREWFILE"
    echo "  $APP_ALLOWLIST"
    echo "  $REMOVABLE_APPLE_APPS"
    echo
  } > "$report_file"

  cleanup_apps "$APPLY" "$MODE" "$report_file"
  echo "Report: $report_file"

  if [[ "$APPLY" == true ]]; then
    apply_standards
  fi
}

move_cleanup_targets() {
  parse_move_args "$@"

  local dest_root report_file selected_count
  selected_count=0

  if [[ "$MODE" == "trash" ]]; then
    dest_root="${HOME_DIR}/.Trash/safe_cleanup_${TIMESTAMP}"
  else
    dest_root="${STAGING_ROOT}/safe_cleanup_${TIMESTAMP}"
  fi

  mkdir -p "$STAGING_ROOT"
  report_file="${STAGING_ROOT}/safe_cleanup_report_${TIMESTAMP}.txt"
  {
    echo "cleanup run: $TIMESTAMP"
    echo "apply: $APPLY"
    echo "mode: $MODE"
    echo "include: $INCLUDE"
    echo "destination root: $dest_root"
    echo
  } > "$report_file"

  echo "Selected targets:"
  while IFS='|' read -r group path; do
    contains_group "$group" || continue
    selected_count=$((selected_count + 1))
    if [[ -e "$path" ]]; then
      size="$(target_size "$path")"
      echo "  $size  $path"
      echo "$size  $path" >> "$report_file"
    else
      echo "  (missing) $path"
      echo "(missing) $path" >> "$report_file"
    fi
  done < <(target_table)

  if contains_group apps; then
    selected_count=$((selected_count + 1))
    echo "  dynamic  unmanaged app bundles"
    echo "dynamic  unmanaged app bundles" >> "$report_file"
  fi

  [[ "$selected_count" -gt 0 ]] || die "no targets selected"

  if [[ "$APPLY" != true ]]; then
    if contains_group apps; then
      cleanup_apps false "$MODE" "$report_file" false
    fi

    echo
    echo "Dry-run only. No files were moved."
    echo "To apply: $(basename "$0") move --apply --mode $MODE --include $INCLUDE"
    echo "Report: $report_file"
    return 0
  fi

  echo
  echo "Moving targets to: $dest_root"
  while IFS='|' read -r group path; do
    contains_group "$group" || continue
    [[ -e "$path" ]] || continue
    move_target "$path" "$dest_root" | tee -a "$report_file"
  done < <(target_table)

  if contains_group apps; then
    cleanup_apps true "$MODE" "$report_file" false
  fi

  echo
  echo "Move complete."
  echo "Reversal: move files from $dest_root back to original paths."
  echo "Report: $report_file"
  apply_standards
}

generate_reports() {
  local out_dir dup_report app_report media_report

  out_dir="${STAGING_ROOT}/reports"
  mkdir -p "$out_dir"

  dup_report="${out_dir}/duplicates_${TIMESTAMP}.txt"
  app_report="${out_dir}/apps_recency_${TIMESTAMP}.txt"
  media_report="${out_dir}/lossless_media_candidates_${TIMESTAMP}.txt"

  echo "Generating duplicate report..."
  find "$HOME_DIR" -type f -size +100M \
    -not -path "$HOME_DIR/Library/Caches/*" \
    -not -path "$HOME_DIR/.Trash/*" \
    -not -path "$HOME_DIR/Library/CloudStorage/Box-Box/*" \
    -not -path "$HOME_DIR/Library/Application Support/Box/*" \
    2>/dev/null | while read -r f; do
    sz="$(stat -f "%z" "$f" 2>/dev/null)"
    bn="$(basename "$f")"
    printf "%s\t%s\t%s\n" "$sz" "$bn" "$f"
  done | sort -k2,2 -k1,1nr | awk -F '\t' '
  {k=tolower($2)"|"$1; c[k]++; p[k]=p[k] ORS $3}
  END {
    for (k in c) if (c[k] > 1) {
      split(k,a,"|"); sz=a[2]+0; waste=(c[k]-1)*sz;
      printf "%012d\t%.2f GiB each\tcount=%d\tpotential_waste=%.2f GiB\t%s\n%s\n---\n", waste, sz/1024/1024/1024, c[k], waste/1024/1024/1024, a[1], p[k];
    }
  }' | sort -nr > "$dup_report"

  echo "Generating app recency report..."
  find /Applications "$HOME_DIR/Applications" -maxdepth 1 -name "*.app" -type d 2>/dev/null | while read -r app; do
    sz="$(du -sk "$app" 2>/dev/null | awk '{print $1}')"
    lu="$(mdls -name kMDItemLastUsedDate -raw "$app" 2>/dev/null)"
    mc="$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$app" 2>/dev/null)"
    [[ -z "$lu" ]] && lu="(unknown)"
    printf "%s\t%s\t%s\t%s\n" "$sz" "$lu" "$mc" "$app"
  done | sort -nr | awk -F '\t' '{printf "%.2f GiB\tlastUsed=%s\tmodified=%s\t%s\n", $1/1024/1024, $2, $3, $4}' > "$app_report"

  echo "Generating lossless media candidate report..."
  {
    echo "Lossless raster image candidates (>50MB):"
    find "$HOME_DIR" -type f \
      \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.tif" -o -iname "*.tiff" \) \
      -size +50M 2>/dev/null | while read -r f; do
      stat -f "%z\t%N" "$f"
    done | sort -nr | awk -F '\t' '{printf "%.2f MB\t%s\n", $1/1024/1024, $2}'

    echo
    echo "Vector files are excluded by design (svg, ai, eps, pdf)."
    echo "Video note: meaningful lossless compression is usually minimal; avoid recompression unless archival workflow is required."
  } > "$media_report"

  echo "Reports generated:"
  echo "  $dup_report"
  echo "  $app_report"
  echo "  $media_report"
}

lint_personal() {
  local dotfiles
  dotfiles="$(cd "$(dirname "$0")/.." && pwd)"

  python3 "$dotfiles/macos/jdlint.py" "$HOME_DIR/Personal" \
    -i '.DS_Store' \
    -i '.tmp.drivedownload' \
    -i '.tmp.driveupload' \
    -i 'Icon*' \
    -i '**/Icon*'
}

main() {
  command="${1:-}"
  [[ -n "$command" ]] || {
    usage
    exit 1
  }
  shift || true

  case "$command" in
    audit) audit_storage "$@" ;;
    targets) list_targets ;;
    move) move_cleanup_targets "$@" ;;
    apps) cleanup_apps_command "$@" ;;
    reports) generate_reports "$@" ;;
    lint-personal) lint_personal "$@" ;;
    --help|-h|help) usage ;;
    *) die "unknown command: $command" ;;
  esac
}

main "$@"
