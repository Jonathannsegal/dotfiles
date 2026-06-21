#!/usr/bin/env bash

set -euo pipefail

HOME_DIR="${HOME}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
STAGING_ROOT="${HOME_DIR}/CleanupStaging"
MODE="staging"
APPLY=false
INCLUDE="all"

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [options]

Commands:
  audit            Read-only storage overview.
  targets          List reversible cleanup target groups.
  move             Dry-run or move selected cleanup targets.
  reports          Generate duplicate/app/media review reports.
  lint-personal    Run Johnny.Decimal lint for ~/Personal.

Move options:
  --dry-run         Preview selected targets. This is the default.
  --apply           Move selected targets.
  --mode staging    Move to ~/CleanupStaging. This is the default.
  --mode trash      Move to ~/.Trash.
  --include LIST    Comma-separated groups. Default: all.

Groups:
  podcasts, macwhisper, chrome, app-caches, dev-caches

Examples:
  $(basename "$0") audit
  $(basename "$0") targets
  $(basename "$0") move --dry-run --include chrome,dev-caches
  $(basename "$0") move --apply --mode staging --include podcasts
  $(basename "$0") reports
  $(basename "$0") lint-personal
EOF
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
}

contains_group() {
  local group="$1"
  [[ "$INCLUDE" == "all" || ",${INCLUDE}," == *",${group},"* ]]
}

target_size() {
  du -sh "$1" 2>/dev/null | awk '{print $1}'
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
  mv "$src" "$dest"
  echo "moved: $src -> $dest"
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

  [[ "$selected_count" -gt 0 ]] || die "no targets selected"

  if [[ "$APPLY" != true ]]; then
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

  echo
  echo "Move complete."
  echo "Reversal: move files from $dest_root back to original paths."
  echo "Report: $report_file"
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
    reports) generate_reports "$@" ;;
    lint-personal) lint_personal "$@" ;;
    --help|-h|help) usage ;;
    *) die "unknown command: $command" ;;
  esac
}

main "$@"
