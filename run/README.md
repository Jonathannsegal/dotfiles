# Run Scripts

`run/` is intentionally small. Most machine-audit and enforcement behavior lives
behind `standards.sh` subcommands so there are fewer entry points to remember.

## Primary Commands

### `setup.sh`

Repeatable bootstrap for a new or existing Mac. It is designed to be rerun:
components that already match the repo are skipped.

It installs Homebrew when missing, configures Homebrew in `~/.zprofile`, installs
missing Brewfile dependencies, links dotfiles, installs shell plugins, installs VS Code
extensions, installs or updates Lens Studio from Snap's official Apple Silicon
download, imports Terminal.app profiles, runs the Python package installer,
refreshes custom app icons, and installs the LaunchAgents that keep icons
reapplied and unmanaged installers blocked.

Plain `./run/setup.sh` is the full setup path. In interactive mode it asks
before applying macOS defaults from `macos/settings.sh`; pressing Enter accepts.
`--yes` applies those defaults without prompting.

When setup reaches a privileged step, it asks for the administrator password
once and keeps that sudo session alive until setup exits. A fully satisfied
rerun can skip privileged work and avoid a password prompt.

Use `--hard` as the repair path when a setup was interrupted or a managed config
looks partially applied. It assumes yes, replaces managed dotfile links instead
of backing them up, reruns `brew bundle`, reapplies macOS settings, reloads
managed LaunchAgents, forces VS Code extension installs, updates shell plugins,
repairs Python packages, and reapplies custom icons.

Common usage:

```bash
./run/setup.sh
./run/setup.sh --yes
./run/setup.sh --macos
./run/setup.sh --hard
```

Lens Studio is not a Homebrew cask; `macos/lens-studio.sh` installs the latest
Apple Silicon build directly from Snap's official download API and is called by
setup unless `--no-lens-studio` is passed.

### `standards.sh`

The source-of-truth audit and enforcement command for keeping the Mac clean.

Subcommands:

- `audit`: full read-only strict audit.
- `apps`: compare Homebrew formulae, casks, VS Code extensions, and npm globals
  against `brew/Brewfile`.
- `settings`: compare live macOS defaults against the managed settings.
- `home --dry-run`: report top-level home folder drift.
- `home --apply`: move top-level git repositories into `~/Developer`.
- `launchagents audit`: compare startup/background items to
  `macos/launchagents.tsv`.
- `launchagents apply`: disable entries marked `disable`.
- `purge-unwanted --dry-run`: preview removal of banned app families.
- `purge-unwanted`: remove banned app families and helpers. This may ask for an
  administrator password once, then keep sudo alive for the purge.

The banned app families are Maxon, Logitech Options, Docker Desktop, Steam, and
Watchman.

### `cleanup.sh`

Storage cleanup and organization utility. It is reversible by default because
`move` sends files to `~/CleanupStaging` unless `--mode trash` is selected.

Subcommands:

- `audit`: read-only storage overview.
- `targets`: list cleanup target groups.
- `apps --dry-run`: preview Homebrew casks and visible `.app` bundles not on
  the managed app lists.
- `apps --apply`: uninstall unmanaged Homebrew casks and move unmanaged app
  bundles to `~/CleanupStaging`.
- `move --dry-run`: preview cleanup moves.
- `move --apply`: move selected cleanup targets.
- `reports`: generate duplicate/app/media review reports.
- `lint-personal`: lint `~/Personal` organization.

The managed app lists are `brew/Brewfile`, MAS entries in that Brewfile, and
`macos/app-allowlist.txt` for package-installed apps whose bundles are not
reported by Homebrew cask metadata. Removable Apple apps such as iMovie,
Numbers, Pages, and Freeform are listed in `macos/removable-apple-apps.txt`.
The `apps` group is included by `move --include all`.

### `export-messages-attachments.sh`

Exports Messages attachments without modifying the Messages database. The
default is a dry-run, flat, media-only export for photo review workflows.

Common usage:

```bash
./run/export-messages-attachments.sh --dry-run
./run/export-messages-attachments.sh --apply --dest ~/CleanupStaging/messages
```
