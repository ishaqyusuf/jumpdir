# termcode

`termcode` is a small macOS CLI for finding local repos, opening them, and running package scripts without remembering where every repo lives.

![termcode terminal demo](assets/termcode-terminal.png)

## Why termcode?

AI has changed how I work on code. I spend less time manually navigating an editor and more time running local projects from a multi-tabbed terminal.

`termcode` exists so I do not have to remember where every repo lives. Configure your project folders once, then list repos, open them, or run package scripts by name.

## Usage

```sh
termcode
termcode runner set pnpm
termcode set ~/Documents/code ~/Desktop/projects
termcode ls
termcode my-app
termcode my-app dev
termcode my-app bun run dev
termcode open my-app
termcode . my-app
termcode rename my-long-repo-name my-app
```

`termcode set` saves the roots to `${TERMCODE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/termcode}/roots`.
Aliases created by `termcode rename` are saved to `aliases` in the same directory, and your preferred runner is saved to `runner`.

## First Run

Run `termcode` with no arguments to start onboarding:

```text
Welcome to termcode.

Step 1: Choose your preferred runner
  1. bun run
  2. pnpm run
  3. npm run
  4. yarn run
  5. none

Step 2: Add project directories
  Example: ~/Documents/code ~/Desktop/projects
```

After each directory step, `termcode` lists the projects it found and lets you add another directory or proceed.

## Preferred Runner

The preferred runner is the package runner `termcode` uses when you run a script by name:

```sh
termcode runner set pnpm
termcode my-app dev
```

This runs:

```sh
pnpm run dev
```

To clear it:

```sh
termcode runner clear
```

If no preferred runner is set, provide one in the command:

```sh
termcode my-app bun run dev
termcode my-app pnpm run dev
termcode my-app npm run dev
termcode my-app yarn run dev
```

## Jump Workflow

Without shell integration, `termcode <project>` prints the project path:

```sh
termcode my-app
termcode path my-app
```

To make `termcode my-app` change your current shell directory in zsh, add this to your shell config:

```sh
eval "$(termcode init zsh)"
```

A standalone CLI cannot change its parent shell directory, so the shell integration wraps the binary and runs `cd "$(command termcode path my-app)"` for one-argument project jumps.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/ishaqyusuf/termcode/main/install.sh | bash
```

By default, the installer puts `termcode` at:

```sh
~/.local/bin/termcode
```

To choose another install location:

```sh
curl -fsSL https://raw.githubusercontent.com/ishaqyusuf/termcode/main/install.sh | sudo env TERMCODE_INSTALL_DIR=/usr/local/bin bash
```

Use `sudo` only for system-owned directories like `/usr/local/bin`.

## Update

Rerun the installer to update `termcode`. It overwrites the existing binary with the latest version from `main`.

```sh
curl -fsSL https://raw.githubusercontent.com/ishaqyusuf/termcode/main/install.sh | bash
```

If you installed to `/usr/local/bin`, update with the same install directory:

```sh
curl -fsSL https://raw.githubusercontent.com/ishaqyusuf/termcode/main/install.sh | sudo env TERMCODE_INSTALL_DIR=/usr/local/bin bash
```

## Install From Source

```sh
git clone https://github.com/ishaqyusuf/termcode.git
cd termcode
./install.sh
```

To install from a local clone into another directory:

```sh
TERMCODE_INSTALL_DIR=/usr/local/bin ./install.sh
```

To install from another branch or tag with curl:

```sh
curl -fsSL https://raw.githubusercontent.com/ishaqyusuf/termcode/main/install.sh | TERMCODE_REF=v0.2.0 bash
```

For forks, pass `TERMCODE_REPO_OWNER` and `TERMCODE_REPO_NAME` to the `bash` command.

## Homebrew Preparation

A formula template lives at `packaging/homebrew/termcode.rb.template`.
After tagging a release, replace the placeholder repository URL and checksum, then publish it through a tap.

## Project Discovery Rule

Discovery is intentionally simple:

- search only the roots configured with `termcode set`
- include only direct child folders
- include only folders containing `package.json`
- list callable names alphabetically
- report duplicate callable names instead of guessing

## Commands

```sh
termcode set <paths...>
termcode ls
termcode runner get
termcode runner set <bun|pnpm|npm|yarn|none>
termcode runner clear
termcode rename <current-name-or-path> <new-alias>
termcode path <project>
termcode init zsh
termcode open <project>
termcode . <project>
termcode <project> <script> [args...]
termcode <project> <runner> run <script> [args...]
```

Script execution uses your preferred runner, or the explicit runner you pass in the command.

## Development

```sh
./bin/termcode --help
./bin/termcode --version
./tests/run.sh
```

See `brain/PROJECT_INDEX.md` and `brain/tasks/backlog.md` for future work.
