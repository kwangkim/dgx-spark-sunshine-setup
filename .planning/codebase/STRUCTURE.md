# Codebase Structure

**Analysis Date:** 2026-02-04

## Directory Layout

```
dgx-spark-sunshine-setup/
├── install.sh                 # Main installation script (910 lines)
├── after-install.sh           # Post-reboot validation and diagnostics helper
├── uninstall.sh               # Complete removal and restoration script
├── setup.md                   # Step-by-step setup guide for iPad/SSH workflows
├── README.md                  # Project overview, quick start, troubleshooting
├── LICENSE                    # MIT license
├── edid/                      # EDID files for virtual display modes
│   └── samsung-q800t.bin      # Samsung Q800T 4K@60Hz, 1440p@120Hz EDID
├── img/                       # Documentation images
│   └── install.png            # Installer screenshot for README
└── templates/                 # Configuration templates for substitution
    ├── xorg.conf.template             # X11 config with BusID and EDID path placeholders
    ├── sunshine.conf.template         # Sunshine config with codec, bitrate, FPS placeholders
    ├── sunshine.service               # Systemd user service unit file
    ├── sunshine-override.conf         # Systemd service override with X session env vars
    ├── tailscale-autoconnect.service  # Optional system service for Tailscale auto-up
    └── tailscale-autoconnect.env.template  # Environment file for Tailscale args
```

## Directory Purposes

**Root Directory:**
- Purpose: Project entry point, user-facing scripts
- Contains: Bash installation/setup scripts, documentation, license
- Key files: `install.sh` (primary installer), `uninstall.sh` (removal), `after-install.sh` (post-install diagnostics)

**edid/**
- Purpose: EDID (Extended Display Identification Data) binary files for virtual display modes
- Contains: Pre-extracted monitor EDIDs that define supported resolutions and refresh rates
- Key files: `samsung-q800t.bin` (Samsung 4K TV EDID, default bundled option)
- Note: Users can provide custom EDID files via installer option

**img/**
- Purpose: Supporting images for documentation
- Contains: Screenshots, diagrams, visual guides
- Key files: `install.png` (installer UI screenshot)
- Note: Used in README.md for visual reference

**templates/**
- Purpose: Configuration template files for runtime substitution
- Contains: X11 xorg.conf, Sunshine config, systemd service unit files
- Substitution approach: sed regex replacement of placeholders ({{PLACEHOLDER}})
- No direct use: Templates are copied and modified by install.sh, never used directly

## Key File Locations

**Entry Points:**
- `install.sh`: Primary user-facing installer; orchestrates entire setup workflow
- `after-install.sh`: Post-reboot helper; verifies installation and provides diagnostics
- `uninstall.sh`: Cleanup script; removes all Sunshine components and restores system state

**Configuration:**
- `templates/xorg.conf.template`: X11 virtual display config (placeholders: {{BUS_ID}}, {{EDID_PATH}})
- `templates/sunshine.conf.template`: Sunshine streaming settings (placeholders: {{CODEC}}, {{BITRATE}}, {{FPS}})
- `templates/sunshine-override.conf`: Systemd override for X session environment
- `templates/sunshine.service`: Systemd user service unit definition
- `templates/tailscale-autoconnect.service`: Optional system-level Tailscale autoconnect
- `templates/tailscale-autoconnect.env.template`: Tailscale service environment file

**Core Logic:**
- `install.sh` main() function (lines 874-902): Orchestrates installation stages
- `install.sh` check_prerequisites() (lines 121-182): Hardware and dependency validation
- `install.sh` configure_x11() (lines 490-545): GPU BusID detection and xorg.conf generation
- `install.sh` install_sunshine() (lines 403-450): GitHub release download and installation
- `install.sh` configure_sunshine() (lines 572-628): Service configuration and enablement

**Testing/Diagnostics:**
- `after-install.sh` check_virtual_display() (lines 70-100+): Verify virtual display via xrandr or logs
- `after-install.sh` check_sunshine_service() (implied): Systemd service status verification
- `after-install.sh` test_encoding() (implied): GPU encoding capability check

**Documentation:**
- `README.md`: Quick start, overview, troubleshooting, architecture details
- `setup.md`: Step-by-step guide for SSH-based setup and iPad-only configuration
- `.planning/codebase/ARCHITECTURE.md`: Architecture and data flow analysis
- `.planning/codebase/STRUCTURE.md`: This file

## Naming Conventions

**Files:**
- Bash scripts: lowercase with hyphens (e.g., `install.sh`, `after-install.sh`, `uninstall.sh`)
- Configuration templates: descriptive with `.template` suffix (e.g., `xorg.conf.template`)
- Binary data: lowercase with `.bin` extension (e.g., `samsung-q800t.bin`)
- Markdown docs: uppercase (README.md, ARCHITECTURE.md) or descriptive (setup.md)

**Functions (Bash):**
- Main orchestrators: prefixed with action verb (e.g., `install_sunshine()`, `configure_x11()`, `create_backup()`)
- Logging helpers: `log_*` prefix (e.g., `log_info()`, `log_success()`, `log_error()`, `log_warning()`)
- Interactive prompts: `prompt_*` prefix (e.g., `prompt_user()`, `prompt_secret()`, `confirm()`)
- Validation: `validate_*` or `check_*` prefix (e.g., `validate_installation()`, `check_prerequisites()`)

**Variables:**
- Constants: UPPERCASE with underscores (e.g., `SCRIPT_DIR`, `BACKUP_DIR`, `SUNSHINE_CONFIG_DIR`)
- User inputs: lowercase with underscores (e.g., `RESOLUTION`, `CODEC`, `BITRATE`)
- Temporary values: descriptive lowercase (e.g., `bus_id`, `pci_bus_id`, `deb_file`)

**Directories (System-level):**
- X11 config: `/etc/X11/` (xorg.conf, *.edid files)
- User home config: `~/.config/sunshine/` (sunshine.conf, sunshine_state.json)
- Systemd user services: `~/.config/systemd/user/` (sunshine.service, sunshine.service.d/override.conf)
- System-wide services: `/etc/systemd/system/` (tailscale-autoconnect.service)
- System config: `/etc/default/` (tailscale-autoconnect)
- udev rules: `/etc/udev/rules.d/` (85-sunshine.rules)
- Backups: `~/.sunshine-setup-backups/YYYYMMDD-HHMMSS/` (user-specific backup archive)

## Where to Add New Code

**New Installation Stage:**
- Primary code: Add new function (e.g., `configure_feature()`) following pattern in `install.sh`
- Pattern: Use logging functions, create_backup() for safety, validate with dedicated function
- Integration: Add function call to main() orchestration sequence
- Example location: Insert between configure_sunshine() and validate_installation()

**New Feature/Option:**
- Configuration prompt: Add function like `configure_feature()` (lines 187-357 pattern)
- Template substitution: Create `templates/feature.template` with {{PLACEHOLDERS}}
- Validation: Add check to validate_installation()
- Documentation: Update README.md and setup.md with new option

**New Systemd Service:**
- Service unit file: Create `templates/feature.service` following sunshine.service pattern
- Installation: Add mkdir/cp logic to configure_sunshine() or new configure_* function
- Enable/disable: Add systemctl --user enable/disable calls with user confirmation
- Environment: Use override.conf pattern for systemd environment propagation

**New Utility Function:**
- Logging: Add to log_* family (e.g., `log_debug()`)
- Prompts: Add to prompt_* family (e.g., `prompt_choice()`)
- Validation: Add to check_*/validate_* family
- Location: Place in utility sections (lines 66-116 for log functions, etc.)

**Uninstall Cleanup:**
- Removal function: Add parallel function to uninstall.sh (e.g., `remove_feature()`)
- Pattern: Follow remove_*() structure with logging, error handling, confirmation prompts
- Integration: Call from main() uninstall sequence
- Example location: Between remove_udev_rules() and remove_user_groups()

## Special Directories

**~/.sunshine-setup-backups/YYYYMMDD-HHMMSS/:**
- Purpose: User-level backup archive with timestamp subdirectories
- Generated: Yes - created by create_backup() during installation
- Committed: No - user-specific runtime data
- Contents: Original xorg.conf, EDID files, Sunshine config, systemd overrides
- Retention: User-managed; no automatic cleanup
- Removal: Deleted by uninstall.sh if user confirms

**~/.config/sunshine/:**
- Purpose: Sunshine application configuration directory (per Sunshine spec)
- Generated: Yes - created by configure_sunshine() and install_sunshine()
- Committed: No - user-specific runtime configs
- Contents: sunshine.conf (generated from template), sunshine_state.json (credentials/state)
- Ownership: User (not root)
- Removal: Deleted by uninstall.sh

**~/.config/systemd/user/:**
- Purpose: User-level systemd service files
- Generated: Yes - sunshine.service, sunshine.service.d/override.conf
- Committed: No - user-specific systemd configuration
- Contents: sunshine.service (base unit), override.conf (X session environment)
- Daemon-reload: Required after modifications
- Removal: Uninstall.sh deletes sunshine.service and sunshine.service.d/

**/etc/X11/:**
- Purpose: System-level X11 configuration
- Generated: Yes - xorg.conf, 4k120.edid
- Committed: No - system-specific runtime configuration
- Requires: sudo access (non-user permission)
- Backup: Original files backed up before modification
- Impact: X11 restart required for changes to take effect

**/etc/udev/rules.d/:**
- Purpose: System-level udev device rules
- Generated: Yes - 85-sunshine.rules for uinput access
- Committed: No - system-specific runtime rules
- Requires: sudo access
- Reload: udevadm control --reload-rules && udevadm trigger
- Removal: Uninstall.sh deletes 85-sunshine.rules

**/etc/default/:**
- Purpose: System-level environment file for services
- Generated: Yes - tailscale-autoconnect (if Tailscale installed)
- Committed: No - user-editable runtime configuration
- Format: Shell variable assignments (TS_UP_EXTRA_ARGS="...")
- Requires: sudo access
- Note: Optional file; script can edit if Tailscale autoconnect installed

**/etc/systemd/system/:**
- Purpose: System-level systemd service files (vs. user-level in ~/.config)
- Generated: Yes - tailscale-autoconnect.service (if Tailscale autoconnect chosen)
- Committed: No - system-specific runtime configuration
- Requires: sudo access
- Type: oneshot service for boot-time automation
- Note: Optional installation; separate from user-level Sunshine service

---

*Structure analysis: 2026-02-04*
