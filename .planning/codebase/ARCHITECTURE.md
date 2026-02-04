# Architecture

**Analysis Date:** 2026-02-04

## Pattern Overview

**Overall:** Multi-stage installer with modular setup phases

**Key Characteristics:**
- Interactive configuration-first approach: gathers user preferences before system modifications
- Layered installation: prerequisites → backup → install → configure → validate
- User session-aware service model: systemd user services for isolation and persistence
- Template-driven configuration: reduces hardcoding and enables version flexibility
- Graceful fallbacks: validation checks with optional skips for cross-platform compatibility

## Layers

**Prerequisites Layer:**
- Purpose: Verify hardware platform, system dependencies, and permissions before installation
- Location: `install.sh` (lines 121-182), `uninstall.sh` (lines 97-118)
- Contains: Hardware detection (GB10 GPU), package availability checks, permission validation
- Depends on: System binaries (nvidia-smi, Xorg, systemd, curl, sed, lspci)
- Used by: Main installation flow to prevent failed installs

**Configuration Layer:**
- Purpose: Interactively prompt user for display resolution, codec, bitrate, and EDID source
- Location: `install.sh` (lines 187-357)
- Contains: Resolution options (4K@60Hz, 1440p@120Hz, iPad Pro dimensions), codec selection (HEVC/AV1/H.264), bitrate prompts, EDID source choice (bundled/custom)
- Depends on: User input validation functions
- Used by: Main flow to capture preferences before system changes

**Backup Layer:**
- Purpose: Create timestamped backups of existing system configurations before modifications
- Location: `install.sh` (lines 362-398)
- Contains: Backup of xorg.conf, EDID files, Sunshine config, systemd overrides
- Depends on: Filesystem and backup directory creation
- Used by: Safety mechanism for rollback via `uninstall.sh`

**Installation Layer:**
- Purpose: Download and install Sunshine binary package from GitHub releases
- Location: `install.sh` (lines 403-450)
- Contains: Release API fetching, Ubuntu 24.04 ARM64 .deb selection, dpkg installation
- Depends on: curl, apt-get, internet connectivity, GitHub release artifacts
- Used by: Core streaming functionality

**Display Layer:**
- Purpose: Configure virtual X11 display via custom EDID and xorg.conf
- Location: `install.sh` (lines 455-545)
- Contains: EDID file installation (`/etc/X11/4k120.edid`), GPU BusID detection via lspci, xorg.conf template substitution, X11 driver configuration
- Depends on: EDID templates (`templates/samsung-q800t.bin`), xorg.conf template, GPU hardware detection
- Used by: Virtual display creation without physical monitor

**Permissions Layer:**
- Purpose: Grant user access to hardware resources (GPU, input devices)
- Location: `install.sh` (lines 550-567)
- Contains: User group membership (video, input), udev rules for uinput device access
- Depends on: usermod, udevadm system utilities
- Used by: Sunshine encoding and input capture functionality

**Service Configuration Layer:**
- Purpose: Configure and manage systemd user service for Sunshine
- Location: `install.sh` (lines 572-628)
- Contains: sunshine.conf generation from template, systemd user service setup, override.conf installation, auto-start enablement, session lingering configuration
- Depends on: Templates (sunshine.conf.template, sunshine.service, sunshine-override.conf), systemctl --user
- Used by: Automatic startup and X session environment propagation

**Optional Layer (Tailscale):**
- Purpose: Enable remote access via VPN without SSH port exposure
- Location: `install.sh` (lines 633-757)
- Contains: Tailscale package installation, systemd service enablement, autoconnect service setup, interactive login vs. auth key option
- Depends on: Optional apt-get, systemd, Tailscale binaries
- Used by: Remote streaming connectivity

**Validation Layer:**
- Purpose: Verify all system components are correctly installed and configured
- Location: `install.sh` (lines 762-825), `after-install.sh` (post-reboot checks)
- Contains: Binary existence checks, configuration file validation, EDID file verification
- Depends on: File system checks, systemd introspection
- Used by: Ensure installation completeness before user interaction

**Uninstallation Layer:**
- Purpose: Safely remove all Sunshine-related components and restore original state
- Location: `uninstall.sh` (lines 98-270)
- Contains: Service stopping/disabling, package removal, config cleanup, X11 restoration, udev rule removal, optional group membership cleanup
- Depends on: systemctl --user, apt-get, filesystem operations
- Used by: Complete removal with rollback to original system state

## Data Flow

**Installation Flow:**

1. User executes `./install.sh`
2. Display logo and banner
3. Check prerequisites (hardware, drivers, X11, systemd, tools)
4. Interactive configuration prompts (resolution, codec, bitrate, EDID source)
5. Print and confirm configuration summary
6. Create timestamped backup of current system state
7. Download and install Sunshine binary from GitHub (Ubuntu 24.04 ARM64 .deb)
8. Install EDID file to `/etc/X11/4k120.edid`
9. Detect NVIDIA GPU BusID via lspci and generate xorg.conf with CustomEDID option
10. Add user to video/input groups and configure udev rules
11. Generate sunshine.conf from template with user-selected codec, bitrate, FPS
12. Install/enable systemd user service (sunshine.service, sunshine-override.conf)
13. Optional: Configure Tailscale (install, enable, connect)
14. Validate all components installed correctly
15. Print final instructions (reboot, run after-install.sh)
16. User reboots system

**Post-Installation Flow (after-install.sh):**

1. Check virtual display status via xrandr (or X11 logs if SSH session)
2. Verify Sunshine service is running
3. Test GPU encoding capabilities (nvidia-smi)
4. Check network accessibility (curl to localhost:47990)
5. Provide troubleshooting guidance if issues found

**Uninstallation Flow:**

1. User executes `./uninstall.sh` (as normal user, NOT sudo)
2. Safety check: prevent running as root (would affect wrong user)
3. Stop Sunshine systemd user service
4. Remove Sunshine package via apt-get
5. Delete Sunshine configuration (~/.config/sunshine)
6. Remove systemd user service files
7. Remove X11 configuration files (xorg.conf, EDID)
8. Remove udev rules (85-sunshine.rules)
9. Optional: Remove user from video/input groups
10. Prompt to reboot

**State Management:**
- User preferences: Stored during interactive prompts, used for template substitution
- System state: Backed up to `~/.sunshine-setup-backups/YYYYMMDD-HHMMSS/` before modifications
- Service state: Managed via systemd --user (enable/disable, start/stop)
- X session environment: Propagated via `dbus-update-activation-environment --systemd DISPLAY XAUTHORITY`

## Key Abstractions

**Installation Stage:**
- Purpose: Encapsulate a single installation step (prerequisite check, backup, service config)
- Examples: `check_prerequisites()`, `create_backup()`, `install_sunshine()`, `configure_x11()`, `configure_sunshine()`
- Pattern: Each stage is a function with clear purpose, logging output, and error handling

**Configuration Template:**
- Purpose: Template file with placeholders for user-selected values
- Examples: `templates/xorg.conf.template` ({{BUS_ID}}, {{EDID_PATH}}), `templates/sunshine.conf.template` ({{CODEC}}, {{BITRATE}}, {{FPS}})
- Pattern: sed substitution at runtime based on user input and system detection

**Backup Structure:**
- Purpose: Preserve original configurations for rollback
- Location: `~/.sunshine-setup-backups/YYYYMMDD-HHMMSS/`
- Contains: xorg.conf, *.edid files, sunshine/ directory, sunshine-override.conf
- Pattern: Timestamp-based directory naming for multiple backup support

**Systemd User Service:**
- Purpose: Run Sunshine as user service (not root), enabling session-specific configuration
- Examples: `sunshine.service`, `sunshine.service.d/override.conf`, `tailscale-autoconnect.service`
- Pattern: Wants/After directives for dependency management (graphical-session.target, network-online.target)

## Entry Points

**Main Installation:**
- Location: `install.sh`
- Triggers: User runs `./install.sh` from repository root
- Responsibilities: Orchestrate entire installation workflow, gather configuration, verify prerequisites, modify system state

**Post-Installation Helper:**
- Location: `after-install.sh`
- Triggers: User runs `./after-install.sh` after system reboot
- Responsibilities: Verify virtual display, check Sunshine service, test GPU encoding, provide diagnostics

**Uninstallation:**
- Location: `uninstall.sh`
- Triggers: User runs `./uninstall.sh` (as normal user, NOT sudo)
- Responsibilities: Safely remove all Sunshine components, restore original configurations, clean up system state

## Error Handling

**Strategy:** Defensive with early exit on critical failures, optional skips for non-critical issues

**Patterns:**

**Critical Failures (exit on error):**
- Missing prerequisites trigger `exit 1` after listing failed checks
- Missing EDID file triggers exit in `install_edid()`
- Failed GPU BusID detection triggers exit in `configure_x11()`
- Failed Sunshine download/install triggers exit
- Configuration validation failures trigger exit

**Non-Critical Issues (optional skip):**
- GB10 GPU not detected: warn but allow continue with confirmation
- Sunshine already installed: warn, ask user to confirm reinstall/upgrade
- Enable lingering fails: warn but allow service to start on-demand until first login
- Tailscale installation skipped: optional feature, graceful warning

**Graceful Degradation:**
- SSH session without X11 display: fall back to checking X11 logs instead of running xrandr
- Custom EDID file not found: explicit error message with file path
- Failed systemd operations: provide manual command alternatives in output

## Cross-Cutting Concerns

**Logging:**
- Pattern: Color-coded log functions (`log_info`, `log_success`, `log_error`, `log_warning`, `log_step`, `log_substep`)
- Style: NVIDIA green theme (#112 in 256-color palette) for branding consistency
- Approach: Every significant action logged with progress indicators (▶, ✓, ✗, ⚠)

**Validation:**
- Pattern: Dedicated `validate_installation()` function runs after all modifications
- Approach: Check file existence (Sunshine binary, xorg.conf, EDID, sunshine.conf, systemd override)
- Scope: Verify all critical components before declaring success

**Authentication:**
- Pattern: `prompt_secret()` function for auth key input without echo (Tailscale)
- Approach: Read-only stdin without display, immediate clearing on use
- Scope: Optional Tailscale auth key handling

**Permissions:**
- Pattern: Explicit group membership and udev rules configuration
- Approach: Add user to video/input groups, install /etc/udev/rules.d/85-sunshine.rules for uinput
- Scope: Enable GPU access and input device capture without running Sunshine as root
