#!/usr/bin/env bash

set -euo pipefail

MODE="staging"
APPLY="false"
INCLUDE="all"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
HOME_DIR="${HOME}"
DEST_ROOT_STAGING="${HOME_DIR}/CleanupStaging/safe_cleanup_${TIMESTAMP}"
DEST_ROOT_TRASH="${HOME_DIR}/.Trash/safe_cleanup_${TIMESTAMP}"
REPORT_FILE="${HOME_DIR}/CleanupStaging/safe_cleanup_report_${TIMESTAMP}.txt"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--dry-run] [--apply] [--mode staging|trash] [--include LIST] [--list-targets]

Defaults:
  --dry-run mode is default (no changes)
  --mode staging (move to ~/CleanupStaging)
  --include all

Include groups (comma-separated):
  podcasts,macwhisper,chrome,app-caches,dev-caches

Examples:
  $(basename "$0") --dry-run --include podcasts,macwhisper
  $(basename "$0") --apply --mode staging --include podcasts
  $(basename "$0") --apply --mode trash --include app-caches,dev-caches
EOF
}

list_targets() {
  cat <<EOF
podcasts:
  ~/Library/Containers/com.apple.podcasts/Data/tmp/StreamedMedia

macwhisper:
  ~/Library/Containers/com.goodsnooze.MacWhisper/Data/tmp
  ~/Library/Containers/com.goodsnooze.MacWhisper/Data/Library/Caches
  ~/Library/Containers/com.goodsnooze.MacWhisper/Data/Library/Application Support/MacWhisper/models

chrome:
  ~/Library/Application Support/Google/Chrome/Default/Service Worker
  ~/Library/Application Support/Google/Chrome/Default/File System
  ~/Library/Application Support/Google/Chrome/Default/IndexedDB

app-caches:
  ~/Library/Application Support/Slack/Cache
  ~/Library/Application Support/discord/Cache
  ~/Library/Application Support/Code/Cache
  ~/Library/Application Support/Code/CachedData

dev-caches:
  ~/Library/Caches/Homebrew
  ~/Library/Caches/pnpm
  ~/.npm
  ~/.cache
EOF
}

contains_group() {
  local group="$1"
  if [ "$INCLUDE" = "all" ]; then
    return 0
  fi
  case ",${INCLUDE}," in
    *",${group},"*) return 0 ;;
    *) return 1 ;;
  esac
}

add_target() {
  local group="$1"
  local path="$2"
  if contains_group "$group"; then
    TARGETS+=("$path")
  fi
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run)
        APPLY="false"
        ;;
      --apply)
        APPLY="true"
        ;;
      --mode)
        shift
        MODE="${1:-}"
        if [ "$MODE" != "staging" ] && [ "$MODE" != "trash" ]; then
          echo "Invalid --mode: $MODE"
          exit 1
        fi
        ;;
      --include)
        shift
        INCLUDE="${1:-all}"
        ;;
      --list-targets)
        list_targets
        exit 0
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        echo "Unknown arg: $1"
        usage
        exit 1
        ;;
    esac
    shift
  done
}

target_exists() {
  [ -e "$1" ]
}

target_size() {
  du -sh "$1" 2>/dev/null | awk '{print $1}'
}

move_target() {
  local src="$1"
  local dest_root="$2"
  local dest="${dest_root}${src}"
  mkdir -p "$(dirname "$dest")"
  mv "$src" "$dest"
  echo "moved: $src -> $dest"
}

main() {
  parse_args "$@"

  TARGETS=()

  add_target "podcasts" "${HOME_DIR}/Library/Containers/com.apple.podcasts/Data/tmp/StreamedMedia"

  add_target "macwhisper" "${HOME_DIR}/Library/Containers/com.goodsnooze.MacWhisper/Data/tmp"
  add_target "macwhisper" "${HOME_DIR}/Library/Containers/com.goodsnooze.MacWhisper/Data/Library/Caches"
  add_target "macwhisper" "${HOME_DIR}/Library/Containers/com.goodsnooze.MacWhisper/Data/Library/Application Support/MacWhisper/models"

  add_target "chrome" "${HOME_DIR}/Library/Application Support/Google/Chrome/Default/Service Worker"
  add_target "chrome" "${HOME_DIR}/Library/Application Support/Google/Chrome/Default/File System"
  add_target "chrome" "${HOME_DIR}/Library/Application Support/Google/Chrome/Default/IndexedDB"

  add_target "app-caches" "${HOME_DIR}/Library/Application Support/Slack/Cache"
  add_target "app-caches" "${HOME_DIR}/Library/Application Support/discord/Cache"
  add_target "app-caches" "${HOME_DIR}/Library/Application Support/Code/Cache"
  add_target "app-caches" "${HOME_DIR}/Library/Application Support/Code/CachedData"

  add_target "dev-caches" "${HOME_DIR}/Library/Caches/Homebrew"
  add_target "dev-caches" "${HOME_DIR}/Library/Caches/pnpm"
  add_target "dev-caches" "${HOME_DIR}/.npm"
  add_target "dev-caches" "${HOME_DIR}/.cache"

  if [ "${#TARGETS[@]}" -eq 0 ]; then
    echo "No targets selected."
    exit 0
  fi

  local dest_root
  if [ "$MODE" = "trash" ]; then
    dest_root="$DEST_ROOT_TRASH"
  else
    dest_root="$DEST_ROOT_STAGING"
  fi

  mkdir -p "$(dirname "$REPORT_FILE")"
  {
    echo "safe cleanup run: $TIMESTAMP"
    echo "apply: $APPLY"
    echo "mode: $MODE"
    echo "include: $INCLUDE"
    echo "destination root: $dest_root"
    echo
  } > "$REPORT_FILE"

  echo "Selected targets:"
  for t in "${TARGETS[@]}"; do
    if target_exists "$t"; then
      sz="$(target_size "$t")"
      echo "  $sz  $t"
      echo "$sz  $t" >> "$REPORT_FILE"
    else
      echo "  (missing) $t"
      echo "(missing) $t" >> "$REPORT_FILE"
    fi
  done

  if [ "$APPLY" != "true" ]; then
    echo
    echo "Dry-run only. No files were moved."
    echo "To apply: $(basename "$0") --apply --mode $MODE --include $INCLUDE"
    echo "Report: $REPORT_FILE"
    exit 0
  fi

  echo
  echo "Applying move operation to: $dest_root"
  for t in "${TARGETS[@]}"; do
    if target_exists "$t"; then
      move_target "$t" "$dest_root" | tee -a "$REPORT_FILE"
    fi
  done

  echo
  echo "Move complete."
  echo "Reversal: move files from $dest_root back to original paths."
  echo "Report: $REPORT_FILE"
}

main "$@"