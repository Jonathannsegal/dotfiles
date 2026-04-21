#!/usr/bin/env bash

set -euo pipefail

SRC="${HOME}/Library/Messages/Attachments"
DEST="${HOME}/CleanupStaging/messages_export_$(date +%Y%m%d_%H%M%S)"
APPLY=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply) APPLY=true ;;
    --dry-run) APPLY=false ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
  shift
done

if [ ! -d "$SRC" ]; then
  echo "Source not found: $SRC" >&2
  exit 1
fi

# Preview
echo "Source: $SRC"
echo "Destination: $DEST"
echo "Source total: $(du -sh "$SRC" | awk '{print $1}')"

PREVIEW_COUNT=$(find "$SRC" -type f \
  \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.heic" -o -iname "*.gif" -o -iname "*.webp" \
     -o -iname "*.mov" -o -iname "*.mp4" -o -iname "*.m4v" -o -iname "*.avi" -o -iname "*.hevc" \) 2>/dev/null | wc -l)

PREVIEW_SIZE=$(find "$SRC" -type f \
  \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.heic" -o -iname "*.gif" -o -iname "*.webp" \
     -o -iname "*.mov" -o -iname "*.mp4" -o -iname "*.m4v" -o -iname "*.avi" -o -iname "*.hevc" \) 2>/dev/null \
  -exec stat -f "%z" {} + | awk '{s+=$1} END {printf "%.2f GiB\n", s/1024/1024/1024}')

echo "Photos + Videos: $PREVIEW_COUNT files, $PREVIEW_SIZE"

if [ "$APPLY" != "true" ]; then
  echo ""
  echo "Dry-run mode. To export: $0 --apply"
  exit 0
fi

# Apply export
echo ""
echo "Exporting..."
mkdir -p "$DEST"

# Collect list of files to export
TMPFILE=$(mktemp)
trap "rm -f $TMPFILE" EXIT

find "$SRC" -type f \
  \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.heic" -o -iname "*.gif" -o -iname "*.webp" \
     -o -iname "*.mov" -o -iname "*.mp4" -o -iname "*.m4v" -o -iname "*.avi" -o -iname "*.hevc" \) 2>/dev/null > "$TMPFILE"

# Copy files with collision handling
while IFS= read -r src_file; do
  [ -z "$src_file" ] && continue

  base_name="$(basename "$src_file")"
  target_file="$DEST/$base_name"

  # Handle collision
  if [ -e "$target_file" ]; then
    stem="${target_file%.*}"
    if [ "$stem" = "$target_file" ]; then
      ext=""
    else
      ext=".${target_file##*.}"
    fi
    suffix=1
    while [ -e "${stem}__${suffix}${ext}" ]; do
      suffix=$((suffix + 1))
    done
    target_file="${stem}__${suffix}${ext}"
  fi

  cp -p "$src_file" "$target_file" 2>/dev/null || true
done < "$TMPFILE"

echo "Export complete."
echo "Destination: $DEST"
du -sh "$DEST"
echo ""
echo "Next steps:"
echo "1. Upload this folder to Google Photos"
echo "2. Verify all files appear correctly"
echo "3. In Messages app, go to Settings > delete from iCloud (never delete local files)"
