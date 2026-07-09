# Jumpdir CLI

## Purpose
Track the main CLI feature.

## How To Use
- Update as command behavior ships.

## Accepted Plan
- Build a macOS shell CLI installable with curl first and Homebrew later.
- Scan configured roots for direct child package projects.
- Support aliases without folder renames.
- Support Finder and VS Code open commands.
- Let users configure a Preferred Runner and override it per command.
- Provide first-run onboarding.
- Provide a project path and zsh jump workflow.

## Shipped Behavior
- `jumpdir set <paths...>` stores canonical root directories.
- `jumpdir ls` lists discovered project names and alias names with paths.
- Duplicate callable names are reported as ambiguous instead of resolved implicitly.
- `jumpdir alias <name-or-path> <alias>` stores an alias for a resolved project path.
- `jumpdir open <project>` opens Finder, and `jumpdir . <project>` opens VS Code.
- `jumpdir runner get/set/clear` manages the Preferred Runner.
- `jumpdir update` checks whether a newer published version is available.
- Interactive command startup checks for updates at most once per day and prompts before installing.
- `jumpdir <project> ?` and `jumpdir <project> help` print project-specific commands, package scripts, and package-manager examples.
- `jumpdir <project> <script> [args...]` runs scripts through the Preferred Runner.
- `jumpdir <project> run <script> [args...]` runs scripts through the Preferred Runner with an explicit `run` keyword.
- `jumpdir <project> <runner> run <script> [args...]` runs scripts through an explicit one-off runner.
- `jumpdir <project> <runner> <command> [args...]` runs package-manager commands like `install` or `add` inside the project.
- Invalid script names open a script picker in interactive terminals, or print available package scripts before exiting in non-interactive use, without invoking the runner first.
- `jumpdir path <project>` prints a resolved project path.
- `jumpdir cd <project>` prints a resolved project path in the binary, and changes directory when shell integration is installed.
- `jumpdir <project>` prints the project path without shell integration.
- Interactive `jumpdir <project>` also shows package-script suggestions on stderr.
- `jumpdir init zsh` prints shell integration so one-argument project commands and `jumpdir cd <project>` can `cd` in the parent shell.
- The zsh integration also completes command names, project names, aliases, and package scripts.

## v0.2 Decisions
- Preferred Runner is the shipped name.
- Supported runner preferences are `bun`, `pnpm`, `npm`, `yarn`, and `none`.
- `auto` is not supported in v0.2; no runner is guessed from lockfiles.
- First-run onboarding triggers only on plain `jumpdir`.
- Without shell integration, `jumpdir <project>` prints the path rather than opening a subshell.
