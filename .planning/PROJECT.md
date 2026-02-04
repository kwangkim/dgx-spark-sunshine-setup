# DGX Spark Sunshine Setup — Code Review & Polish

## What This Is

A quality pass on the DGX Spark Sunshine installer — reviewing all shell scripts and templates for correctness, shell best practices, robustness, and documentation quality. Also includes polishing the terminal UI/UX to be consistent across all scripts, and adding a true one-line installer that downloads a release tarball from GitHub without requiring git.

## Core Value

The installer works correctly and fails gracefully — users trust it to set up their DGX Spark for Sunshine streaming without breaking their system.

## Requirements

### Validated

- ✓ Interactive install flow with prerequisite checks, configuration prompts, backup, install, and validation — existing
- ✓ Virtual X11 display via custom EDID and xorg.conf generation — existing
- ✓ Sunshine systemd user service with autostart and lingering — existing
- ✓ Timestamped backup system for rollback — existing
- ✓ Resolution/codec/bitrate configuration with template substitution — existing
- ✓ Optional Tailscale VPN integration — existing
- ✓ Post-reboot verification script (after-install.sh) — existing
- ✓ Clean uninstaller with safety checks — existing
- ✓ Terminal UI theme: ASCII banner, tree-style sections, color-coded status indicators — existing (install.sh)

### Active

- [ ] Deep code review report covering all scripts and templates
  - Correctness: edge cases, error handling, things that could break
  - Shell best practices: quoting, variable handling, shellcheck compliance
  - Comments/documentation: scripts well-documented for future readers
  - Robustness: failure handling, rollback, cleanup, partial failures
- [ ] Visual theme improvement suggestions (concrete options to choose from)
- [ ] Visual theme consistency: after-install.sh and uninstall.sh follow install.sh's lead
- [ ] One-line installer: `curl` command that downloads release tarball from GitHub and runs install.sh

### Out of Scope

- Rewriting scripts from scratch — this is a review and polish pass, not a rewrite
- Adding new features beyond the one-liner (no manage.sh, no Ansible, no multi-display)
- Automated testing framework — may be a future milestone
- Supporting distros beyond Ubuntu 24.04 — existing scope only
- CI/CD pipeline — not needed for personal project

## Context

- Existing codebase is ~800 lines of bash across 3 scripts + 6 template files
- The codebase map (.planning/codebase/) already identifies tech debt, known bugs, security considerations, and fragile areas — these inform the review
- install.sh has a polished terminal theme (ASCII art banner, green/yellow colors, tree-style sections, checkmarks); other scripts are simpler
- The user wants to see the review report before deciding what to fix
- One-line installer should work without git on the target machine — curl downloads a tarball, extracts, runs install.sh

## Constraints

- **Platform**: NVIDIA DGX Spark (GB10), Ubuntu 24.04 LTS only
- **Language**: Pure bash — no external scripting languages
- **Quality bar**: Personal project — works well, doesn't need to be bulletproof
- **Approach**: Report first, then implement approved fixes

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Report before fixes | User wants to review findings and choose what to address | — Pending |
| install.sh is the visual model | Other scripts follow its theme but can be simpler | — Pending |
| One-liner uses tarball (not git clone) | No git dependency on target machine | — Pending |

---
*Last updated: 2026-02-04 after initialization*
