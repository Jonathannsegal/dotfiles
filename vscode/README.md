# Project profiles

Run `python3 ~/dotfiles/vscode/install-profiles.py` to recreate the profiles and
install the local detector. Normal dotfiles setup includes this step. Definitions
live in `profiles.json`; the existing Default profile remains available.

| Profile | Detection |
| --- | --- |
| Research/Python | Python project manifest, or shallow Python/notebook files |
| Unity/C# | Unity ProjectVersion.txt, solution, or C# project |
| Writing/LaTeX | Shallow .tex files |
| Lightweight | Other projects and collection folders such as home |

Opening a trusted local project automatically selects its profile. Detection is
bounded to shallow filenames and project markers, skips dependencies and
symlinks, and does not scan cloud trees recursively. New clones are detected
without maintaining path associations. Remote workspaces are left alone.
Mixed workspaces prioritize Unity, then Python, then writing.

For an ambiguous project, commit `.vscode/dotfiles-profile.json`:

```json
{"profile": "Writing/LaTeX"}
```

An override follows the repository across clones. The status bar explains the
detection and can be clicked to retry. Unsaved editors defer the switch. Installing
the extension does not reload an already-running window; reopen it or click the
status bar to apply. Set `dotfilesProfiles.enabled` to false to stop automatic
switches. New empty windows use Lightweight.

The detector invokes VS Code's native per-profile command after verifying it
exists; it never edits the live profile database. This command is internal and
may change in a future VS Code release; failure is reported in the status bar
and Dotfiles Profiles output channel. Re-run setup after recreating profiles.

Validation: `node --test vscode/auto-profiles/detect.test.js`.
