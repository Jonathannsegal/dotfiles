# Dotfiles

Personal macOS dotfiles.

## Install

```bash
git clone https://github.com/Jonathannsegal/dotfiles.git ~/dotfiles
cd ~/dotfiles
./run/setup.sh
```

The default setup is safe to rerun. It converges the machine toward this repo and skips components that are already correctly configured. It will:

1. Create or update `~/.env.sh` with `DOTFILES`.
2. Symlink config files from this repo, backing up conflicting files to `~/.dotfiles_backup`.
3. Install Homebrew if needed, configure Homebrew in `~/.zprofile`, and install missing Homebrew bundle dependencies.
4. Install or update Snap Lens Studio for Apple Silicon from Snap's official download API.
5. Install missing zsh plugins outside shell startup.
6. Link Homebrew OpenJDK for macOS tools when approved and not already linked.
7. Install missing VS Code extensions from the Brewfile when VS Code is available.
8. Import Terminal.app profiles and run the Python package installer.
9. Ask whether to apply macOS defaults from `macos/settings.sh`.
10. Install a LaunchAgent that blocks unmanaged installers in `~/Downloads` and `~/Desktop`.
11. Force-refresh custom app icons and install the LaunchAgent that reapplies them at login, every 6 hours, and when `/Applications` changes.
12. Apply enforceable clean-computer standards and report any remaining audit drift.

## Useful Options

```bash
./run/setup.sh --yes          # non-interactive where possible
./run/setup.sh --no-brew      # skip Homebrew bundle
./run/setup.sh --no-icons     # skip icon refresh
./run/setup.sh --no-lens-studio # skip Lens Studio install/update
./run/setup.sh --macos        # apply macOS defaults without prompting
./run/setup.sh --no-macos     # skip macOS defaults
./run/setup.sh --no-terminal  # skip Terminal.app profiles
./run/setup.sh --no-python    # skip the Python package installer
./run/setup.sh --no-jdk       # skip the system OpenJDK symlink
./run/setup.sh --no-installer-guard # skip unmanaged installer blocking
./run/setup.sh --no-standards # skip standards enforcement
./run/setup.sh --hard         # repair mode: overwrite/reapply managed setup
```

Plain `./run/setup.sh` is the normal full setup. In interactive mode it asks before applying macOS defaults; pressing Enter accepts. `--yes` accepts that prompt automatically.

When setup reaches a privileged step, it asks for the administrator password once and keeps that sudo session alive until setup exits. A fully satisfied rerun can skip privileged work and avoid a password prompt.

Use `./run/setup.sh --hard` when a new-machine setup was interrupted or a managed config looks partially applied. Hard mode assumes yes, replaces managed dotfile links instead of backing them up, reruns `brew bundle`, reapplies macOS settings, reloads managed LaunchAgents, forces VS Code extension installs, updates shell plugins, repairs Python packages, and reapplies custom icons. It is scoped to repo-managed setup surfaces; it is not a general disk wipe.

Setup also applies the enforceable standards: top-level Git repos move into `~/Developer` except `~/dotfiles`, LaunchAgents marked `disable` are disabled, and Homebrew items not listed in `brew/Brewfile` are purged. The final standards audit is reported but does not fail setup when manual review items remain.

## Maintenance

See `run/README.md` for the full script map. The common commands are:

```bash
./run/cleanup.sh audit
./run/cleanup.sh targets
./run/cleanup.sh apps --dry-run
./run/cleanup.sh move --dry-run --include app-caches,dev-caches
./run/cleanup.sh reports
./run/cleanup.sh lint-personal
./run/actions.sh messages --dry-run
./run/setup.sh standards audit
./run/setup.sh standards apps
./run/setup.sh standards settings
./run/setup.sh standards home --dry-run
./run/setup.sh standards launchagents audit
./run/setup.sh standards purge-unwanted --dry-run
```

Cleanup moves are reversible by default when run with `--mode staging`; files are moved under `~/CleanupStaging` instead of deleted. `./run/cleanup.sh apps --apply` uninstalls Homebrew casks that are not in `brew/Brewfile`, moves visible app bundles that are not represented by `brew/Brewfile`, MAS entries, or `macos/app-allowlist.txt`, and removes removable Apple apps listed in `macos/removable-apple-apps.txt` when macOS allows it. Apply-mode cleanup commands also enforce standards afterward.

Dock items are managed in `macos/dock-items.txt`. Startup/background items are audited against `macos/launchagents.tsv`; only entries marked `disable` are changed by `./run/setup.sh standards launchagents apply`.

`./run/setup.sh standards apps` is the quickest way to see what is installed locally but no longer part of the repo-managed setup.

`./run/setup.sh standards purge-unwanted` removes installed Homebrew casks and formula leaves that are not listed in `brew/Brewfile`, then runs `brew autoremove` and `brew cleanup`. Run it from Terminal when protected `/Applications` or `/Library` leftovers require the administrator prompt.

## Clean Computer Standard

This repo is the source of truth for the machine. The standard is intentionally strict:

- Install apps, CLIs, npm globals, and VS Code extensions only through `brew/Brewfile`, MAS entries, or `macos/app-allowlist.txt` for package-installed apps that Homebrew cannot expose as `.app` metadata.
- Do not run downloaded `.dmg`, `.pkg`, `.mpkg`, or `.app` installers directly. The installer guard moves them to `~/CleanupStaging/blocked-installers` and tells you to install via Homebrew.
- Keep this dotfiles repo at `~/dotfiles`.
- Keep active code in `~/Developer`; interactive `git clone <url>` is wrapped to clone there by default.
- Keep personal files in `~/Personal`, school/research files in `~/School`, photos in `~/Pictures`, Lightroom work in `~/Lightroom`, screenshots and temporary downloads in `~/Downloads`, and Zotero data in `~/Zotero`.
- Keep Desktop empty except macOS metadata files.
- Treat Downloads as an inbox; review files older than 14 days.
- Manage Dock order through `macos/dock-items.txt`.
- Manage startup/background items through `macos/launchagents.tsv`; any `review` or unmanaged item fails the strict audit until it is classified.
- Manage macOS preferences through `macos/settings.sh`; unapplied differences fail the strict audit.
- Keep apps and CLI tools off the machine unless they are intentionally added back to `brew/Brewfile`, MAS entries, or the app allowlist.

Run `./run/setup.sh standards audit` when you want the full cleanliness check.

## Local Data Layout

- `~/dotfiles`: this dotfiles repo.
- `~/Developer`: active programming projects.
- `~/Personal`: personal files.
- `~/School`: school/research files.
- `~/Pictures`: photo libraries.
- `~/Lightroom`: Lightroom catalogs, previews, and project files.
- `~/Downloads`: screenshots and temporary downloads.
- `~/Zotero`: Zotero library data.

Interactive `git clone <url>` commands are wrapped by the shell config so new repositories land in `~/Developer` by default.

## Zotero

Zotero is installed by `brew/Brewfile` with `cask "zotero"`. The old source-build setup was removed because it cloned and built Zotero plus stale extensions instead of configuring the installed app reliably.
