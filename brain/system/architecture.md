# Architecture

## Purpose
Track the technical shape of the CLI.

## How To Use
- Update when command parsing, config storage, or resolver behavior changes.
- Link important decisions from `brain/decisions/`.

## Template
- Entry point: `bin/jumpdir`
- Config directory: `${JUMPDIR_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/jumpdir}`
- Config files: `roots` as newline-delimited canonical paths, `aliases` as tab-separated alias/path records, `runner` as the preferred runner token, `onboarded` as the first-run completion marker, `update-check` as the last daily update-check date, and `history` as a human-readable command plus a tab-separated reversible argument vector for each recent action.
- Resolver: scan configured roots at runtime
- Project rule: direct child folder containing `package.json`
- Duplicate handling: report ambiguous callable names instead of choosing one implicitly.
- Runner: use configured Preferred Runner (`bun`, `pnpm`, `npm`, `yarn`, or `none`), explicit Preferred Runner script form (`jumpdir <project> run <script>`), explicit one-off script runner (`jumpdir <project> bun run <script>`), or package-manager commands (`jumpdir <project> bun install`).
- Onboarding: plain `jumpdir` starts setup until `onboarded` exists; `--help` and other commands do not trigger onboarding.
- Jump workflow: `jumpdir path <project>`, `jumpdir cd <project>`, and plain `jumpdir <project>` print the resolved path; `jumpdir init zsh` prints shell integration for real `cd` jumps.
- History: retain the 200 most recent unique action commands, show 20 by default, filter with case-insensitive literal matching, and use atomic locked updates for both recording and Backspace deletion. Interactive replay reconstructs argument arrays without evaluating stored shell text; zsh integration uses a versioned NUL-delimited selection protocol to either replay through the parent-shell wrapper or paste a per-argument-quoted command into its prompt.
- Updates: interactive startup skips help/version/update/history/completion/init, checks the published source version at most once per day, and can run the installer into the current binary directory when accepted.
