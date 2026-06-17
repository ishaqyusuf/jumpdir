# Contracts

## Purpose
Define user-visible command contracts.

## How To Use
- Update when command inputs, outputs, or failure modes change.

## Template
- `set` replaces saved roots.
- `ls` prints callable project names alphabetically.
- `rename` creates aliases only.
- duplicate names fail until resolved with an alias.
- `runner get/set/clear` manages the Preferred Runner.
- `update` checks the published `bin/jumpdir` version and reports whether a newer version is available.
- interactive command startup checks for a newer version at most once daily, prompts `Update now? [Y/n]`, and continues the original command when declined.
- `path <project>` prints a single resolved project path.
- `cd <project>` prints a single resolved project path unless shell integration wraps it.
- `<project>` prints the resolved project path unless shell integration wraps it.
- `<project> ?` and `<project> help` print project-specific commands and scripts to stdout.
- `init zsh` provides zsh completion for command names, project names, aliases, and package scripts, and makes `jumpdir cd <project>` change the parent shell directory.
- interactive `<project>` also prints available package scripts on stderr when they can be read.
- script execution uses either the Preferred Runner, the explicit Preferred Runner form `jumpdir my-app run dev`, or an explicit runner form such as `jumpdir my-app bun run dev`.
- explicit runner commands such as `jumpdir my-app bun install` run inside the resolved project without package-script validation.
- invalid script names fail before invoking the runner and print available package scripts when they can be read.
- missing Preferred Runner fails with setup guidance instead of guessing a package manager.
