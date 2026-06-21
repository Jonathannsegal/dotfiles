#!/usr/bin/env bash

set -euo pipefail

SRC="${HOME}/Library/Messages/Attachments"
TS="$(date +%Y%m%d_%H%M%S)"
DEST="${HOME}/CleanupStaging/messages_export_${TS}"
APPLY=false
MEDIA_ONLY=true
FLAT_MODE=true
WRITE_MANIFEST=true

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Exports Messages attachments without modifying the Messages library.
Default mode is a dry-run, flat, media-only export for Google Photos workflows.

Options:
  --apply             Copy files.
  --dry-run           Preview only. This is the default.
  --source PATH       Source attachments folder. Default: ~/Library/Messages/Attachments
  --dest PATH         Export destination folder.
  --all               Export all attachments, not just common photo/video files.
  --media             Export common photo/video files. This is the default.
  --nested            Preserve source folder structure.
  --flat              Copy into one folder and add collision suffixes. This is the default.
  --no-manifest       Do not write a TSV manifest.
  -h, --help          Show this help.
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

find_files() {
  if [[ "$MEDIA_ONLY" == true ]]; then
    find "$SRC" -type f \
      \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.heic" -o -iname "*.gif" -o -iname "*.webp" \
         -o -iname "*.tif" -o -iname "*.tiff" -o -iname "*.mov" -o -iname "*.mp4" -o -iname "*.m4v" \
         -o -iname "*.avi" -o -iname "*.hevc" -o -iname "*.webm" \) \
      -print0 2>/dev/null
  else
    find "$SRC" -type f -print0 2>/dev/null
  fi
}

find_relative_files() {
  if [[ "$MEDIA_ONLY" == true ]]; then
    (
      cd "$SRC"
      find . -type f \
        \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.heic" -o -iname "*.gif" -o -iname "*.webp" \
           -o -iname "*.tif" -o -iname "*.tiff" -o -iname "*.mov" -o -iname "*.mp4" -o -iname "*.m4v" \
           -o -iname "*.avi" -o -iname "*.hevc" -o -iname "*.webm" \) \
        -print0 2>/dev/null
    )
  else
    (cd "$SRC" && find . -type f -print0 2>/dev/null)
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --apply) APPLY=true ;;
      --dry-run) APPLY=false ;;
      --source)
        shift
        SRC="${1:-}"
        [[ -n "$SRC" ]] || die "--source requires a path"
        ;;
      --dest)
        shift
        DEST="${1:-}"
        [[ -n "$DEST" ]] || die "--dest requires a path"
        ;;
      --all) MEDIA_ONLY=false ;;
      --media) MEDIA_ONLY=true ;;
      --nested) FLAT_MODE=false ;;
      --flat) FLAT_MODE=true ;;
      --no-manifest) WRITE_MANIFEST=false ;;
      --help|-h)
        usage
        exit 0
        ;;
      *) die "unknown argument: $1" ;;
    esac
    shift
  done

  SRC="${SRC/#\~/$HOME}"
  DEST="${DEST/#\~/$HOME}"
}

check_access() {
  [[ -d "$SRC" ]] || die "source folder not found: $SRC"

  if ! find "$SRC" -maxdepth 0 >/dev/null 2>&1; then
    die "cannot access $SRC. Grant Full Disk Access to Terminal or VS Code."
  fi

  if ! find "$SRC" -maxdepth 1 -type f >/dev/null 2>&1; then
    die "cannot read inside $SRC. Grant Full Disk Access to Terminal or VS Code."
  fi

  command -v stat >/dev/null 2>&1 || die "stat is required"
}

collect_stats() {
  FILE_COUNT=0
  TOTAL_BYTES=0

  while IFS= read -r -d '' file; do
    size="$(stat -f "%z" "$file" 2>/dev/null || echo 0)"
    FILE_COUNT=$((FILE_COUNT + 1))
    TOTAL_BYTES=$((TOTAL_BYTES + size))
  done < <(find_files)
}

print_size() {
  awk -v bytes="$1" 'BEGIN { printf "%.2f GiB", bytes / 1024 / 1024 / 1024 }'
}

check_destination_space() {
  mkdir -p "$DEST"

  available_kb="$(df -Pk "$DEST" | awk 'NR == 2 {print $4}')"
  required_kb=$((TOTAL_BYTES / 1024))

  if [[ -n "$available_kb" && "$required_kb" -gt "$available_kb" ]]; then
    die "destination may not have enough space. Need $(print_size "$TOTAL_BYTES"), available $(awk -v kb="$available_kb" 'BEGIN { printf "%.2f GiB", kb / 1024 / 1024 }')"
  fi
}

flat_target_for() {
  local src_file="$1"
  local base stem ext target path_hash suffix

  base="$(basename "$src_file")"
  target="$DEST/$base"

  if [[ ! -e "$target" ]]; then
    printf "%s" "$target"
    return 0
  fi

  stem="$base"
  ext=""
  if [[ "$base" == *.* && "$base" != .* ]]; then
    stem="${base%.*}"
    ext=".${base##*.}"
  fi

  path_hash="$(printf "%s" "$src_file" | shasum -a 1 | awk '{print substr($1,1,10)}')"
  target="$DEST/${stem}__${path_hash}${ext}"
  suffix=1
  while [[ -e "$target" ]]; do
    target="$DEST/${stem}__${path_hash}_${suffix}${ext}"
    suffix=$((suffix + 1))
  done

  printf "%s" "$target"
}

write_manifest_header() {
  local manifest="$1"
  printf "source\ttarget\tbytes\tmodified\n" > "$manifest"
}

append_manifest_row() {
  local manifest="$1"
  local src_file="$2"
  local target_file="$3"
  local bytes modified

  [[ "$WRITE_MANIFEST" == true ]] || return 0

  bytes="$(stat -f "%z" "$src_file" 2>/dev/null || echo 0)"
  modified="$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$src_file" 2>/dev/null || echo "")"
  printf "%s\t%s\t%s\t%s\n" "$src_file" "$target_file" "$bytes" "$modified" >> "$manifest"
}

copy_flat() {
  local manifest="$1"
  local src_file target_file

  while IFS= read -r -d '' src_file; do
    target_file="$(flat_target_for "$src_file")"
    cp -p "$src_file" "$target_file"
    append_manifest_row "$manifest" "$src_file" "$target_file"
  done < <(find_files)
}

copy_nested() {
  local manifest="$1"
  local files_list src_file rel target_file

  files_list="$(mktemp)"
  trap 'rm -f "$files_list"' RETURN

  find_relative_files > "$files_list"
  rsync -a --from0 --files-from="$files_list" "$SRC/" "$DEST/"

  while IFS= read -r -d '' rel; do
    src_file="$SRC/${rel#./}"
    target_file="$DEST/${rel#./}"
    append_manifest_row "$manifest" "$src_file" "$target_file"
  done < "$files_list"
}

main() {
  parse_args "$@"
  check_access
  collect_stats

  echo "Source: $SRC"
  echo "Destination: $DEST"
  echo "Mode: $([[ "$MEDIA_ONLY" == true ]] && echo media || echo all), $([[ "$FLAT_MODE" == true ]] && echo flat || echo nested)"
  echo "Files: $FILE_COUNT"
  echo "Size: $(print_size "$TOTAL_BYTES")"

  if [[ "$FILE_COUNT" -eq 0 ]]; then
    echo
    echo "Nothing to export."
    exit 0
  fi

  if [[ "$APPLY" != true ]]; then
    echo
    echo "Dry-run only. No files copied."
    echo "To export: $(basename "$0") --apply"
    exit 0
  fi

  check_destination_space

  manifest="$DEST/messages_export_manifest_${TS}.tsv"
  if [[ "$WRITE_MANIFEST" == true ]]; then
    write_manifest_header "$manifest"
  fi

  if [[ "$FLAT_MODE" == true ]]; then
    copy_flat "$manifest"
  else
    copy_nested "$manifest"
  fi

  echo
  echo "Export complete."
  echo "Destination: $DEST"
  du -sh "$DEST" 2>/dev/null || true
  if [[ "$WRITE_MANIFEST" == true ]]; then
    echo "Manifest: $manifest"
  fi
  echo
  echo "Do not delete files directly from ~/Library/Messages. Delete Messages data from the Messages app or macOS storage settings."
}

main "$@"
