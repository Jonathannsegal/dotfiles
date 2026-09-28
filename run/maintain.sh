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
  check      Run fresh health checks; --details includes audit logs.
  update     Update managed apps and tools, clean unused dependencies, refresh health.
  snapshot   Write a local state report under ~/CleanupStaging/state-snapshots.
  restore    Snapshot first, then converge the machine back to this repo.

Examples:
  $(basename "$0") check
  $(basename "$0") update
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
    python3 "$DOTFILES/run/health.py" "$@"
}

update() {
    local failures=0
    local profile
    # Use executables directly, without shell wrappers that overwrite Brewfile.
    bash "$DOTFILES/brew/setup-local-tap.sh" || return $?
    brew update || return $?
    run_report_command "Homebrew updates" brew upgrade --greedy --yes --no-quit || failures=$((failures + 1))
    run_report_command "App Store updates" mas update || failures=$((failures + 1))
    # npm 12 blocks lifecycle scripts by default. Allow only the installers
    # required by these managed tools and their native dependencies.
    run_report_command "Global npm tools" npm update --global \
        --allow-scripts=@anthropic-ai/claude-code,agent-browser,esbuild,fsevents,core-js || failures=$((failures + 1))
    run_report_command "Python apps" pipx upgrade-all || failures=$((failures + 1))
    run_report_command "VS Code extensions" code --update-extensions || failures=$((failures + 1))
    while IFS= read -r profile; do
        run_report_command "VS Code profile: $profile" code --profile "$profile" --update-extensions || failures=$((failures + 1))
    done < <(jq -r '.profiles | keys[]' "$DOTFILES/vscode/profiles.json")
    run_report_command "Unused Homebrew dependencies" brew autoremove || failures=$((failures + 1))
    run_report_command "Homebrew cleanup" brew cleanup || failures=$((failures + 1))
    run_report_command "Available macOS updates" softwareupdate --list || failures=$((failures + 1))
    check --refresh || failures=$((failures + 1))
    echo "Restart updated apps when convenient. Adobe products, Cisco, and Unity editors use their vendor updaters."
    if [[ "$failures" -gt 0 ]]; then
        echo "$failures update step(s) need attention; see the errors above." >&2
        return 1
    fi
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
  check --refresh
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
    update) update "$@" ;;
    snapshot) snapshot "$@" ;;
    restore) restore "$@" ;;
    --help|-h|help) usage ;;
    *) usage >&2; exit 1 ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
