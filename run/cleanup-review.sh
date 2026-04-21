#!/usr/bin/env bash

set -euo pipefail

HOME_DIR="${HOME}"
OUT_DIR="${HOME_DIR}/CleanupStaging/reports"
TS="$(date +%Y%m%d_%H%M%S)"

mkdir -p "$OUT_DIR"

dup_report="${OUT_DIR}/duplicates_${TS}.txt"
app_report="${OUT_DIR}/apps_recency_${TS}.txt"
media_report="${OUT_DIR}/lossless_media_candidates_${TS}.txt"

echo "Generating duplicate report..."
find "$HOME_DIR" -type f -size +100M \
  -not -path "$HOME_DIR/Library/Caches/*" \
  -not -path "$HOME_DIR/.Trash/*" \
  -not -path "$HOME_DIR/Library/CloudStorage/Box-Box/*" \
  -not -path "$HOME_DIR/Library/Application Support/Box/*" \
  2>/dev/null | while read -r f; do
  sz=$(stat -f "%z" "$f" 2>/dev/null)
  bn=$(basename "$f")
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
  sz=$(du -sk "$app" 2>/dev/null | awk '{print $1}')
  lu=$(mdls -name kMDItemLastUsedDate -raw "$app" 2>/dev/null)
  mc=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$app" 2>/dev/null)
  [ -z "$lu" ] && lu="(unknown)"
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
  echo
  echo "Video note: meaningful lossless compression is usually minimal; avoid recompression unless archival workflow is required."
  echo "Potential tiny savings only: strip metadata (safe for quality, but can remove camera metadata)."
  echo
  echo "Example lossless image commands (manual, per file):"
  echo "  PNG: optipng -o2 <file.png>"
  echo "  JPEG: jpegtran -copy all -optimize -perfect <input.jpg> > <output.jpg>"
  echo "  TIFF: tiffcp -c lzw <input.tif> <output.tif>"
} > "$media_report"

echo "Reports generated:"
echo "  $dup_report"
echo "  $app_report"
echo "  $media_report"