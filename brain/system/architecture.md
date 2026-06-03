# Architecture

## Purpose
Track the technical shape of the CLI.

## How To Use
- Update when command parsing, config storage, or resolver behavior changes.
- Link important decisions from `brain/decisions/`.

## Template
- Entry point: `bin/termcode`
- Config directory: `${TERMCODE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/termcode}`
- Config files: `roots` as newline-delimited canonical paths, `aliases` as tab-separated alias/path records, `runner` as the preferred runner token, and `onboarded` as the first-run completion marker.
- Resolver: scan configured roots at runtime
- Project rule: direct child folder containing `package.json`
- Duplicate handling: report ambiguous callable names instead of choosing one implicitly.
- Runner: use explicit command runner (`termcode <project> bun run <script>`) or configured Preferred Runner (`bun`, `pnpm`, `npm`, `yarn`, or `none`).
- Onboarding: plain `termcode` starts setup until `onboarded` exists; `--help` and other commands do not trigger onboarding.
- Jump workflow: `termcode path <project>` and plain `termcode <project>` print the resolved path; `termcode init zsh` prints shell integration for real `cd` jumps.
