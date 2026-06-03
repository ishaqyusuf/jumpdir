# Termcode CLI

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
- `termcode set <paths...>` stores canonical root directories.
- `termcode ls` lists discovered project names and alias names with paths.
- Duplicate callable names are reported as ambiguous instead of resolved implicitly.
- `termcode rename <name-or-path> <alias>` stores an alias for a resolved project path.
- `termcode open <project>` opens Finder, and `termcode . <project>` opens VS Code.
- `termcode runner get/set/clear` manages the Preferred Runner.
- `termcode <project> <script> [args...]` runs scripts through the Preferred Runner.
- `termcode <project> <runner> run <script> [args...]` runs scripts through an explicit one-off runner.
- `termcode path <project>` prints a resolved project path.
- `termcode <project>` prints the project path without shell integration.
- `termcode init zsh` prints shell integration so one-argument project commands can `cd` in the parent shell.

## v0.2 Decisions
- Preferred Runner is the shipped name.
- Supported runner preferences are `bun`, `pnpm`, `npm`, `yarn`, and `none`.
- `auto` is not supported in v0.2; no runner is guessed from lockfiles.
- First-run onboarding triggers only on plain `termcode`.
- Without shell integration, `termcode <project>` prints the path rather than opening a subshell.
