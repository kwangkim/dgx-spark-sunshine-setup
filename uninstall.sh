#!/bin/bash
# ============================================================================
# NVIDIA DGX Spark Sunshine Streaming Setup Uninstaller
# ============================================================================
# Completely removes Sunshine, Tailscale, and all related configurations
# ============================================================================

set -eo pipefail  # Exit on error, catch pipeline failures

# ============================================================================
# Colors and Formatting (NVIDIA Green Theme)
# ============================================================================
readonly NVIDIA_GREEN='\033[38;5;112m'
readonly BRIGHT_GREEN='\033[1;32m'
readonly WHITE='\033[1;37m'
readonly GRAY='\033[0;37m'
readonly RED='\033[1;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[1;34m'
readonly RESET='\033[0m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'

# ============================================================================
# Utility Functions
# ============================================================================
log_info() {
    echo -e "${NVIDIA_GREEN}▶${RESET} $1"
}

log_success() {
    echo -e "${BRIGHT_GREEN}✓${RESET} $1"
}

log_error() {
    echo -e "${RED}✗${RESET} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠${RESET} $1"
}

log_step() {
    echo ""
    echo -e "${BLUE}${BOLD}┌─ $1${RESET}"
}

log_substep() {
    echo -e "${GRAY}│${RESET}  $1"
}

log_complete() {
    echo -e "${BLUE}${BOLD}└─${RESET} ${BRIGHT_GREEN}Complete${RESET}"
}

# ============================================================================
# Safety Guard
# ============================================================================
if [[ "${EUID}" -eq 0 ]]; then
    log_error "Do not run this uninstaller with sudo/as root. It uses \$HOME and systemctl --user, which would target the root user and remove the wrong files/services."
    log_info "Run it as the intended desktop user (no sudo). If you need privileges for package removal, the script will prompt via sudo when required."
    log_info "If you must run under sudo, use: sudo -u <user> ./uninstall.sh"
    exit 1
fi

# ============================================================================
# Configuration
# ============================================================================
readonly SUNSHINE_CONFIG_DIR="${HOME}/.config/sunshine"
readonly SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"

confirm() {
    local prompt="$1"
    local response
    echo -ne "${YELLOW}?${RESET} ${prompt} ${DIM}[y/N]${RESET}: "
    read -r response
    [[ "${response}" =~ ^[Yy]$ ]]
}

# ============================================================================
# Print Header
# ============================================================================
print_header() {
    echo ""
    echo -e "${RED}${BOLD}"
    echo "  ╔═══════════════════════════════════════════════════════════════╗"
    echo "  ║                 SUNSHINE UNINSTALLER                          ║"
    echo "  ║           DGX Spark Streaming Setup Removal                   ║"
    echo "  ╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo -e "${YELLOW}This will completely remove Sunshine and all related configurations.${RESET}"
    echo ""
}

# ============================================================================
# Stop Sunshine Service
# ============================================================================
stop_sunshine_service() {
    log_step "Stopping Sunshine Service"

    if systemctl --user is-active sunshine &>/dev/null; then
        log_substep "Stopping sunshine service..."
        systemctl --user stop sunshine
        log_success "Sunshine service stopped"
    else
        log_substep "Sunshine service is not running"
    fi

    if systemctl --user is-enabled sunshine &>/dev/null; then
        log_substep "Disabling sunshine service..."
        systemctl --user disable sunshine
        log_success "Sunshine service disabled"
    else
        log_substep "Sunshine service is not enabled"
    fi

    log_complete
}

# ============================================================================
# Remove Sunshine Package
# ============================================================================
remove_sunshine_package() {
    log_step "Removing Sunshine Package"

    if dpkg -l sunshine 2>/dev/null | grep -q "^[ih]i\|^[rR]c"; then
        log_substep "Removing sunshine package..."
        sudo apt-get remove --purge -y sunshine
        log_success "Sunshine package removed"
    else
        log_warning "Sunshine package not found"
    fi

    # Clean up any leftover dependencies
    log_substep "Cleaning up unused dependencies..."
    sudo apt-get autoremove -y
    log_success "Dependencies cleaned"

    log_complete
}

# ============================================================================
# Remove Configuration Files
# ============================================================================
remove_configurations() {
    log_step "Removing Configuration Files"

    # Remove Sunshine config directory
    if [[ -d "${SUNSHINE_CONFIG_DIR}" ]]; then
        log_substep "Removing ${SUNSHINE_CONFIG_DIR}..."
        rm -rf "${SUNSHINE_CONFIG_DIR}"
        log_success "Sunshine config directory removed"
    else
        log_substep "Sunshine config directory not found"
    fi

    # Remove systemd service files
    if [[ -f "${SYSTEMD_USER_DIR}/sunshine.service" ]]; then
        log_substep "Removing sunshine.service..."
        rm -f "${SYSTEMD_USER_DIR}/sunshine.service"
        log_success "User sunshine.service removed"
    fi

    if [[ -d "${SYSTEMD_USER_DIR}/sunshine.service.d" ]]; then
        log_substep "Removing sunshine.service.d override directory..."
        rm -rf "${SYSTEMD_USER_DIR}/sunshine.service.d"
        log_success "Systemd override directory removed"
    fi

    # Reload systemd
    log_substep "Reloading systemd daemon..."
    if ! systemctl --user daemon-reload; then
        log_warning "systemd daemon-reload failed — may need to log out and back in"
    fi
    log_success "Systemd reloaded"

    log_complete
}

# ============================================================================
# Remove X11 Configuration
# ============================================================================
remove_x11_config() {
    log_step "Removing X11 Configuration"

    # Remove xorg.conf (validate it was created by our installer)
    if [[ -f "/etc/X11/xorg.conf" ]]; then
        # Verify this xorg.conf was created by our installer before removing
        if grep -q "DGX Spark Sunshine Setup Installer" /etc/X11/xorg.conf 2>/dev/null; then
            log_substep "Removing /etc/X11/xorg.conf (created by installer)..."
            sudo rm -f /etc/X11/xorg.conf
            log_success "xorg.conf removed"
            log_warning "X11 will use default auto-configuration after restart"
        else
            log_warning "xorg.conf exists but was NOT created by this installer — skipping removal"
            log_substep "To remove manually: ${DIM}sudo rm /etc/X11/xorg.conf${RESET}"
        fi
    else
        log_substep "xorg.conf not found"
    fi

    # Remove EDID file
    if [[ -f "/etc/X11/4k120.edid" ]]; then
        log_substep "Removing /etc/X11/4k120.edid..."
        sudo rm -f /etc/X11/4k120.edid
        log_success "EDID file removed"
    else
        log_substep "EDID file not found"
    fi

    log_complete
}

# ============================================================================
# Remove udev Rules
# ============================================================================
remove_udev_rules() {
    log_step "Removing udev Rules"

    if [[ -f "/etc/udev/rules.d/85-sunshine.rules" ]]; then
        log_substep "Removing /etc/udev/rules.d/85-sunshine.rules..."
        sudo rm -f /etc/udev/rules.d/85-sunshine.rules
        sudo udevadm control --reload-rules
        sudo udevadm trigger
        log_success "Sunshine udev rules removed"
    else
        log_substep "Sunshine udev rules not found"
    fi

    log_complete
}

# ============================================================================
# Optional: Remove User from Groups
# ============================================================================
remove_user_groups() {
    log_step "User Group Cleanup"

    echo ""
    echo -e "${YELLOW}The installer added your user to 'video' and 'input' groups.${RESET}"
    echo -e "${GRAY}These groups are commonly used by other applications too.${RESET}"
    echo ""
    echo -e "${YELLOW}Warning: Other apps may use these groups:${RESET}"
    echo -e "${GRAY}  • video: GPU access (CUDA, Docker GPU passthrough)${RESET}"
    echo -e "${GRAY}  • input: Gamepads, input devices${RESET}"
    echo -e "${GRAY}If unsure, keep them — they are harmless.${RESET}"
    echo ""

    if confirm "Remove user from 'video' and 'input' groups?"; then
        log_substep "Removing user from groups..."
        sudo deluser "${USER}" video 2>/dev/null || true
        sudo deluser "${USER}" input 2>/dev/null || true
        log_success "User removed from groups"
        log_warning "Changes will take effect after logout/reboot"
    else
        log_info "Keeping user in video and input groups"
    fi

    log_complete
}

# ============================================================================
# Restore Backed-Up Files
# ============================================================================
restore_backups() {
    log_step "Backup Restoration"

    # Find the most recent backup directory
    local backup_base="${HOME}/.sunshine-setup-backups"
    if [[ ! -d "${backup_base}" ]]; then
        log_substep "No backup directory found"
        log_complete
        return
    fi

    # Find the latest backup
    local latest_backup
    latest_backup=$(ls -dt "${backup_base}"/backup-* 2>/dev/null | head -1 || true)
    # Handle old format without backup- prefix
    if [[ -z "${latest_backup}" ]]; then
        latest_backup=$(ls -dt "${backup_base}"/*/ 2>/dev/null | head -1 || true)
    fi

    if [[ -z "${latest_backup}" || ! -d "${latest_backup}" ]]; then
        log_substep "No backups found in ${backup_base}"
        log_complete
        return
    fi

    log_substep "Found backup: ${latest_backup}"

    # Offer to restore xorg.conf
    if [[ -f "${latest_backup}/xorg.conf" ]]; then
        if confirm "Restore original xorg.conf from backup?"; then
            sudo cp "${latest_backup}/xorg.conf" /etc/X11/xorg.conf
            sudo chmod 644 /etc/X11/xorg.conf
            log_success "xorg.conf restored from backup"
        else
            log_info "Skipping xorg.conf restoration"
        fi
    fi

    # Offer to restore EDID files
    shopt -s nullglob
    local edid_files=("${latest_backup}"/*.edid)
    if [[ ${#edid_files[@]} -gt 0 ]]; then
        if confirm "Restore backed-up EDID files?"; then
            sudo cp "${edid_files[@]}" /etc/X11/
            log_success "EDID files restored from backup"
        else
            log_info "Skipping EDID restoration"
        fi
    fi
    shopt -u nullglob

    log_complete
}

# ============================================================================
# Optional: Remove Tailscale
# ============================================================================
remove_tailscale() {
    log_step "Optional: Tailscale Removal"

    if ! command -v tailscale &> /dev/null && ! dpkg -l tailscale 2>/dev/null | grep -q "^[ih]i"; then
        log_substep "Tailscale is not installed — skipping"
        log_complete
        return
    fi

    echo ""
    echo -e "${YELLOW}Tailscale was optionally installed for remote access.${RESET}"
    echo -e "${GRAY}You may want to keep it if you use it for other purposes.${RESET}"
    echo ""

    if ! confirm "Remove Tailscale?"; then
        log_info "Keeping Tailscale"
        log_complete
        return
    fi

    # Stop and disable the autoconnect service if present
    if systemctl is-active tailscale-autoconnect &>/dev/null || systemctl is-enabled tailscale-autoconnect &>/dev/null; then
        log_substep "Stopping tailscale-autoconnect service..."
        sudo systemctl disable --now tailscale-autoconnect 2>/dev/null || true
        log_success "tailscale-autoconnect service stopped and disabled"
    fi

    # Remove the autoconnect service and env files
    if [[ -f "/etc/systemd/system/tailscale-autoconnect.service" ]]; then
        log_substep "Removing tailscale-autoconnect service file..."
        sudo rm -f /etc/systemd/system/tailscale-autoconnect.service
        log_success "tailscale-autoconnect service file removed"
    fi
    if [[ -f "/etc/default/tailscale-autoconnect" ]]; then
        log_substep "Removing tailscale-autoconnect config..."
        sudo rm -f /etc/default/tailscale-autoconnect
        log_success "tailscale-autoconnect config removed"
    fi

    # Disconnect from tailnet before removing
    if command -v tailscale &> /dev/null; then
        log_substep "Disconnecting from Tailscale network..."
        sudo tailscale down 2>/dev/null || true
    fi

    # Stop tailscaled
    if systemctl is-active tailscaled &>/dev/null; then
        log_substep "Stopping tailscaled service..."
        sudo systemctl disable --now tailscaled 2>/dev/null || true
        log_success "tailscaled stopped and disabled"
    fi

    # Remove the package
    log_substep "Removing tailscale package..."
    if sudo apt-get remove --purge -y tailscale 2>/dev/null; then
        log_success "Tailscale package removed"
    else
        log_warning "Could not remove tailscale package via apt"
    fi

    # Remove the apt repository and signing key added by the installer
    if [[ -f "/etc/apt/sources.list.d/tailscale.list" ]]; then
        log_substep "Removing Tailscale apt repository..."
        sudo rm -f /etc/apt/sources.list.d/tailscale.list
        log_success "Tailscale apt source removed"
    fi
    if [[ -f "/usr/share/keyrings/tailscale-archive-keyring.gpg" ]]; then
        log_substep "Removing Tailscale signing key..."
        sudo rm -f /usr/share/keyrings/tailscale-archive-keyring.gpg
        log_success "Tailscale signing key removed"
    fi

    sudo systemctl daemon-reload 2>/dev/null || true

    log_complete
}

# ============================================================================
# Print Final Message
# ============================================================================
print_final_message() {
    echo ""
    echo -e "${NVIDIA_GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}${BOLD}Uninstallation Complete!${RESET}"
    echo -e "${NVIDIA_GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "${WHITE}${BOLD}What was removed:${RESET}"
    echo -e "${GRAY}  ✓${RESET} Sunshine package"
    echo -e "${GRAY}  ✓${RESET} Sunshine configuration (~/.config/sunshine)"
    echo -e "${GRAY}  ✓${RESET} Systemd user service files"
    echo -e "${GRAY}  ✓${RESET} X11 xorg.conf (virtual display config)"
    echo -e "${GRAY}  ✓${RESET} Custom EDID file"
    echo -e "${GRAY}  ✓${RESET} Sunshine udev rules"
    echo -e "${GRAY}  ✓${RESET} Tailscale (if selected)"
    echo ""
    echo -e "${YELLOW}${BOLD}Recommended:${RESET}"
    echo -e "${GRAY}  •${RESET} Restart your system: ${DIM}sudo reboot${RESET}"
    echo ""
    echo -e "${NVIDIA_GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
}

# ============================================================================
# Main Uninstall Flow
# ============================================================================
main() {
    print_header

    if ! confirm "Are you sure you want to completely uninstall Sunshine?"; then
        log_warning "Uninstallation cancelled"
        exit 0
    fi

    echo ""

    stop_sunshine_service
    remove_sunshine_package
    remove_configurations
    remove_x11_config
    restore_backups
    remove_udev_rules
    remove_user_groups
    remove_tailscale

    print_final_message
}

# ============================================================================
# Entry Point
# ============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
