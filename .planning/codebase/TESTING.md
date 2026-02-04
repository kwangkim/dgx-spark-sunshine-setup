# Testing Patterns

**Analysis Date:** 2026-02-04

## Test Framework

**Runner:** Not detected

**Assertion Library:** Not detected

**Test Infrastructure:** Not applicable

This codebase uses **manual testing and verification scripts** rather than automated unit test frameworks. The project focuses on shell script verification through:
1. Interactive validation during installation (`install.sh`)
2. Post-installation diagnostics (`after-install.sh`)
3. Manual system checks (xrandr, nvidia-smi, systemctl status)

**Run Commands:**

```bash
./install.sh              # Main installation with interactive checks
./after-install.sh        # Post-reboot verification and diagnostics
./after-install.sh --check-all     # Run all checks non-interactively
./uninstall.sh            # Complete removal with validation
```

## Test File Organization

**Location:** No dedicated test directory

**Structure:**
- Tests embedded in scripts: `install.sh`, `after-install.sh`, `uninstall.sh`
- Verification logic collocated with functionality
- Diagnostic functions in `after-install.sh` (lines 70-366)

**Naming:** Test functions prefixed with `check_*` or `test_*`
- `check_prerequisites()` - Prerequisites validation
- `check_virtual_display()` - Display configuration verification
- `check_sunshine_service()` - Service status checks
- `check_gpu_encoding()` - Hardware encoder capability test
- `check_network_access()` - Connectivity verification
- `validate_installation()` - Post-install validation
- `test_encoding()` - NVENC hardware encoder test

## Test Structure

**Verification Pattern from `install.sh`:**
```bash
# Prerequisite checks (lines 121-182)
check_prerequisites() {
    log_step "Checking Prerequisites"

    local errors=0

    # Check for NVIDIA driver
    log_substep "Checking NVIDIA driver..."
    if ! command -v nvidia-smi &> /dev/null; then
        log_error "NVIDIA driver not found (nvidia-smi missing)"
        ((errors++))
    else
        log_success "NVIDIA driver found: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader)"
    fi

    # ... more checks ...

    if [[ ${errors} -gt 0 ]]; then
        log_error "Prerequisites check failed with ${errors} error(s)"
        exit 1
    fi

    log_complete
}
```

**Patterns:**
- Counter accumulation: `((errors++))` tracks multiple failures
- Test continues on failure (non-fatal checks)
- Exit only if errors exceed threshold
- Each check independent (can run separately)
- Logging provides immediate feedback on pass/fail

**Post-Install Validation Pattern from `install.sh` (lines 762-825):**
```bash
validate_installation() {
    log_step "Validating Installation"

    local errors=0

    # Check Sunshine binary
    log_substep "Checking Sunshine installation..."
    if command -v sunshine &> /dev/null; then
        log_success "Sunshine binary found"
    else
        log_error "Sunshine binary not found"
        ((errors++))
    fi

    # Check xorg.conf
    log_substep "Checking xorg.conf..."
    if [[ -f "/etc/X11/xorg.conf" ]]; then
        log_success "xorg.conf exists"
        if grep -q "CustomEDID" /etc/X11/xorg.conf; then
            log_success "CustomEDID option found"
        else
            log_error "CustomEDID option not found in xorg.conf"
            ((errors++))
        fi
    else
        log_error "xorg.conf not found"
        ((errors++))
    fi

    if [[ ${errors} -gt 0 ]]; then
        log_warning "Validation completed with ${errors} error(s)"
    else
        log_success "All validation checks passed"
    fi

    log_complete
}
```

## Mocking

**Framework:** Not applicable

**Strategy:** Direct system interaction (no mocking)
- Real command execution: `command -v`, `nvidia-smi`, `systemctl`
- Real file operations: `cp`, `rm`, `mkdir`
- Real network checks: `curl -k https://localhost:47990`

**Conditional Execution:**
Tests check for command availability before running:
```bash
if ! command -v nvidia-smi &> /dev/null; then
    log_error "nvidia-smi not found"
    return 1
fi
```

## Fixtures and Factories

**Test Data:** EDID binary files in `edid/` directory
- `edid/samsung-q800t.bin` - Default EDID for virtual display
- Used directly in installation without modification

**Configuration Templates:** Fixed template files in `templates/`
- `xorg.conf.template` - X11 config template
- `sunshine.conf.template` - Sunshine config template
- Templates substituted at installation time with actual values

**Test Pattern from `after-install.sh`:**
```bash
test_encoding() {
    log_section "Test Hardware Encoding"
    echo ""

    if ! command -v ffmpeg &> /dev/null; then
        log_error "ffmpeg not found - cannot test encoding"
        return 1
    fi

    log_info "Testing NVENC HEVC encoding (10 seconds)..."
    echo ""

    # Create a test pattern and encode with NVENC
    if ffmpeg -f lavfi -i testsrc=duration=10:size=1920x1080:rate=30 \
        -c:v hevc_nvenc -preset p7 -b:v 10M \
        -f null - 2>&1 | grep -q "frame="; then
        log_success "NVENC encoding test passed"
        log_info "Hardware encoding is working correctly"
    else
        log_error "NVENC encoding test failed"
        log_info "Check NVIDIA driver installation"
    fi
}
```

## Coverage

**Requirements:** No coverage enforced

**Approach:** Manual verification of critical paths
- Prerequisite checks cover required dependencies
- Installation validation checks key artifacts exist
- Post-install helper provides diagnostic coverage
- SSH fallbacks for headless scenarios

**Test Types Implemented:**

### Unit-like Checks (Isolated System State)
Located in `install.sh` (lines 121-182):
- Hardware platform detection
- NVIDIA driver presence
- X11 availability
- systemd presence
- Required command availability (curl, sed, lspci)

Located in `install.sh` (lines 762-825):
- Sunshine binary installation
- xorg.conf file creation
- CustomEDID option presence
- EDID file placement
- Sunshine configuration file
- systemd override file

### Integration Tests (System Interaction)
Located in `after-install.sh` (lines 70-123):
```bash
check_virtual_display() {
    # Test actual xrandr output
    local xrandr_output
    xrandr_output=$(xrandr 2>&1)

    # Handle SSH without X11 access
    if echo "$xrandr_output" | grep -q "Can't open display"; then
        # Fallback to X11 logs
        if [[ -f /var/log/Xorg.0.log ]]; then
            display_info=$(sudo grep -i "DFP-0.*connected\|Mode.*x.*Hz" /var/log/Xorg.0.log 2>/dev/null | tail -3)
        fi
    fi
}
```

Located in `after-install.sh` (lines 125-163):
- Sunshine service enabled status
- Session lingering configuration
- Service active status
- Web interface accessibility (curl to https://localhost:47990)

Located in `after-install.sh` (lines 165-197):
- GPU name detection via nvidia-smi
- Active encoding sessions
- GPU utilization percentage
- GPU memory usage

Located in `after-install.sh` (lines 199-233):
- Local IP detection
- Tailscale IP detection
- Firewall status (ufw)

### End-to-End Tests (Full System)
Located in `after-install.sh` (lines 344-366):
```bash
test_encoding() {
    # Real hardware encoding test with ffmpeg
    ffmpeg -f lavfi -i testsrc=duration=10:size=1920x1080:rate=30 \
        -c:v hevc_nvenc -preset p7 -b:v 10M \
        -f null - 2>&1 | grep -q "frame="
}
```

Full uninstallation test pattern in `uninstall.sh` (lines 98-223):
- Service stop verification
- Package removal verification
- Configuration directory removal
- X11 config cleanup
- EDID file removal
- udev rules cleanup

## Interactive Testing Pattern

**Menu-Driven Diagnostics in `after-install.sh` (lines 371-489):**
```bash
show_menu() {
    echo ""
    echo -e "${NVIDIA_GREEN}${BOLD}Available Actions:${RESET}"
    echo ""
    echo -e "${GRAY}  [1]${RESET} Run all checks (recommended)"
    echo -e "${GRAY}  [2]${RESET} Check virtual display"
    echo -e "${GRAY}  [3]${RESET} Check Sunshine service"
    # ... more options ...
    echo ""
}

main() {
    # If argument provided, run specific command
    if [[ $# -gt 0 ]]; then
        case "$1" in
            --check-all)
                run_all_checks
                exit 0
                ;;
            --check-display)
                check_virtual_display
                exit 0
                ;;
            # ... more options ...
        esac
    fi

    # Interactive mode
    print_header
    while true; do
        show_menu
        read -r choice
        case "$choice" in
            1) run_all_checks ;;
            2) check_virtual_display ;;
            # ... execute selected test ...
        esac
    done
}
```

**Non-Interactive Execution:**
```bash
./after-install.sh --check-all           # Run all checks
./after-install.sh --check-display       # Display check only
./after-install.sh --start               # Start Sunshine service
./after-install.sh --logs                # View recent logs
```

## Error Scenarios Tested

**Handled Scenarios:**

1. **Missing GPU** (lines 128-134 in `install.sh`):
   - GB10 not detected
   - User confirmation to continue anyway

2. **Missing Dependencies** (lines 138-174 in `install.sh`):
   - nvidia-smi not found
   - X11 not available
   - systemd not installed
   - Required commands missing

3. **File Not Found** (lines 465-468 in `install.sh`):
   - EDID file missing
   - xorg.conf missing

4. **Service Issues** (lines 148-162 in `after-install.sh`):
   - Service not enabled
   - Service not running
   - Web interface not responding

5. **X11 Issues** (lines 73-99 in `after-install.sh`):
   - SSH session without X11 access
   - xrandr not available
   - Fallback to X11 logs

6. **Hardware Encoding** (lines 348-365 in `after-install.sh`):
   - ffmpeg not found
   - NVENC not working
   - Encoder initialization failed

## Log Verification

**Log Locations:**
- Sunshine service logs: `journalctl --user -u sunshine -f` (real-time)
- X11 logs: `/var/log/Xorg.0.log` (EDID/display issues)
- Installer logs: stdout (colorized with log_* functions)

**Log Checking from `after-install.sh` (lines 235-259):**
```bash
view_sunshine_logs() {
    log_section "Sunshine Logs (Last 20 Lines)"
    echo ""
    if systemctl --user is-active sunshine &> /dev/null; then
        journalctl --user -u sunshine -n 20 --no-pager | sed "s/^/${GRAY}  /"
        echo -e "${RESET}"
        echo ""
        log_info "To follow live logs: ${DIM}journalctl --user -u sunshine -f${RESET}"
    else
        log_warning "Sunshine service is not running - no logs available"
    fi
}
```

## Critical Verification Points

**Before Installation (install.sh):**
1. Hardware compatibility (GB10 GPU)
2. NVIDIA driver installation
3. X11 desktop environment
4. systemd daemon
5. Required utilities (curl, sed, lspci)

**During Installation (install.sh):**
1. Backups created successfully
2. Sunshine package downloaded and installed
3. EDID file placement and validation
4. xorg.conf generated with correct BusID
5. Sunshine configuration file created
6. systemd service installed and reloaded
7. All files in correct locations

**After Installation (after-install.sh):**
1. Virtual display detected via xrandr
2. Sunshine service running
3. Web interface accessible on https://localhost:47990
4. GPU detected and utilization visible
5. NVENC encoding functional
6. Network accessibility (LAN IP, Tailscale if configured)
7. Firewall status checked

---

*Testing analysis: 2026-02-04*
