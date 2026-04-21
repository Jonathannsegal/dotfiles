#!/usr/bin/env bash

set -euo pipefail

HOME_DIR="${HOME}"

print_section() {
  printf "\n=== %s ===\n" "$1"
}

print_section "Disk Free"
df -h "${HOME_DIR}"

print_section "Top-Level Home Usage"
du -hd 1 "${HOME_DIR}" 2>/dev/null | sort -h

print_section "Library High-Level"
for p in \
  "${HOME_DIR}/Library/Application Support" \
  "${HOME_DIR}/Library/Containers" \
  "${HOME_DIR}/Library/Caches" \
  "${HOME_DIR}/Library/CloudStorage" \
  "${HOME_DIR}/Library/Group Containers" \
  "${HOME_DIR}/Library/Developer" \
  "${HOME_DIR}/Library/Logs"; do
  [ -e "$p" ] && du -sh "$p" 2>/dev/null
done | sort -h

print_section "Targeted Cleanup Candidates"
for p in \
  "${HOME_DIR}/Library/Containers/com.apple.podcasts/Data/tmp/StreamedMedia" \
  "${HOME_DIR}/Library/Containers/com.goodsnooze.MacWhisper/Data/tmp" \
  "${HOME_DIR}/Library/Containers/com.goodsnooze.MacWhisper/Data/Library/Caches" \
  "${HOME_DIR}/Library/Containers/com.goodsnooze.MacWhisper/Data/Library/Application Support/MacWhisper/models" \
  "${HOME_DIR}/Library/Application Support/Google/Chrome/Default/Service Worker" \
  "${HOME_DIR}/Library/Application Support/Google/Chrome/Default/File System" \
  "${HOME_DIR}/Library/Application Support/Google/Chrome/Default/IndexedDB" \
  "${HOME_DIR}/Library/Application Support/Slack/Cache" \
  "${HOME_DIR}/Library/Application Support/discord/Cache" \
  "${HOME_DIR}/Library/Application Support/Code/Cache" \
  "${HOME_DIR}/Library/Application Support/Code/CachedData" \
  "${HOME_DIR}/Library/Caches/Homebrew" \
  "${HOME_DIR}/Library/Caches/pnpm" \
  "${HOME_DIR}/.npm" \
  "${HOME_DIR}/.cache"; do
  [ -e "$p" ] && du -sh "$p" 2>/dev/null
done | sort -h

print_section "Largest Applications"
find /Applications "${HOME_DIR}/Applications" -maxdepth 1 -name "*.app" -type d 2>/dev/null |
while read -r app; do
  kb=$(du -sk "$app" 2>/dev/null | awk '{print $1}')
  [ -n "$kb" ] && printf "%s\t%s\n" "$kb" "$app"
done | sort -nr | head -n 50 | awk '{printf "%.2f GiB\t%s\n", $1/1024/1024, $2}'

print_section "Done"
echo "Read-only audit complete."