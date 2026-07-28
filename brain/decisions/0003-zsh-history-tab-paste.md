# ADR 0003: Zsh History Prompt Paste

## Purpose
Record how highlighted history commands can be placed into the shell prompt without running them.

## Decision
When the generated zsh integration requests history protocol version 2, the picker makes Enter and Tab return a paste action plus the original argument vector using the NUL-delimited protocol. The wrapper quotes each argument with zsh `%q` and uses raw `print -rz` output to queue the command in the next prompt.

## Context
Selecting history should let a user inspect or edit the command before explicitly running it. A standalone child process cannot modify its parent shell prompt, so this default is available only through zsh integration.

## Consequences
- Enter is advertised as paste-first and Tab remains an equivalent shortcut in protocol-version-2 zsh sessions.
- Existing integrations keep the legacy argument-only protocol and Enter behavior.
- Stored display text is never evaluated as shell code.
- Raw prompt insertion preserves `%q` backslashes so spaces and shell metacharacters remain part of their original arguments.
