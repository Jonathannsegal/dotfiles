#!/usr/bin/env bash

set -euo pipefail

SRC="${HOME}/Library/Messages/Attachments"
TS="$(date +%Y%m%d_%H%M%S)"
DEST="${HOME}/CleanupStaging/messages_export_${TS}"
APPLY="false"
MEDIA_ONLY="true"
FLAT_MODE="true"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--dry-run] [--apply] [--dest PATH] [--all]

Defaults:
  --dry-run (no file changes)
  export media-only (images/videos) for Google Photos workflows

Options:
  --apply      Perform the copy
  --dry-run    Preview only
  --dest PATH  Export destination folder
  --all        Export all attachments (not just media)
  --nested     Preserve source folder structure in the export
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --apply) APPLY="true" ;;
      --dry-run) APPLY="false" ;;
      --dest)
        shift
        DEST="${1:-$DEST}"
        ;;
      --all) MEDIA_ONLY="false" ;;
      --nested) FLAT_MODE="false" ;;
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

check_access() {
  if [ ! -d "$SRC" ]; then
    echo "Source folder not found: $SRC"
    exit 1
  fi

  if ! ls "$SRC" >/dev/null 2>&1; then
    echo "Permission denied for $SRC"
    echo "Grant Full Disk Access to Terminal/VS Code and rerun."
    exit 1
  fi
}

preview_counts() {
  echo "Source: $SRC"
  echo "Destination: $DEST"

  echo
  echo "Source total:"
  du -sh "$SRC" 2>/dev/null || true

  if [ "$MEDIA_ONLY" = "true" ]; then
    echo
    if [ "$FLAT_MODE" = "true" ]; then
      echo "Flat media-only preview (photos and videos):"
      find "$SRC" -type f \
        \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.heic" -o -iname "*.gif" -o -iname "*.webp" \
           -o -iname "*.mov" -o -iname "*.mp4" -o -iname "*.m4v" -o -iname "*.avi" -o -iname "*.hevc" \) 2>/dev/null | wc -l | awk '{print "files:", $1}'

      find "$SRC" -type f \
        \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.heic" -o -iname "*.gif" -o -iname "*.webp" \
           -o -iname "*.mov" -o -iname "*.mp4" -o -iname "*.m4v" -o -iname "*.avi" -o -iname "*.hevc" \) \
        -exec stat -f "%z" {} + 2>/dev/null | awk '{s+=$1} END {printf "size: %.2f GiB\n", s/1024/1024/1024}'
    else
      echo "Media-only preview (common image/video extensions):"
      find "$SRC" -type f \
        \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.heic" -o -iname "*.gif" -o -iname "*.webp" \
           -o -iname "*.mov" -o -iname "*.mp4" -o -iname "*.m4v" -o -iname "*.avi" -o -iname "*.hevc" \) 2>/dev/null | wc -l | awk '{print "files:", $1}'

      find "$SRC" -type f \
        \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.heic" -o -iname "*.gif" -o -iname "*.webp" \
           -o -iname "*.mov" -o -iname "*.mp4" -o -iname "*.m4v" -o -iname "*.avi" -o -iname "*.hevc" \) \
        -exec stat -f "%z" {} + 2>/dev/null | awk '{s+=$1} END {printf "size: %.2f GiB\n", s/1024/1024/1024}'
    fi
  else
    echo
    echo "All-attachments preview:"
    find "$SRC" -type f 2>/dev/null | wc -l | awk '{print "files:", $1}'
  fi
}

apply_copy() {
  mkdir -p "$DEST"

  if [ "$MEDIA_ONLY" = "true" ]; then
    if [ "$FLAT_MODE" = "true" ]; then
      local tmp_list
      tmp_list="$(mktemp)"
      find "$SRC" -type f \
        \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.heic" -o -iname "*.gif" -o -iname "*.webp" \
           -o -iname "*.mov" -o -iname "*.mp4" -o -iname "*.m4v" -o -iname "*.avi" -o -iname "*.hevc" \) \
        -print > "$tmp_list"

      while IFS= read -r src_file; do
        [ -z "$src_file" ] && continue
        base_name="$(basename "$src_file")"
        target_file="$DEST/$base_name"

        # Handle collision suffix if needed
        if [ -e "$target_file" ]; then
          stem="${target_file%.*}"
          ext=""
          if [[ "$target_file" == *.* ]]; then
            ext=".${target_file##*.}"
          fi
          suffix=1
          while [ -e "$stem__${suffix}${ext}" ]; then
            suffix=$((suffix + 1))
          done
          target_file="$stem__${suffix}${ext}"
        fi

        cp -p "$src_file" "$target_file"
      done < "$tmp_list"
      rm -f "$tmp_list"
    else
      local files_list
      files_list="$(mktemp)"
      (
        cd "$SRC"
        find . -type f \
          \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.heic" -o -iname "*.gif" -o -iname "*.webp" \
             -o -iname "*.mov" -o -iname "*.mp4" -o -iname "*.m4v" -o -iname "*.avi" -o -iname "*.hevc" \) \
          -print
      ) > "$files_list"

      rsync -a --files-from="$files_list" "$SRC/" "$DEST/"
      rm -f "$files_list"
    fi
  else
    rsync -a "$SRC/" "$DEST/"
  fi

  echo
  echo "Export complete."
  echo "Destination: $DEST"
  du -sh "$DEST" 2>/dev/null || true
}

main() {
  parse_args "$@"
  check_access
  preview_counts

  if [ "$APPLY" != "true" ]; then
    echo
    echo "Dry-run only. No files copied."
    echo "To run export: $(basename "$0") --apply"
    exit 0
  fi

  apply_copy
  echo
  echo "Important: iCloud Messages deletion should be done from Messages app settings/conversations,"
  echo "not by deleting files directly from Library, to avoid database inconsistency."
}

main "$@"