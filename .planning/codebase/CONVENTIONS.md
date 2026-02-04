# Coding Conventions

**Analysis Date:** 2026-02-04

## Naming Patterns

**Files:**
- Scripts use `.sh` extension
- Template files use `.template` suffix (e.g., `xorg.conf.template`, `sunshine.conf.template`)
- Configuration files without `.template` are final configs (e.g., `sunshine-override.conf`)
- Installer script: `install.sh` (main entry point)
- Post-install helper: `after-install.sh` (verification and troubleshooting)
- Uninstaller: `uninstall.sh` (cleanup and removal)

**Functions:**
- Use `snake_case` for function names
- Semantic naming tied to responsibility: `check_prerequisites`, `install_sunshine`, `configure_x11`, `validate_installation`
- Helper/utility functions: `log_info`, `log_success`, `log_error`, `log_warning`, `log_step`, `log_substep`, `log_complete`
- Action functions: `confirm`, `prompt_user`, `prompt_secret`

**Variables:**
- Global constants use `UPPERCASE_SNAKE_CASE` and declared `readonly`
- Local variables use `lowercase_snake_case`
- Configuration paths stored in constants: `SCRIPT_DIR`, `EDID_DIR`, `TEMPLATES_DIR`, `BACKUP_DIR`, `SUNSHINE_CONFIG_DIR`, `SYSTEMD_USER_DIR`
- User selections stored with descriptive names: `RESOLUTION`, `REFRESH_RATE`, `CODEC`, `BITRATE`, `EDID_SOURCE`, `CUSTOM_EDID_PATH`

**Types:**
- No type system (bash scripting)
- String manipulation for numeric values (e.g., `BITRATE=$((input * 1000))` to convert Mbps to Kbps)

## Code Style

**Formatting:**
- 4-space indentation (not tabs)
- Line length: generally 80-100 characters (readable in terminals)
- Comment blocks use `=` separator lines for section headers

**Shell Options:**
- `set -e` in main installer (exit on error)
- NO `set -e` in `after-install.sh` (intentional to continue diagnostics on failure)
- Bash-specific features used (`[[...]]` instead of `[...]`, `$()` instead of backticks)

**Command Execution:**
- Redirect stderr: `command &> /dev/null` (suppress both stdout and stderr)
- Conditional execution: `if command -v sunshine &> /dev/null` (test if command exists)
- Suppress only stdout: `command > /dev/null` (keep stderr visible)
- Pipe to stderr only: `echo "message" >&2`

## Import Organization

**Source Location:**
- Templates sourced from `templates/` directory using variable substitution
- External files sourced with absolute paths derived from `SCRIPT_DIR`
- No explicit source command used; files are copied and modified

**Template Substitution Pattern:**
```bash
sed -e "s|{{PLACEHOLDER}}|${VARIABLE}|g" \
    -e "s|{{ANOTHER}}|${OTHER_VAR}|g" \
    "${TEMPLATES_DIR}/template.name" > "${OUTPUT_FILE}"
```

**Path Handling:**
- Use absolute paths throughout (e.g., `/etc/X11/xorg.conf`)
- Home directory accessed via `${HOME}` variable
- Current user accessed via `$(whoami)` when needed

## Error Handling

**Patterns:**
- Early exit on critical errors using `exit 1`
- Counter for error accumulation: `((errors++))` to track multiple issues
- Conditional continuation: `|| true` for non-critical failures
- Validation before operation: Check file existence with `[[ -f "${file}" ]]` or `[[ -d "${dir}" ]]`
- Fallback logic: Try primary method, then fallback: `if [[ -z "${value}" ]]; then use_fallback`

**Error Messages:**
- Use `log_error()` for recoverable issues, include guidance
- Use exit with error code for non-recoverable issues
- Always suggest next steps in error messages

## Logging

**Framework:** Console output using ANSI color codes (no external logger)

**Color Constants:**
- `NVIDIA_GREEN='\033[38;5;112m'` - Primary brand color
- `BRIGHT_GREEN='\033[1;32m'` - Success indication
- `RED='\033[1;31m'` - Errors
- `YELLOW='\033[1;33m'` - Warnings
- `BLUE='\033[1;34m'` - Section headers
- `GRAY='\033[0;37m'` - Supplementary text
- `RESET='\033[0m'` - Always end with RESET

**Patterns:**

Log levels in `install.sh`:
- `log_info "message"` - Primary action info (▶ prefix, green)
- `log_success "message"` - Completed steps (✓ prefix, bright green)
- `log_error "message"` - Errors (✗ prefix, red, redirects to stderr with `>&2`)
- `log_warning "message"` - Non-blocking issues (⚠ prefix, yellow)
- `log_step "title"` - Major section header (blue border, ┌─ prefix)
- `log_substep "message"` - Steps within section (│ connector)
- `log_complete` - End of section (└─ Complete)

Log levels in `after-install.sh`:
- `log_section "title"` - Major section header (blue separator lines)
- Same utility functions as `install.sh`

**When to Log:**
- Before major operations: `log_step "Installing Sunshine"`
- Before each sub-operation: `log_substep "Downloading..."`
- After successful completion: `log_success "Installed"`
- When skipping or detecting existing state: `log_warning "Already installed"`
- Include recovery/next-step guidance in every log message

**Log Examples from Codebase:**
```bash
# From install.sh line 66-67
log_info() {
    echo -e "${NVIDIA_GREEN}▶${RESET} $1"
}

# From install.sh line 369-372
if [[ -f "/etc/X11/xorg.conf" ]]; then
    log_substep "Backing up /etc/X11/xorg.conf..."
    sudo cp /etc/X11/xorg.conf "${BACKUP_DIR}/xorg.conf"
    log_success "xorg.conf backed up"
fi
```

## Comments

**When to Comment:**
- Section headers use ASCII art + descriptive comment lines (every major function gets one)
- Complex logic (hex-to-decimal conversion, EDID detection) gets inline comments
- Regular code is self-documenting via function/variable names (comments are rare)

**Section Header Pattern:**
```bash
# ============================================================================
# Function Purpose Description
# ============================================================================
function_name() {
    ...
}
```

**Inline Comments:**
Sparse; only for non-obvious logic:
```bash
# Prefer fully-qualified domain:bus:device.function (via -D) and match both
# "VGA compatible controller" and "3D controller" classes.
bus_id=$(lspci -D | grep -Ei "NVIDIA" | grep -Ei "VGA compatible controller|3D controller" | awk '{print $1}' | head -n 1)
```

**No JSDoc/TSDoc** (bash scripting)

## Function Design

**Size:** Functions typically 5-30 lines; larger functions break into logical sub-steps with logging

**Parameters:**
- Positional parameters (e.g., `$1`) for command-line args
- Global variables for state (e.g., `RESOLUTION`, `CODEC`)
- Local variables declared with `local` keyword
- Complex data passed via multiple parameters or sourced from templates

**Return Values:**
- Exit code 0 for success, non-zero for failure
- Functions don't return strings; they log output or modify global variables
- Use `return 1` for failures in non-fatal functions (e.g., checks)
- Use `exit 1` for fatal errors in main flow

**Function Structure Pattern:**
```bash
function_name() {
    log_step "Step Title"

    log_substep "Sub-action..."
    # perform operation
    log_success "Result"

    log_complete
}
```

## Module Design

**Exports:** No module system; entire script included with `source` or direct execution

**Barrel Files:** Not applicable (bash scripting)

**File Organization:**
- `install.sh`: Linear flow - prerequisites → configuration → installation → validation → final instructions
- `after-install.sh`: Interactive menu-driven + command-line args for direct execution
- `uninstall.sh`: Safety guards → stop service → remove package → remove configs → cleanup

**Main Pattern:**
```bash
# Entry Point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```
This allows sourcing the script without auto-execution.

## Conditional Logic

**Pattern:**
- Use `[[ ]]` (bash-specific, more robust) instead of `[ ]` (POSIX)
- String tests: `[[ -z "${var}" ]]` (empty), `[[ -n "${var}" ]]` (non-empty)
- File tests: `[[ -f "${file}" ]]` (file), `[[ -d "${dir}" ]]` (directory)
- Command tests: `command -v name &> /dev/null` (command exists)
- Service status: `systemctl --user is-active service` or `is-enabled service`

**Numeric Comparisons:**
- Use `(( ))` for arithmetic: `(( errors++ ))`, `[[ $input -ge 20 ]] && [[ $input -le 300 ]]`

## Systemd Integration

**Service Files:**
- Location: `~/.config/systemd/user/` (user-scope services)
- Type: `simple` (service runs in foreground)
- Restart: `on-failure` (restart if exit code indicates failure)
- Wants/After: Link to graphical-session for display-dependent services
- Override mechanism: `.service.d/override.conf` for environment customization

**Commands:**
- User services: `systemctl --user start/stop/restart/enable/disable sunshine`
- Daemon reload: `systemctl --user daemon-reload` after modifying service files
- Check status: `systemctl --user is-active service` (exit code 0/1)
- View logs: `journalctl --user -u service -f` (follow)

## User Interaction

**Confirmation Pattern:**
```bash
confirm() {
    local prompt="$1"
    local response
    echo -ne "${YELLOW}?${RESET} ${prompt} ${DIM}[y/N]${RESET}: "
    read -r response
    [[ "${response}" =~ ^[Yy]$ ]]
}

# Usage
if confirm "Proceed with installation?"; then
    # perform action
fi
```

**User Input Pattern:**
```bash
prompt_user() {
    local prompt="$1"
    local var_name="$2"
    echo -ne "${NVIDIA_GREEN}?${RESET} ${prompt}: "
    read -r "${var_name}"
}

# Usage
prompt_user "Select resolution (1-5)" choice
```

**Secret Input Pattern (masked password):**
```bash
prompt_secret() {
    local prompt="$1"
    local var_name="$2"
    echo -ne "${NVIDIA_GREEN}?${RESET} ${prompt}: "
    read -rs "$var_name"
    echo ""
}
```

## Hardware Detection

**NVIDIA GPU Detection:**
- Primary: `nvidia-smi -L` pipe to grep for "GB10"
- BusID detection: `lspci -D | grep -Ei "NVIDIA|VGA compatible controller" | awk '{print $1}'`
- Format conversion: Domain:Bus:Device.Function → PCI:Bus:Device:Function
- Hex-to-decimal: `$((16#${hex_value}})`

---

*Convention analysis: 2026-02-04*
