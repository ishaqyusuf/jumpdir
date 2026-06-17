# Permissions

## Purpose
Track filesystem and platform permissions.

## How To Use
- Update when the CLI gains new system interactions.

## Template
- Reads configured project roots.
- Writes config under `${XDG_CONFIG_HOME:-$HOME/.config}/jumpdir/`.
- Uses macOS `open` for Finder.
- Uses `code` for VS Code.
