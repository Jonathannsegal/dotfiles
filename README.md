# Dotfiles

My personal dotfiles for macOS. Managed with a custom bash script.

## Structure

- **zsh**: Shell configuration, aliases, and functions.
- **brew**: Homebrew Bundle (Brewfile) and installation scripts.
- **macos**: macOS defaults and preferences.
- **python**, **dotnet**, **jdk**, **vscode**: Language and tool-specific configurations.
- **terminal**: Terminal profiles (Dark/Light).

## Installation

```bash
git clone https://github.com/Jonathannsegal/dotfiles.git
cd dotfiles
./run/setup.sh
```

The setup script is interactive and will guide you through:
1. Linking config files.
2. Installing Homebrew packages.
3. Setting up macOS defaults.
4. Configuring language environments (Python, etc.).

## Customization

For machine-specific configurations that shouldn't be committed to the repo (API keys, path overrides), create a `~/.env.sh` file:

```bash
# ~/.env.sh
export SECRET_KEY="value"
```

This file is sourced automatically by `.zshrc`.

## TODO

1. https://it.cornell.edu/cuvpn
2. atlas ti
3. https://www.psychologie.hhu.de/arbeitsgruppen/allgemeine-psychologie-und-arbeitspsychologie/gpower
4. Login Items
5. Finder Settings
6. iterm2
