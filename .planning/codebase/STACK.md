# Technology Stack

**Analysis Date:** 2026-02-04

## Languages

**Primary:**
- Bash (shell scripting) - All installation and configuration scripts (`install.sh`, `after-install.sh`, `uninstall.sh`)
- Configuration files (EDID binary, X11 config, systemd config)

**Secondary:**
- None (no compiled code, pure shell + configuration)

## Runtime

**Environment:**
- Ubuntu 24.04 LTS (target OS)
- Bash 4.x+ (standard on Ubuntu)
- systemd (user and system services)
- X11 display server (graphical session)

**Package Manager:**
- apt-get (Ubuntu/Debian)
- No lockfile required (shell scripts with runtime dependency resolution)

## Frameworks

**Core:**
- Sunshine (game streaming server) - LizardByte project, ARM64 build for DGX Spark
  - NVENC hardware encoding (NVIDIA GPU codec)
  - Web UI on port 47990 (HTTPS)
  - User systemd service (`~/.config/systemd/user/sunshine.service`)

**System Services:**
- systemd (user and system service management)
  - `sunshine.service` - Main game streaming service
  - `sunshine.service.d/override.conf` - Service overrides
  - `tailscale-autoconnect.service` (optional) - Auto-connect VPN on boot

**Display Server:**
- X11 with NVIDIA proprietary driver
- Custom EDID (Extended Display Identification Data) for virtual display

## Key Dependencies

**Critical:**
- `nvidia-smi` - NVIDIA driver tools (required for GPU detection and NVENC encoding)
  - Must detect GB10 hardware
  - Enables hardware video encoding

- `curl` - HTTP client (required for fetching Sunshine releases from GitHub)
  - Fetches: `https://api.github.com/repos/LizardByte/Sunshine/releases/latest`

- `lspci` - PCI device enumeration (required for GPU BusID detection)
  - Used to find NVIDIA GB10 GPU domain:bus:device.function in X11 config

- `Xorg` / `X11` - Display server and graphics environment
  - Sunshine captures display `:0` (first X11 session)

- `sed` - Text stream editor (required for configuration template substitution)
  - Generates dynamic configs: `xorg.conf`, `sunshine.conf`

**Infrastructure (Optional):**
- Tailscale (`tailscale`, `tailscaled`) - VPN for remote access
  - Fetched from: `https://tailscale.com/download/linux`
  - Installed via: `apt-get install -y tailscale`
  - Auth key support for non-interactive setup

## Configuration

**Environment:**
- Files are generated from templates, not environment variables
- User selections drive configuration (resolution, codec, bitrate)

**Build/Installation Config:**

Configuration templates in `templates/`:
- `xorg.conf.template` - X11 virtual display config
  - Substitutions: `{{BUS_ID}}`, `{{EDID_PATH}}`
  - Installed to: `/etc/X11/xorg.conf`

- `sunshine.conf.template` - Sunshine streaming server config
  - Substitutions: `{{CODEC}}`, `{{BITRATE}}`, `{{FPS}}`
  - Installed to: `~/.config/sunshine/sunshine.conf`

- `sunshine.service` - systemd user service unit
  - Type: simple
  - ExecStart: `/usr/bin/sunshine`
  - Installed to: `~/.config/systemd/user/sunshine.service`

- `sunshine-override.conf` - systemd service override
  - Installed to: `~/.config/systemd/user/sunshine.service.d/override.conf`

- `tailscale-autoconnect.service` (optional) - Boot-time VPN auto-connect
  - Installed to: `/etc/systemd/system/tailscale-autoconnect.service`

- `tailscale-autoconnect.env.template` (optional) - VPN configuration
  - Variable: `TS_UP_EXTRA_ARGS` (e.g., `"--ssh"`)
  - Installed to: `/etc/default/tailscale-autoconnect`

**Backup System:**
- All overwritten files backed up to: `~/.sunshine-setup-backups/YYYYMMDD-HHMMSS/`
- Contains: `xorg.conf`, `*.edid`, `sunshine/`, `sunshine-override.conf`

## Platform Requirements

**Development:**
- NVIDIA DGX Spark (GB10) hardware
- Ubuntu 24.04 LTS with NVIDIA driver installed
- Root/sudo access (for `/etc/X11/` and systemd system services)
- Bash shell with standard utilities

**Production (Deployment):**
- NVIDIA DGX Spark (GB10) - proprietary hardware with NVIDIA GPU
- Ubuntu 24.04 LTS (target OS)
- Desktop environment running X11 session on `:0`
- NVIDIA proprietary driver (not nouveau)
- Network connectivity for:
  - GitHub API (fetch Sunshine releases)
  - Tailscale infrastructure (if VPN option selected)

## Hardware Capabilities

**GPU Encoding:**
- NVIDIA NVENC (hardware encoder on GB10)
- Supported codecs: HEVC (H.265), AV1, H.264
- Configurable bitrate: 20-300 Mbps
- Display modes: Up to 4K@60Hz or 1440p@120Hz (165 MHz pixel clock limit on GB10)

**Performance Profile:**
- Idle: CPU ~0%, GPU ~0%, Memory ~100 MB
- Streaming 1440p@120Hz: CPU ~5-10%, GPU ~10-20%, Memory ~200 MB

---

*Stack analysis: 2026-02-04*
