#!/usr/bin/env bash

set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
HOME_DIR="${HOME}"
SNAPSHOT_ROOT="${HOME_DIR}/CleanupStaging/state-snapshots"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

usage() {
  cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  check      Run the daily health checks now.
  snapshot   Write a local state report under ~/CleanupStaging/state-snapshots.
  restore    Snapshot first, then converge the machine back to this repo.

Examples:
  $(basename "$0") check
  $(basename "$0") snapshot
  $(basename "$0") restore
EOF
}

section() {
  printf "\n=== %s ===\n" "$1"
}

run_report_command() {
  local title="$1"
  shift

  section "$title"
  if "$@"; then
    return 0
  else
    printf "command failed: "
    printf "%q " "$@"
    printf "\n"
    return 1
  fi
}

check() {
  local failed=false

  run_report_command "Standards" bash "$DOTFILES/run/.standards.sh" audit || failed=true
  run_report_command "Johnny.Decimal" bash "$DOTFILES/run/cleanup.sh" lint-personal || failed=true
  run_report_command "Projects" bash "$DOTFILES/run/cleanup.sh" projects || failed=true

  [[ "$failed" == false ]]
}

snapshot() {
  local out_file
  mkdir -p "$SNAPSHOT_ROOT"
  out_file="${SNAPSHOT_ROOT}/state_${TIMESTAMP}.txt"

  {
    echo "state snapshot: $TIMESTAMP"
    echo "host: $(hostname)"
    echo "user: $(whoami)"
    echo "dotfiles: $DOTFILES"
    echo "dotfiles_head: $(git -C "$DOTFILES" rev-parse --short HEAD 2>/dev/null || echo unknown)"

    run_report_command "Dotfiles Git Status" git -C "$DOTFILES" status --short --ignored=matching || true
    run_report_command "Standards Audit" bash "$DOTFILES/run/.standards.sh" audit || true
    run_report_command "Johnny.Decimal" bash "$DOTFILES/run/cleanup.sh" lint-personal || true
    run_report_command "Projects" bash "$DOTFILES/run/cleanup.sh" projects || true
    run_report_command "Storage Audit" bash "$DOTFILES/run/cleanup.sh" audit || true
    run_report_command "Homebrew Bundle Check" brew bundle check --file="$DOTFILES/brew/Brewfile" || true
    run_report_command "LaunchAgents" bash "$DOTFILES/run/.standards.sh" launchagents audit || true
  } > "$out_file" 2>&1

  echo "$out_file"
}

restore() {
  local snapshot_file
  snapshot_file="$(snapshot)"
  echo "Snapshot: $snapshot_file"
  echo
  echo "Converging this Mac back to the repo-managed baseline..."
  bash "$DOTFILES/run/setup.sh" --yes --hard
  echo
  echo "Post-restore check:"
  check
}

main() {
  local command="${1:-}"
  [[ -n "$command" ]] || {
    usage
    exit 1
  }
  shift || true

  case "$command" in
    check) check "$@" ;;
    snapshot) snapshot "$@" ;;
    restore) restore "$@" ;;
    --help|-h|help) usage ;;
    *) usage >&2; exit 1 ;;
  esac
}

main "$@"
