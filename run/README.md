# Run Scripts

`run/` is intentionally small. The public entry points are `setup.sh`,
`cleanup.sh`, `maintain.sh`, and `actions.sh`.

## Primary Commands

### `setup.sh`

Repeatable bootstrap for a new or existing Mac. It is designed to be rerun:
components that already match the repo are skipped.

It installs Homebrew when missing, configures Homebrew in `~/.zprofile`, installs
missing Brewfile dependencies, links dotfiles, installs shell plugins, installs VS Code
extensions, installs or updates Lens Studio from Snap's official Apple Silicon
download, imports Terminal.app profiles, runs the Python package installer,
force-refreshes custom app icons, installs the LaunchAgents that keep icons
reapplied and unmanaged installers blocked, and applies enforceable standards.

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

Setup applies enforceable standards unless `--no-standards` is passed: top-level
Git repos move into `~/Developer` except `~/dotfiles`, LaunchAgents marked
`disable` are disabled, and Homebrew items not listed in `brew/Brewfile` are
purged. It then
runs a strict audit as a report so remaining review items are visible without
blocking setup.

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

Creative Cloud is installed through Homebrew. Setup also hides Adobe's helper,
diagnostics, installer, and uninstaller app bundles so app search stays focused
on the user-facing Creative Cloud app.

Tailscale is installed through Homebrew. Setup configures Tailscale at the app
preference level to hide its Dock icon, but it does not launch Tailscale or
enable start-at-login.

Standards commands are available through `setup.sh`:

- `standards audit`: full read-only strict audit.
- `standards apps`: compare Homebrew formulae, casks, VS Code extensions, and npm globals
  against `brew/Brewfile`.
- `standards settings`: compare live macOS defaults against the managed settings.
- `standards home --dry-run`: report top-level home folder drift.
- `standards home --apply`: move top-level git repositories into `~/Developer`, except
  the canonical dotfiles repo at `~/dotfiles`.
- `standards launchagents audit`: compare startup/background items to
  `macos/launchagents.tsv`.
- `standards launchagents apply`: disable entries marked `disable`.
- `standards purge-unwanted --dry-run`: preview removal of Homebrew items not
  listed in `brew/Brewfile`.
- `standards purge-unwanted`: remove Homebrew casks and formula leaves not
  listed in `brew/Brewfile`, then run `brew autoremove` and `brew cleanup`.

### `cleanup.sh`

Storage cleanup and organization utility. It is reversible by default because
`move` sends files to `~/CleanupStaging` unless `--mode trash` is selected.
Apply commands also run standards enforcement after cleanup finishes.

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
- `projects`: list Git repositories and flag any outside `~/Developer`.

The managed app lists are `brew/Brewfile`, MAS entries in that Brewfile, and
`macos/app-allowlist.txt` for package-installed apps whose bundles are not
reported by Homebrew cask metadata. Removable Apple apps such as iMovie, News,
Numbers, Pages, and Freeform are listed in `macos/removable-apple-apps.txt`.
The `garageband` group removes optional GarageBand/Logic sound-library content
from `/Library/Application Support` and `/Library/Audio`. The `apps` and
`garageband` groups are included by `move --include all`.

### `maintain.sh`

Shortcuts for keeping the current machine shape easy to preserve and recover.

- `check`: run standards, Johnny.Decimal, and project-location checks now.
- `snapshot`: write a local state report under `~/CleanupStaging/state-snapshots`.
- `restore`: snapshot first, then run `setup.sh --yes --hard` and recheck.

Use `restore` when installed apps, preferences, icons, Dock items, or managed
dotfiles have drifted and you want to converge back to the repo baseline.

### `actions.sh`

Device and data actions that are useful but not part of setup or cleanup.
Currently it contains the Messages attachment exporter. The default is a dry-run,
flat, media-only export for photo review workflows.

Common usage:

```bash
./run/actions.sh messages --dry-run
./run/actions.sh messages --apply --dest ~/CleanupStaging/messages
```
