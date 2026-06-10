# Done

## Purpose
Track completed tasks.

## How To Use
- Move completed task summaries here.
- Include completion dates when helpful.

## Tasks
- 2026-05-26: Scaffolded repo and initialized Brain.

### Implement Termcode Roadmaps
- Priority: High
- Description: Implemented the CLI roadmap: config roots, discovery, duplicate detection, aliases, open commands, script execution, tests, installer polish, release docs, and Homebrew formula preparation.
- Related Feature: Termcode CLI
- Status: Done
- Created Date: 2026-05-26

### Add Curl Installer
- Priority: High
- Description: Updated `install.sh` so it works from a local clone or from `curl | bash`, with configurable repo owner, repo name, ref, source URL, and install directory.
- Related Feature: Termcode CLI
- Status: Done
- Created Date: 2026-05-26

### Document Installer Updates
- Priority: Medium
- Description: Documented updates as rerunning the installer, and fixed system directory install guidance to use `sudo env TERMCODE_INSTALL_DIR=... bash`.
- Related Feature: Termcode CLI
- Status: Done
- Created Date: 2026-05-26

### Implement v0.2 Roadmap
- Priority: High
- Description: Implemented first-run onboarding, Preferred Runner config, runner get/set/clear commands, explicit runner overrides, missing-runner guidance, path printing, zsh jump integration, expanded tests, README updates, Brain updates, and version 0.2.0 release metadata.
- Related Feature: Termcode CLI
- Status: Done
- Created Date: 2026-05-30

### Add Zsh Completion
- Priority: Medium
- Description: Added zsh completion for command names, project names, aliases, and package scripts through `termcode init zsh`.
- Related Feature: Termcode CLI
- Status: Done
- Created Date: 2026-06-05

### Support Package Manager Commands
- Priority: High
- Description: Added explicit package-manager command parsing such as `termcode my-app bun install`, made `termcode my-app run dev` use the Preferred Runner, updated docs/tests, and bumped version to 0.2.1.
- Related Feature: Termcode CLI
- Status: Done
- Created Date: 2026-06-10
