# Done

## Purpose
Track completed tasks.

## How To Use
- Move completed task summaries here.
- Include completion dates when helpful.

## Tasks
- 2026-05-26: Scaffolded repo and initialized Brain.

### Implement Jumpdir Roadmaps
- Priority: High
- Description: Implemented the CLI roadmap: config roots, discovery, duplicate detection, aliases, open commands, script execution, tests, installer polish, release docs, and Homebrew formula preparation.
- Related Feature: Jumpdir CLI
- Status: Done
- Created Date: 2026-05-26

### Add Curl Installer
- Priority: High
- Description: Updated `install.sh` so it works from a local clone or from `curl | bash`, with configurable repo owner, repo name, ref, source URL, and install directory.
- Related Feature: Jumpdir CLI
- Status: Done
- Created Date: 2026-05-26

### Document Installer Updates
- Priority: Medium
- Description: Documented updates as rerunning the installer, and fixed system directory install guidance to use `sudo env JUMPDIR_INSTALL_DIR=... bash`.
- Related Feature: Jumpdir CLI
- Status: Done
- Created Date: 2026-05-26

### Implement v0.2 Roadmap
- Priority: High
- Description: Implemented first-run onboarding, Preferred Runner config, runner get/set/clear commands, explicit runner overrides, missing-runner guidance, path printing, zsh jump integration, expanded tests, README updates, Brain updates, and version 0.2.0 release metadata.
- Related Feature: Jumpdir CLI
- Status: Done
- Created Date: 2026-05-30

### Add Zsh Completion
- Priority: Medium
- Description: Added zsh completion for command names, project names, aliases, and package scripts through `jumpdir init zsh`.
- Related Feature: Jumpdir CLI
- Status: Done
- Created Date: 2026-06-05

### Support Package Manager Commands
- Priority: High
- Description: Added explicit package-manager command parsing such as `jumpdir my-app bun install`, made `jumpdir my-app run dev` use the Preferred Runner, updated docs/tests, and bumped version to 0.2.1.
- Related Feature: Jumpdir CLI
- Status: Done
- Created Date: 2026-06-10

### Add Explicit Cd Command
- Priority: Medium
- Description: Added `jumpdir cd <project>` as an explicit jump command, wired zsh shell integration to change the parent directory, updated docs/tests, and bumped version to 0.2.2.
- Related Feature: Jumpdir CLI
- Status: Done
- Created Date: 2026-06-16

### Add Daily Update Prompt
- Priority: Medium
- Description: Added a once-per-day interactive startup update check, prompts `Update now? [Y/n]` when a newer version is available, continues the original command when declined, updated docs/tests, and bumped version to 0.2.3.
- Related Feature: Jumpdir CLI
- Status: Done
- Created Date: 2026-06-16

### Add Project Question Mark Help
- Priority: Medium
- Description: Added `jumpdir <project> ?` and `jumpdir <project> help` to show the resolved project path, common project commands, package scripts, and package-manager command examples, updated docs/tests, and bumped version to 0.3.0.
- Related Feature: Jumpdir CLI
- Status: Done
- Created Date: 2026-06-17

### Rename Product To Jumpdir
- Priority: High
- Description: Renamed the primary CLI and docs from `termcode` to `jumpdir`, added `bin/jumpdir`, kept `bin/termcode` as a compatibility shim, preserved old config/env fallbacks, updated installer/Homebrew/docs/tests, and set the next release version to 0.3.0.
- Related Feature: Jumpdir CLI
- Status: Done
- Created Date: 2026-06-17

### Fix Update Check Output Regression
- Priority: High
- Description: Made legacy config migration best-effort, made daily update marker writes non-blocking so commands still show help/errors when config bookkeeping cannot write, added regression coverage, and bumped version to 0.3.1.
- Related Feature: Jumpdir CLI
- Status: Done
- Created Date: 2026-06-17
