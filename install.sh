#!/bin/bash
# ============================================================================
# NVIDIA DGX Spark Sunshine Streaming Setup Installer
# ============================================================================
# Automated installer for Sunshine game streaming with virtual display
# on NVIDIA DGX Spark (GB10) systems
# ============================================================================

set -e  # Exit on error

# ============================================================================
# Colors and Formatting (NVIDIA Green Theme)
# ============================================================================
readonly NVIDIA_GREEN='\033[38;5;112m'  # NVIDIA signature green
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
# Configuration
# ============================================================================
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly EDID_DIR="${SCRIPT_DIR}/edid"
readonly TEMPLATES_DIR="${SCRIPT_DIR}/templates"
readonly BACKUP_DIR="${HOME}/.sunshine-setup-backups/$(date +%Y%m%d-%H%M%S)"

readonly SUNSHINE_RELEASE_URL="https://api.github.com/repos/LizardByte/Sunshine/releases/latest"
readonly SUNSHINE_CONFIG_DIR="${HOME}/.config/sunshine"
readonly SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"

# User selections (set via prompts)
RESOLUTION=""
REFRESH_RATE=""
CODEC=""
BITRATE=""
EDID_SOURCE=""
CUSTOM_EDID_PATH=""

# ============================================================================
# ASCII Logo and Header
# ============================================================================
print_logo() {
    echo ""
    echo -e "${NVIDIA_GREEN}${BOLD}"
    echo "  ██████╗  ██████╗ ██╗  ██╗    ███████╗██████╗  █████╗ ██████╗ ██╗  ██╗"
    echo "  ██╔══██╗██╔════╝ ╚██╗██╔╝    ██╔════╝██╔══██╗██╔══██╗██╔══██╗██║ ██╔╝"
    echo "  ██║  ██║██║  ███╗ ╚███╔╝     ███████╗██████╔╝███████║██████╔╝█████╔╝ "
    echo "  ██║  ██║██║   ██║ ██╔██╗     ╚════██║██╔═══╝ ██╔══██║██╔══██╗██╔═██╗ "
    echo "  ██████╔╝╚██████╔╝██╔╝ ██╗    ███████║██║     ██║  ██║██║  ██║██║  ██╗"
    echo "  ╚═════╝  ╚═════╝ ╚═╝  ╚═╝    ╚══════╝╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝"
    echo -e "${RESET}"
    echo -e "${GRAY}  Sunshine Streaming Setup${RESET}"
    echo -e "${DIM}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
}

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

prompt_user() {
    local prompt="$1"
    local var_name="$2"
    echo -ne "${NVIDIA_GREEN}?${RESET} ${prompt}: "
    read -r "${var_name}"
}

prompt_secret() {
    local prompt="$1"
    local var_name="$2"
    echo -ne "${NVIDIA_GREEN}?${RESET} ${prompt}: "
    read -rs "$var_name"
    echo ""
}

confirm() {
    local prompt="$1"
    local response
    echo -ne "${YELLOW}?${RESET} ${prompt} ${DIM}[y/N]${RESET}: "
    read -r response
    [[ "${response}" =~ ^[Yy]$ ]]
}

# ============================================================================
# Prerequisites Check
# ============================================================================
check_prerequisites() {
    log_step "Checking Prerequisites"

    local errors=0

    # Check if running on DGX Spark
    log_substep "Checking hardware platform..."
    if command -v nvidia-smi &> /dev/null && nvidia-smi -L 2>/dev/null | grep -q "GB10"; then
        log_success "GB10 GPU detected"
    else
        log_warning "GB10 GPU not detected - this script is designed for DGX Spark"
        if ! confirm "Continue anyway?"; then
            exit 1
        fi
    fi

    # Check for NVIDIA driver
    log_substep "Checking NVIDIA driver..."
    if ! command -v nvidia-smi &> /dev/null; then
        log_error "NVIDIA driver not found (nvidia-smi missing)"
        ((errors++))
    else
        log_success "NVIDIA driver found: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader)"
    fi

    # Check for X11
    log_substep "Checking X11..."
    if ! command -v Xorg &> /dev/null; then
        log_error "X11 not found - desktop environment required"
        ((errors++))
    else
        log_success "X11 found"
    fi

    # Check for systemd
    log_substep "Checking systemd..."
    if ! command -v systemctl &> /dev/null; then
        log_error "systemd not found"
        ((errors++))
    else
        log_success "systemd found"
    fi

    # Check for required commands
    local required_cmds=("curl" "sed" "lspci")
    for cmd in "${required_cmds[@]}"; do
        log_substep "Checking for ${cmd}..."
        if ! command -v "${cmd}" &> /dev/null; then
            log_error "${cmd} not found"
            ((errors++))
        else
            log_success "${cmd} found"
        fi
    done

    if [[ ${errors} -gt 0 ]]; then
        log_error "Prerequisites check failed with ${errors} error(s)"
        exit 1
    fi

    log_complete
}

# ============================================================================
# Interactive Configuration
# ============================================================================
configure_resolution() {
    log_step "Display Configuration"

    echo ""
    echo -e "${WHITE}${BOLD}Available Resolutions:${RESET}"
    echo -e "${GRAY}  1)${RESET} 3840x2160 @ 60Hz  ${DIM}(4K, lower refresh rate)${RESET}"
    echo -e "${GRAY}  2)${RESET} 3440x1440 @ 60Hz  ${DIM}(Dell AW3420DW Ultrawide 21:9)${RESET}"
    echo -e "${GRAY}  3)${RESET} 2732x2048 @ 60Hz  ${DIM}(iPad Pro 12.9 M2)${RESET}"
    echo -e "${GRAY}  4)${RESET} 2560x1440 @ 120Hz ${DIM}(1440p, higher refresh rate)${RESET} ${NVIDIA_GREEN}[Recommended]${RESET}"
    echo -e "${GRAY}  5)${RESET} 1920x1080 @ 120Hz ${DIM}(1080p, higher refresh rate)${RESET}"
    echo ""

    local choice
    while true; do
        prompt_user "Select resolution (1-5)" choice
        case "${choice}" in
            1)
                RESOLUTION="3840x2160"
                REFRESH_RATE="60"
                break
                ;;
            2)
                RESOLUTION="3440x1440"
                REFRESH_RATE="60"
                break
                ;;
            3)
                RESOLUTION="2732x2048"
                REFRESH_RATE="60"
                break
                ;;
            4)
                RESOLUTION="2560x1440"
                REFRESH_RATE="120"
                break
                ;;
            5)
                RESOLUTION="1920x1080"
                REFRESH_RATE="120"
                break
                ;;
            *)
                log_error "Invalid selection. Please choose 1-5."
                ;;
        esac
    done

    log_success "Selected: ${RESOLUTION} @ ${REFRESH_RATE}Hz"
    log_complete
}

configure_codec() {
    log_step "Video Codec Configuration"

    echo ""
    echo -e "${WHITE}${BOLD}Available Codecs:${RESET}"
    echo -e "${GRAY}  1)${RESET} HEVC (H.265) ${DIM}(Better compatibility)${RESET} ${NVIDIA_GREEN}[Recommended]${RESET}"
    echo -e "${GRAY}  2)${RESET} AV1         ${DIM}(Better compression, newer clients)${RESET}"
    echo -e "${GRAY}  3)${RESET} H.264       ${DIM}(Maximum compatibility)${RESET}"
    echo ""

    local choice
    while true; do
        prompt_user "Select codec (1-3)" choice
        case "${choice}" in
            1)
                CODEC="hevc"
                break
                ;;
            2)
                CODEC="av1"
                break
                ;;
            3)
                CODEC="h264"
                break
                ;;
            *)
                log_error "Invalid selection. Please choose 1-3."
                ;;
        esac
    done

    log_success "Selected: ${CODEC}"
    log_complete
}

configure_bitrate() {
    log_step "Bitrate Configuration"

    echo ""
    echo -e "${WHITE}${BOLD}Recommended Bitrates:${RESET}"
    echo -e "${GRAY}  •${RESET} LAN (Gigabit):  ${DIM}100-200 Mbps${RESET}"
    echo -e "${GRAY}  •${RESET} LAN (Wi-Fi):    ${DIM}50-100 Mbps${RESET}"
    echo -e "${GRAY}  •${RESET} Remote (VPN):   ${DIM}20-50 Mbps${RESET}"
    echo ""

    local input
    while true; do
        prompt_user "Enter bitrate in Mbps [50-200]" input
        if [[ "${input}" =~ ^[0-9]+$ ]] && [ "${input}" -ge 20 ] && [ "${input}" -le 300 ]; then
            BITRATE=$((input * 1000))  # Convert to Kbps
            break
        else
            log_error "Invalid bitrate. Please enter a number between 20 and 300."
        fi
    done

    log_success "Selected: ${input} Mbps"
    log_complete
}

configure_edid() {
    log_step "EDID Configuration"

    echo ""
    echo -e "${WHITE}${BOLD}EDID Options:${RESET}"
    echo -e "${GRAY}  1)${RESET} Use bundled Samsung Q800T EDID ${DIM}(4K@60Hz, 1440p@120Hz)${RESET} ${NVIDIA_GREEN}[Recommended]${RESET}"
    echo -e "${GRAY}  2)${RESET} Provide custom EDID file path"
    echo ""

    local choice
    while true; do
        prompt_user "Select EDID source (1-2)" choice
        case "${choice}" in
            1)
                EDID_SOURCE="bundled"
                break
                ;;
            2)
                EDID_SOURCE="custom"
                while true; do
                    prompt_user "Enter path to custom EDID .bin file" CUSTOM_EDID_PATH
                    if [[ -f "${CUSTOM_EDID_PATH}" ]]; then
                        log_success "Custom EDID file found"
                        break
                    else
                        log_error "File not found: ${CUSTOM_EDID_PATH}"
                    fi
                done
                break
                ;;
            *)
                log_error "Invalid selection. Please choose 1-2."
                ;;
        esac
    done

    log_complete
}

print_configuration_summary() {
    echo ""
    echo -e "${NVIDIA_GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}${BOLD}Configuration Summary${RESET}"
    echo -e "${NVIDIA_GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${GRAY}  Resolution:${RESET}  ${RESOLUTION} @ ${REFRESH_RATE}Hz"
    echo -e "${GRAY}  Codec:${RESET}       ${CODEC}"
    echo -e "${GRAY}  Bitrate:${RESET}     $((BITRATE / 1000)) Mbps"
    echo -e "${GRAY}  EDID Source:${RESET} ${EDID_SOURCE}"
    if [[ "${EDID_SOURCE}" == "custom" ]]; then
        echo -e "${GRAY}  EDID Path:${RESET}   ${CUSTOM_EDID_PATH}"
    fi
    echo -e "${NVIDIA_GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    if ! confirm "Proceed with installation?"; then
        log_warning "Installation cancelled by user"
        exit 0
    fi
}

# ============================================================================
# Backup Functions
# ============================================================================
create_backup() {
    log_step "Creating Backups"

    mkdir -p "${BACKUP_DIR}"
    log_substep "Backup directory: ${BACKUP_DIR}"

    # Backup xorg.conf if it exists
    if [[ -f "/etc/X11/xorg.conf" ]]; then
        log_substep "Backing up /etc/X11/xorg.conf..."
        sudo cp /etc/X11/xorg.conf "${BACKUP_DIR}/xorg.conf"
        log_success "xorg.conf backed up"
    fi

    # Backup existing EDID files
    if ls /etc/X11/*.edid &> /dev/null; then
        log_substep "Backing up existing EDID files..."
        sudo cp /etc/X11/*.edid "${BACKUP_DIR}/" 2>/dev/null || true
        log_success "EDID files backed up"
    fi

    # Backup Sunshine config if it exists
    if [[ -d "${SUNSHINE_CONFIG_DIR}" ]]; then
        log_substep "Backing up Sunshine configuration..."
        cp -r "${SUNSHINE_CONFIG_DIR}" "${BACKUP_DIR}/sunshine"
        log_success "Sunshine config backed up"
    fi

    # Backup systemd override if it exists
    if [[ -f "${SYSTEMD_USER_DIR}/sunshine.service.d/override.conf" ]]; then
        log_substep "Backing up systemd override..."
        cp "${SYSTEMD_USER_DIR}/sunshine.service.d/override.conf" "${BACKUP_DIR}/sunshine-override.conf"
        log_success "systemd override backed up"
    fi

    log_success "All backups created in: ${BACKUP_DIR}"
    log_complete
}

# ============================================================================
# Sunshine Installation
# ============================================================================
install_sunshine() {
    log_step "Installing Sunshine"

    # Check if already installed
    if command -v sunshine &> /dev/null; then
        log_warning "Sunshine is already installed"
        local current_version
        current_version=$(sunshine --version 2>/dev/null || echo "unknown")
        log_substep "Current version: ${current_version}"

        if ! confirm "Reinstall/upgrade Sunshine?"; then
            log_info "Skipping Sunshine installation"
            log_complete
            return
        fi
    fi

    log_substep "Fetching latest release information..."
    local release_info
    release_info=$(curl -sL "${SUNSHINE_RELEASE_URL}")

    local download_url
    # Specifically get Ubuntu 24.04 ARM64 package (not Debian Trixie which has library version mismatches)
    download_url=$(echo "${release_info}" | grep -o "https://[^\"]*sunshine-ubuntu-24\.04-arm64\.deb" | head -1)

    # Fallback to any Ubuntu ARM64 package
    if [[ -z "${download_url}" ]]; then
        download_url=$(echo "${release_info}" | grep -o "https://[^\"]*sunshine-ubuntu.*arm64\.deb" | head -1)
    fi

    if [[ -z "${download_url}" ]]; then
        log_error "Failed to find Ubuntu ARM64 .deb package in latest release"
        exit 1
    fi

    local deb_file="/tmp/sunshine-arm64.deb"
    log_substep "Downloading: ${download_url##*/}"
    curl -L -o "${deb_file}" "${download_url}"

    log_substep "Installing Sunshine package..."
    sudo apt-get install -y "${deb_file}"

    rm -f "${deb_file}"

    log_success "Sunshine installed successfully"
    log_substep "Version: $(sunshine --version 2>/dev/null || echo 'unknown')"
    log_complete
}

# ============================================================================
# EDID Configuration
# ============================================================================
install_edid() {
    log_step "Installing EDID File"

    local source_edid
    if [[ "${EDID_SOURCE}" == "bundled" ]]; then
        source_edid="${EDID_DIR}/samsung-q800t.bin"
    else
        source_edid="${CUSTOM_EDID_PATH}"
    fi

    if [[ ! -f "${source_edid}" ]]; then
        log_error "EDID file not found: ${source_edid}"
        exit 1
    fi

    log_substep "Source: ${source_edid}"
    log_substep "Installing to: /etc/X11/4k120.edid"

    sudo cp "${source_edid}" /etc/X11/4k120.edid
    sudo chmod 644 /etc/X11/4k120.edid

    # Validate EDID
    log_substep "Validating EDID file..."
    if file /etc/X11/4k120.edid | grep -q "EDID"; then
        log_success "EDID file validated"
    else
        log_warning "EDID validation uncertain - file may not be valid EDID data"
    fi

    log_complete
}

# ============================================================================
# X11 Configuration
# ============================================================================
configure_x11() {
    log_step "Configuring X11"

    # Detect GPU BusID
    log_substep "Detecting NVIDIA GPU BusID..."
    local bus_id
    # Prefer fully-qualified domain:bus:device.function (via -D) and match both
    # "VGA compatible controller" and "3D controller" classes.
    bus_id=$(lspci -D | grep -Ei "NVIDIA" | grep -Ei "VGA compatible controller|3D controller" | awk '{print $1}' | head -n 1)

    # Fallback: try to find any NVIDIA GPU-like device (still with -D for domain)
    if [[ -z "${bus_id}" ]]; then
        bus_id=$(lspci -D | grep -Ei "nvidia.*gb10" | awk '{print $1}' | head -n 1)
    fi

    if [[ -z "${bus_id}" ]]; then
        log_error "Failed to detect NVIDIA GPU BusID"
        log_substep "Please check 'lspci -D | grep -i nvidia' output"
        exit 1
    fi

    # Convert from domain:bus:device.function to PCI:bus:device:function format
    # lspci shows: 000f:01:00.0 -> we need: PCI:15:1:0
    # Extract components
    local domain bus device func
    domain=$(echo "${bus_id}" | cut -d: -f1)
    bus=$(echo "${bus_id}" | cut -d: -f2)
    device=$(echo "${bus_id}" | cut -d: -f3 | cut -d. -f1)
    func=$(echo "${bus_id}" | cut -d. -f2)

    # Convert hex to decimal
    domain=$((16#${domain}))
    bus=$((16#${bus}))
    device=$((16#${device}))
    func=$((16#${func}))

    local pci_bus_id="PCI:${bus}:${device}:${func}"

    log_success "Detected BusID: ${pci_bus_id}"

    # Generate xorg.conf from template
    log_substep "Generating xorg.conf from template..."
    local temp_xorg="/tmp/xorg.conf.tmp"
    sed -e "s|{{BUS_ID}}|${pci_bus_id}|g" \
        -e "s|{{EDID_PATH}}|/etc/X11/4k120.edid|g" \
        "${TEMPLATES_DIR}/xorg.conf.template" > "${temp_xorg}"

    log_substep "Installing xorg.conf to /etc/X11/xorg.conf"
    sudo cp "${temp_xorg}" /etc/X11/xorg.conf
    sudo chmod 644 /etc/X11/xorg.conf
    rm -f "${temp_xorg}"

    log_success "X11 configuration installed"
    log_warning "X11 restart required - display will be reconfigured on next login"
    log_complete
}

# ============================================================================
# Permissions Configuration
# ============================================================================
configure_permissions() {
    log_step "Configuring Permissions"

    log_substep "Adding current user to 'video' and 'input' groups..."
    sudo usermod -aG video,input "${USER}"
    log_success "User added to groups"

    log_substep "Configuring udev rules for uinput..."
    local udev_rule='KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess"'
    echo "${udev_rule}" | sudo tee /etc/udev/rules.d/85-sunshine.rules > /dev/null

    log_substep "Reloading udev rules..."
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    log_success "udev rules configured"

    log_complete
}

# ============================================================================
# Sunshine Configuration
# ============================================================================
configure_sunshine() {
    log_step "Configuring Sunshine"

    # Create config directory
    mkdir -p "${SUNSHINE_CONFIG_DIR}"

    # Generate sunshine.conf from template
    log_substep "Generating sunshine.conf..."
    sed -e "s|{{CODEC}}|${CODEC}|g" \
        -e "s|{{BITRATE}}|${BITRATE}|g" \
        -e "s|{{FPS}}|${REFRESH_RATE}|g" \
        "${TEMPLATES_DIR}/sunshine.conf.template" > "${SUNSHINE_CONFIG_DIR}/sunshine.conf"

    log_success "sunshine.conf created"

    # Configure systemd user service
    log_substep "Configuring systemd user service..."
    mkdir -p "${SYSTEMD_USER_DIR}"
    mkdir -p "${SYSTEMD_USER_DIR}/sunshine.service.d"

    # Install the base service file (newer Sunshine versions don't include one)
    if [[ ! -f "${SYSTEMD_USER_DIR}/sunshine.service" ]]; then
        log_substep "Installing sunshine.service..."
        cp "${TEMPLATES_DIR}/sunshine.service" "${SYSTEMD_USER_DIR}/sunshine.service"
    fi

    # Install the override configuration
    cp "${TEMPLATES_DIR}/sunshine-override.conf" "${SYSTEMD_USER_DIR}/sunshine.service.d/override.conf"

    # Reload systemd
    log_substep "Reloading systemd configuration..."
    systemctl --user daemon-reload
    log_success "Systemd configuration reloaded"

    # Ask if they want auto-start
    echo ""
    if confirm "Enable Sunshine to start automatically on login?"; then
        systemctl --user enable sunshine
        log_success "Sunshine service enabled (will start automatically on next login)"

        # Enable lingering for user session persistence
        # This allows the user's systemd services to start at boot, even before GUI login
        log_substep "Enabling session persistence (lingering)..."
        if sudo loginctl enable-linger "$(whoami)"; then
            log_success "Session lingering enabled for reliable auto-start"
        else
            log_warning "Could not enable lingering - Sunshine may not start until first login"
            log_substep "To enable manually: ${DIM}sudo loginctl enable-linger $(whoami)${RESET}"
        fi
    else
        log_info "Sunshine service configured but not enabled for auto-start"
        log_substep "To start manually: ${DIM}systemctl --user start sunshine${RESET}"
        log_substep "To enable auto-start later: ${DIM}systemctl --user enable sunshine${RESET}"
    fi

    log_complete
}

# ============================================================================
# Optional: Tailscale (Remote Access)
# ============================================================================
configure_tailscale() {
    log_step "Optional: Tailscale Remote Access"

    echo ""
    if ! confirm "Install and configure Tailscale for remote access (VPN)?"; then
        log_info "Skipping Tailscale setup"
        log_complete
        return
    fi

    if ! command -v apt-get &> /dev/null; then
        log_warning "apt-get not found - cannot auto-install Tailscale on this system"
        log_substep "Install Tailscale manually: ${DIM}https://tailscale.com/download/linux${RESET}"
        log_complete
        return
    fi

    if command -v tailscale &> /dev/null; then
        log_success "Tailscale already installed"
    else
        log_substep "Installing Tailscale..."
        if sudo apt-get update; then
            if sudo apt-get install -y tailscale; then
                log_success "Tailscale installed"
            else
                log_warning "Failed to install Tailscale via apt"
                log_substep "To install manually: ${DIM}sudo apt-get update && sudo apt-get install -y tailscale${RESET}"
                log_substep "Or see: ${DIM}https://tailscale.com/download/linux${RESET}"
                log_complete
                return
            fi
        else
            log_warning "Failed to update package lists - skipping Tailscale installation"
            log_substep "Try later: ${DIM}sudo apt-get update && sudo apt-get install -y tailscale${RESET}"
            log_complete
            return
        fi
    fi

    log_substep "Enabling tailscaled service..."
    if sudo systemctl enable --now tailscaled; then
        log_success "tailscaled service enabled and started"
    else
        log_warning "Could not enable/start tailscaled"
        log_substep "To start manually: ${DIM}sudo systemctl enable --now tailscaled${RESET}"
        log_complete
        return
    fi

    echo ""
    if confirm "Install a systemd service to auto-connect at boot?"; then
        if [[ -f "${TEMPLATES_DIR}/tailscale-autoconnect.service" ]] && [[ -f "${TEMPLATES_DIR}/tailscale-autoconnect.env.template" ]]; then
            log_substep "Installing Tailscale autoconnect configuration..."

            # Environment file (not secret)
            sudo install -m 0644 "${TEMPLATES_DIR}/tailscale-autoconnect.env.template" /etc/default/tailscale-autoconnect

            sudo install -m 0644 "${TEMPLATES_DIR}/tailscale-autoconnect.service" /etc/systemd/system/tailscale-autoconnect.service
            sudo systemctl daemon-reload
            sudo systemctl enable --now tailscale-autoconnect.service
            log_success "Tailscale autoconnect service installed (tailscale-autoconnect.service)"
            log_substep "Optional: edit ${DIM}/etc/default/tailscale-autoconnect${RESET} to add args like ${DIM}--ssh${RESET}"
        else
            log_warning "Tailscale autoconnect templates not found - skipping service install"
        fi
    else
        log_info "Skipping autoconnect service installation"
    fi

    echo ""
    if confirm "Bring Tailscale up now (connect this machine to your tailnet)?"; then
        local up_choice
        local auth_key

        echo ""
        echo -e "${WHITE}${BOLD}Tailscale login method:${RESET}"
        echo -e "${GRAY}  1)${RESET} Interactive login (recommended)"
        echo -e "${GRAY}  2)${RESET} Auth key (non-interactive)"
        echo ""
        while true; do
            prompt_user "Select (1-2)" up_choice
            case "${up_choice}" in
                1)
                    log_substep "Running: ${DIM}sudo tailscale up${RESET}"
                    if sudo tailscale up; then
                        log_success "Tailscale is up"
                    else
                        log_warning "tailscale up failed or was cancelled"
                        log_substep "To retry: ${DIM}sudo tailscale up${RESET}"
                    fi
                    break
                    ;;
                2)
                    prompt_secret "Enter Tailscale auth key (tskey-auth-...)" auth_key
                    if [[ -z "${auth_key}" ]]; then
                        log_warning "No auth key provided; falling back to interactive login"
                        if sudo tailscale up; then
                            log_success "Tailscale is up"
                        else
                            log_warning "tailscale up failed or was cancelled"
                            log_substep "To retry: ${DIM}sudo tailscale up${RESET}"
                        fi
                    else
                        log_substep "Running: ${DIM}sudo tailscale up --authkey <hidden>${RESET}"
                        if sudo tailscale up --authkey "${auth_key}"; then
                            log_success "Tailscale is up"
                        else
                            log_warning "tailscale up failed"
                            log_substep "To retry interactively: ${DIM}sudo tailscale up${RESET}"
                        fi
                    fi
                    break
                    ;;
                *)
                    log_error "Invalid selection. Please choose 1-2."
                    ;;
            esac
        done
    else
        log_info "Tailscale installed; you can connect later"
        log_substep "To connect: ${DIM}sudo tailscale up${RESET}"
    fi

    log_complete
}

# ============================================================================
# Post-Install Validation
# ============================================================================
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

    # Check EDID file
    log_substep "Checking EDID file..."
    if [[ -f "/etc/X11/4k120.edid" ]]; then
        log_success "EDID file exists"
    else
        log_error "EDID file not found"
        ((errors++))
    fi

    # Check Sunshine config
    log_substep "Checking Sunshine configuration..."
    if [[ -f "${SUNSHINE_CONFIG_DIR}/sunshine.conf" ]]; then
        log_success "sunshine.conf exists"
    else
        log_error "sunshine.conf not found"
        ((errors++))
    fi

    # Check systemd override
    log_substep "Checking systemd override..."
    if [[ -f "${SYSTEMD_USER_DIR}/sunshine.service.d/override.conf" ]]; then
        log_success "systemd override exists"
    else
        log_error "systemd override not found"
        ((errors++))
    fi

    if [[ ${errors} -gt 0 ]]; then
        log_warning "Validation completed with ${errors} error(s)"
    else
        log_success "All validation checks passed"
    fi

    log_complete
}

# ============================================================================
# Final Instructions
# ============================================================================
print_final_instructions() {
    echo ""
    echo -e "${NVIDIA_GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}${BOLD}Installation Complete!${RESET}"
    echo -e "${NVIDIA_GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "${WHITE}${BOLD}Next Steps:${RESET}"
    echo ""
    echo -e "${NVIDIA_GREEN}1.${RESET} ${BOLD}Restart your system${RESET}"
    echo -e "${GRAY}   └─${RESET} Required for X11 to load new virtual display configuration"
    echo -e "${GRAY}   └─${RESET} Run: ${DIM}sudo reboot${RESET}"
    echo ""
    echo -e "${NVIDIA_GREEN}2.${RESET} ${BOLD}Run the post-installation helper${RESET} ${DIM}(Recommended)${RESET}"
    echo -e "${GRAY}   └─${RESET} Run: ${DIM}./after-install.sh${RESET}"
    echo -e "${GRAY}   └─${RESET} The helper will verify your installation and guide you through setup"
    echo ""
    echo -e "${WHITE}${BOLD}What the helper does:${RESET}"
    echo -e "${GRAY}  ✓${RESET} Checks virtual display (${RESOLUTION} @ ${REFRESH_RATE}Hz)"
    echo -e "${GRAY}  ✓${RESET} Verifies Sunshine service status"
    echo -e "${GRAY}  ✓${RESET} Tests GPU encoding capabilities"
    echo -e "${GRAY}  ✓${RESET} Checks network accessibility"
    echo -e "${GRAY}  ✓${RESET} Provides troubleshooting guidance if needed"
    echo ""
    echo -e "${WHITE}${BOLD}Quick Commands:${RESET}"
    echo -e "${GRAY}  •${RESET} Interactive menu: ${DIM}./after-install.sh${RESET}"
    echo -e "${GRAY}  •${RESET} Run all checks: ${DIM}./after-install.sh --check-all${RESET}"
    echo -e "${GRAY}  •${RESET} View logs: ${DIM}./after-install.sh --logs${RESET}"
    echo ""
    echo -e "${WHITE}${BOLD}Manual Setup (if not using helper):${RESET}"
    echo -e "${GRAY}  1.${RESET} Verify display: ${DIM}xrandr${RESET}"
    echo -e "${GRAY}  2.${RESET} Start Sunshine: ${DIM}systemctl --user start sunshine${RESET}"
    echo -e "${GRAY}  3.${RESET} Configure at: ${DIM}https://localhost:47990${RESET}"
    echo -e "${GRAY}  4.${RESET} Connect with: ${DIM}Moonlight client (moonlight-stream.org)${RESET}"
    echo ""
    echo -e "${WHITE}${BOLD}Backups Saved To:${RESET}"
    echo -e "${GRAY}  •${RESET} ${BACKUP_DIR}"
    echo ""
    echo -e "${NVIDIA_GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
}

# ============================================================================
# Main Installation Flow
# ============================================================================
main() {
    # Display logo
    print_logo

    # Prerequisites
    check_prerequisites

    # Interactive configuration
    configure_resolution
    configure_codec
    configure_bitrate
    configure_edid

    # Confirmation
    print_configuration_summary

    # Installation steps
    create_backup
    install_sunshine
    install_edid
    configure_x11
    configure_permissions
    configure_sunshine
    validate_installation
    configure_tailscale

    # Final instructions
    print_final_instructions
}

# ============================================================================
# Entry Point
# ============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
