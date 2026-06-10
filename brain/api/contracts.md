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
- `update` checks the published `bin/termcode` version and reports whether a newer version is available.
- `path <project>` prints a single resolved project path.
- `<project>` prints the resolved project path unless shell integration wraps it.
- `init zsh` provides zsh completion for command names, project names, aliases, and package scripts.
- interactive `<project>` also prints available package scripts on stderr when they can be read.
- script execution uses either the Preferred Runner, the explicit Preferred Runner form `termcode my-app run dev`, or an explicit runner form such as `termcode my-app bun run dev`.
- explicit runner commands such as `termcode my-app bun install` run inside the resolved project without package-script validation.
- invalid script names fail before invoking the runner and print available package scripts when they can be read.
- missing Preferred Runner fails with setup guidance instead of guessing a package manager.
