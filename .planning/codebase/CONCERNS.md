# Codebase Concerns

**Analysis Date:** 2026-02-04

## Tech Debt

**X11 Session Environment Setup (Critical Flow Dependency):**
- Issue: Sunshine service requires `XAUTHORITY` environment variable to capture X session, but it's not automatically set. The installer doesn't export `XAUTHORITY` to systemd user manager at installation time.
- Files: `install.sh` (lines 599-604), `templates/sunshine-override.conf` (lines 8-10), `after-install.sh` (lines 82-99)
- Impact: Service may start but capture black screen if X session environment not properly configured. Users must manually run `dbus-update-activation-environment --systemd DISPLAY XAUTHORITY` from within the X session.
- Fix approach: Add automated step to detect and export X session environment during installation, or create a helper script that detects missing `XAUTHORITY` and guides users through setup.

**External Dependency on GitHub Release API (Network Reliability):**
- Issue: `install.sh` fetches Sunshine release info from GitHub API without fallback or caching (line 422: `curl -sL "${SUNSHINE_RELEASE_URL}"`). Installation fails silently if GitHub is unreachable or rate-limited.
- Files: `install.sh` (lines 420-450)
- Impact: Installation cannot proceed if GitHub API is down or unreachable. No user-friendly error message distinguishes network failures from missing release artifacts.
- Fix approach: Add retry logic with exponential backoff, GitHub rate limit detection, and fallback to pinned known-good version. Cache last successful download URL locally.

**Hardcoded EDID Filename and Hardware Assumptions:**
- Issue: Installer hardcodes output as `/etc/X11/4k120.edid` and assumes GB10 hardware exists. Custom EDID validation only checks file type, not pixel clock compatibility with GB10's 165 MHz limit.
- Files: `install.sh` (lines 459-485), README.md (line 43)
- Impact: Users with incompatible EDIDs may complete installation successfully but see black screen or mode negotiation failures at boot. No runtime validation prevents incompatible configs.
- Fix approach: Add EDID validation to check pixel clock against GB10 limit. Make EDID filename configurable or query max refresh rate from device tree.

**Backup Strategy Vulnerabilities:**
- Issue: Backups stored in `~/.sunshine-setup-backups/` with world-readable permissions (chmod not specified). Backup contains sensitive files like `sunshine_state.json` which may include authentication tokens.
- Files: `install.sh` (lines 362-398)
- Impact: User credentials potentially exposed if home directory has lax permissions. No encryption or secure deletion of old backups.
- Fix approach: Set backup directory to `700` permissions. Add backup rotation policy (keep only last N backups). Option to encrypt backups.

**Tailscale Auth Key Handling:**
- Issue: Tailscale auth key accepted as command-line prompt input (line 726, `prompt_secret`). No validation that auth key matches expected format. Auth key may be logged in shell history.
- Files: `install.sh` (lines 725-737)
- Impact: Auth key could be intercepted or leaked via shell history. Discourages users from automating installation if it requires manual auth key entry.
- Fix approach: Support auth key via environment variable (e.g., `TS_AUTH_KEY`) to allow automation without interactive prompt. Document history security. Add cleanup of shell history option.

## Known Bugs

**GPU BusID Detection Race Condition (Fixed in recent commit, but fragile):**
- Symptoms: Fallback BusID detection may fail to find GPU if device naming varies. lspci output format depends on kernel/BIOS version.
- Files: `install.sh` (lines 493-527)
- Trigger: Systems with non-standard NVIDIA GPU enumeration or older kernels that don't use domain:bus:device.function format
- Workaround: Manual BusID configuration - users can edit xorg.conf after installation if auto-detection fails

**XAUTHORITY not set when using SSH + systemd User Service:**
- Symptoms: Black screen or "cannot open display" errors despite X session running
- Files: `templates/sunshine-override.conf`, `setup.md` (lines 16-30)
- Trigger: User installs via SSH without running `dbus-update-activation-environment` from within an active X session
- Workaround: `dbus-update-activation-environment --systemd DISPLAY XAUTHORITY` must be run from within the X session; documented in setup.md but requires user knowledge

**Uninstaller Assumes User Ran as Non-Root (Safety Check):**
- Symptoms: Uninstaller exits if run with sudo, but doesn't check if Sunshine service belongs to current user
- Files: `uninstall.sh` (lines 59-64)
- Trigger: If installation was done by different user, uninstall fails or removes wrong user's services
- Workaround: Manual cleanup required if uninstaller rejects execution

## Security Considerations

**Sudo Usage in Installer (Privilege Escalation):**
- Risk: Multiple `sudo` calls throughout installer without explicit approval prompts for each operation. User must understand what each `sudo` does.
- Files: `install.sh` (lines 371, 378, 385, 443, 473-474, 538-539, 554-563, 615, 673, 688-690, 717, 729, 737)
- Current mitigation: Uses `set -e` to exit on any command failure. Configuration summary shown before installation starts. User prompted for auto-start and Tailscale separately.
- Recommendations:
  - Add `--confirm-all` flag to skip interactive prompts (requires explicit flag for CI/automation)
  - Show detailed breakdown of which files will be modified before requesting sudo password
  - Log all privileged operations to `~/.sunshine-setup-audit.log` for accountability

**Udev Rules Installation (Input Device Access):**
- Risk: Udev rule `85-sunshine.rules` grants `uaccess` to `uinput` kernel device, allowing current user to intercept input from all applications
- Files: `install.sh` (lines 558-559)
- Current mitigation: Only applies to current user via `uaccess` tag. Requires user to be in `video` group.
- Recommendations:
  - Document security implications in README
  - Provide option to use `input` group instead of uaccess (more restricted)
  - Add uninstall warning that shows what permissions are being removed

**Custom EDID File Validation:**
- Risk: No validation that custom EDID file is actually valid EDID data or came from a trusted source
- Files: `install.sh` (lines 476-482)
- Current mitigation: Basic `file` command check; validation is "uncertain"
- Recommendations:
  - Use `edid-decode` tool if available to validate structure
  - Warn user if EDID is modified/truncated
  - Document safe sources for EDID files (Linux TV database)

**Sensitive Files in Configuration Backups:**
- Risk: `sunshine_state.json` may contain authentication credentials stored in home directory backup
- Files: `install.sh` (lines 362-398), README.md (lines 196-206)
- Current mitigation: Backups in home directory with standard permissions; relies on home directory security
- Recommendations:
  - Set backup directory to `700` (rwx------)
  - Add option to encrypt backups or prompt for passphrase
  - Document that backups should be kept secure

## Performance Bottlenecks

**Network I/O During Installation (GitHub API Fetch):**
- Problem: Sunshine .deb download may be large (20-50MB) and could take time over slow connections
- Files: `install.sh` (lines 440)
- Cause: Single-threaded curl download, no compression, no resume capability
- Improvement path:
  - Add curl options for compression (`--compressed`)
  - Add resume support (`-C -`)
  - Show progress bar (`--progress-bar` or `--show-error`)
  - Consider caching in `/var/cache` with validation

**Validation Loops (Repetitive Checks):**
- Problem: `validate_installation()` checks same files multiple times; each check opens files separately
- Files: `install.sh` (lines 762-825)
- Cause: No batching of validations; `grep` called separately for each check
- Improvement path: Combine file checks into single pass; cache results

## Fragile Areas

**Shell Script Portability (Bash-Specific Syntax):**
- Files: `install.sh`, `uninstall.sh`, `after-install.sh`
- Why fragile: Uses bash-specific features (`$(...)`, `[[ ]]`, regex operators) that may not work in sh-compatible shells. Arrays used in loops may break if unquoted.
- Safe modification: Always quote variables: `"${variable}"` not `$variable`. Use `[[` for conditionals. Test on both bash 4.x and 5.x.
- Test coverage: Limited - scripts only tested against single bash version. No integration tests.

**GPU Detection via lspci Output Parsing:**
- Files: `install.sh` (lines 493-527)
- Why fragile: Regex patterns assume specific lspci output format. Kernel updates or different hardware can change output. Multiple fallbacks suggest previous failures.
- Safe modification: Test BusID detection on multiple kernel versions and GB10 variants before merging. Add verbose mode to show detected vs. expected output.
- Test coverage: None visible; only "tested on one system" development

**X11 Configuration File Generation (sed substitution):**
- Files: `install.sh` (lines 530-540)
- Why fragile: Uses sed with `|` delimiter and unescaped `{{` variables. If paths contain pipe characters or regex metacharacters, sed will fail silently or corrupt xorg.conf.
- Safe modification: Use safer delimiter (`sed -e "s#{{BUS_ID}}#${pci_bus_id}#g"`) or printf-based templating. Validate generated xorg.conf syntax before installing.
- Test coverage: None - no xorg.conf validation after generation

**Systemd User Service State Assumptions:**
- Files: `install.sh` (lines 588-627), `after-install.sh` (lines 148-162)
- Why fragile: Script assumes systemd user services work consistently. Lingering, socket activation, and session scope vary by systemd version.
- Safe modification: Query `systemctl --version` and check known issues. Test service startup on systems with user services disabled. Provide manual fallback commands.
- Test coverage: Tested on Ubuntu 24.04 only; behavior may differ on other distributions

## Scaling Limits

**Backup Directory Unbounded Growth:**
- Current capacity: Each backup ~100KB-1MB depending on config size. Timestamped naming creates new backup per run.
- Limit: Installing 10+ times could create 10+ MB in backups. No rotation or cleanup.
- Scaling path:
  - Implement backup rotation: keep only last 5 backups, auto-delete older ones
  - Add `--cleanup-backups` flag to remove old backups
  - Compress old backups with gzip

**Single EDID File Limitation:**
- Current capacity: One EDID file per system (`/etc/X11/4k120.edid`). Supporting multiple displays would require separate EDID files.
- Limit: Future multi-display setups cannot coexist; would need xorg.conf redesign.
- Scaling path:
  - Plan for multiple virtual displays (DFP-0, DFP-1, etc.)
  - Generate EDID filenames based on output port names
  - Store EDID metadata for easy switching

## Dependencies at Risk

**Sunshine Project Stability:**
- Risk: Sunshine is community-maintained project with evolving API. New releases may have breaking config changes.
- Impact: sunshine.conf template may become incompatible. NVENC preset names may change.
- Migration plan:
  - Pin to known-good Sunshine version in README
  - Add version check in install.sh; warn if newer major version differs
  - Document breaking changes in CHANGELOG
  - Provide migration script for config upgrades

**Ubuntu 24.04 Specific:**
- Risk: Installer targets Ubuntu 24.04 .deb package. Support for other distros/versions unclear.
- Impact: Users on Ubuntu 22.04 or Debian may experience package conflicts.
- Migration plan:
  - Expand testing to other LTS versions
  - Create fallback download logic for Debian Trixie/Bookworm
  - Document minimum Ubuntu/kernel version requirements

**Tailscale Optional Dependency (Version Compatibility):**
- Risk: Tailscale auth key format or CLI flags may change between versions.
- Impact: `--authkey` flag may not exist in older Tailscale versions; scripts will fail silently.
- Migration plan:
  - Check Tailscale version before using --authkey
  - Provide manual setup instructions for unsupported versions
  - Document tested Tailscale versions in README

## Missing Critical Features

**No Pre-Installation Dry-Run Mode:**
- Problem: No way to preview what will be modified without actually running installation
- Blocks: Users cannot validate configuration or understand impact before sudo
- Improvement: Add `--dry-run` flag that shows all operations without executing them

**No Rollback/Restore Functionality:**
- Problem: Backups are created, but no easy one-command restore. Users must manually navigate backup directory and copy files.
- Blocks: Users cannot easily recover from bad installation
- Improvement: Add restore function: `./uninstall.sh --restore <backup_timestamp>`

**No Configuration Management After Installation:**
- Problem: After install, editing sunshine.conf requires direct file editing and service restart
- Blocks: No GUI or CLI tool to change resolution/codec/bitrate without touching config files
- Improvement: Add interactive menu: `./manage.sh` to change common settings

**No Automated Testing for Virtual Display:**
- Problem: after-install.sh can't fully verify display on SSH sessions (xrandr fails)
- Blocks: Headless installations difficult to debug remotely
- Improvement: Add fallback checks via X11 logs; generate diagnostic report instead of just warnings

**No Multi-System Deployment Support:**
- Problem: Installer is single-system only; no way to deploy to fleet of DGX Spark machines
- Blocks: Enterprise deployments require manual installation per machine
- Improvement: Create Ansible playbook or cloud-init script wrapper

## Test Coverage Gaps

**No Unit Tests for Shell Functions:**
- What's not tested: Individual functions like `configure_codec()`, `validate_installation()`, backup restoration
- Files: `install.sh`, `uninstall.sh`
- Risk: Silent failures in individual functions don't cause exit due to `set -e` not catching subshell errors
- Priority: High - functions are core installation logic

**No Integration Tests for Full Installation Flow:**
- What's not tested: End-to-end install on fresh Ubuntu 24.04 system; uninstall after install; restore from backup
- Files: All scripts
- Risk: Broken installs discovered by users, not CI
- Priority: Critical - entire project purpose is installation

**No Test Coverage for GPU Detection Edge Cases:**
- What's not tested: Systems with no GPU, multiple GPUs, GPU without proper NVIDIA driver, domain numbers > 15
- Files: `install.sh` (lines 493-527)
- Risk: Installation succeeds but xorg.conf has wrong BusID, causing black screen
- Priority: High - very common failure mode

**No Network Failure Testing:**
- What's not tested: GitHub API rate limiting, network timeouts, corrupted .deb file download
- Files: `install.sh` (lines 420-450)
- Risk: Silent failures with confusing error messages
- Priority: Medium - typical user has internet

**No X11 Session Configuration Tests:**
- What's not tested: DISPLAY/XAUTHORITY environment handling, systemd user service with/without lingering
- Files: `templates/sunshine-override.conf`, `setup.md`
- Risk: Most common support issues (black screen) are untested
- Priority: Critical - explains >50% of reported issues

**No Uninstaller Verification Tests:**
- What's not tested: Uninstall removes all created files and permissions; no leftover files; original config restored from backup
- Files: `uninstall.sh`
- Risk: Partial uninstallation leaves orphaned files or broken configs
- Priority: High - users trust uninstaller to clean up

---

*Concerns audit: 2026-02-04*
