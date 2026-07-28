# ADR 0003: Zsh History Tab Paste

## Purpose
Record how highlighted history commands can be placed into the shell prompt without running them.

## Decision
When the generated zsh integration requests history protocol version 2, the picker enables Tab and returns a NUL-delimited selection action plus the original argument vector. The wrapper quotes each argument with zsh `%q` and uses raw `print -rz` output to queue the command in the next prompt.

## Context
Enter should keep replaying immediately, while Tab should let a user inspect or edit the selected command before pressing Enter. A standalone child process cannot modify its parent shell prompt, so this behavior is available only through zsh integration.

## Consequences
- Tab is advertised and handled only for protocol-version-2 zsh sessions.
- Existing integrations keep the legacy argument-only protocol and Enter behavior.
- Stored display text is never evaluated as shell code.
- Raw prompt insertion preserves `%q` backslashes so spaces and shell metacharacters remain part of their original arguments.
