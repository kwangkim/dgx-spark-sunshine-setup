# External Integrations

**Analysis Date:** 2026-02-04

## APIs & External Services

**Package Distribution:**
- GitHub Releases API (LizardByte/Sunshine)
  - Endpoint: `https://api.github.com/repos/LizardByte/Sunshine/releases/latest`
  - Purpose: Fetch latest Sunshine ARM64 .deb package
  - Method: `curl -sL` from `install.sh` line 422
  - Specific package: `sunshine-ubuntu-24.04-arm64.deb` (primary), fallback to any `sunshine-ubuntu*-arm64.deb`
  - Used by: `install_sunshine()` function in `install.sh`
  - No authentication required (public releases)

**VPN & Remote Access:**
- Tailscale VPN Network
  - Auth: Interactive login (`sudo tailscale up`) or auth key (`TS_AUTH_KEY`)
  - Purpose: Secure remote access to DGX Spark Sunshine server
  - Portal: `https://tailscale.com/download/linux`
  - Installation: Via `apt-get install -y tailscale`
  - Daemon: `tailscaled` (system service)
  - Configuration: `sudo tailscale up [--authkey TSKEY] [--ssh]`
  - Optional auto-connect service: `tailscale-autoconnect.service`
  - Env var: `TS_UP_EXTRA_ARGS` in `/etc/default/tailscale-autoconnect`

## Data Storage

**Databases:**
- None used

**File Storage:**
- Local filesystem only
  - Config directory: `~/.config/sunshine/`
  - Systemd overrides: `~/.config/systemd/user/`
  - Backups: `~/.sunshine-setup-backups/YYYYMMDD-HHMMSS/`
  - System configs: `/etc/X11/xorg.conf`, `/etc/X11/4k120.edid`
  - X11 session environment: Accessed via `DISPLAY` and `XAUTHORITY` env vars

**Caching:**
- None detected

## Authentication & Identity

**Auth Provider:**
- Sunshine (built-in)
  - Method: Username/password configured via Web UI
  - Web UI: `https://localhost:47990`
  - State file: `~/.config/sunshine/sunshine_state.json` (credentials storage)
  - PIN-based pairing with Moonlight client (4-digit PIN)

- Tailscale (optional)
  - Method 1: Interactive login (browser-based OAuth)
    - Command: `sudo tailscale up`
    - Redirects to browser for Tailscale account authentication
  - Method 2: Auth key (non-interactive)
    - Format: `tskey-auth-...` (secret)
    - Stored temporarily in script environment (not persisted)
  - SSH support: Optional with `--ssh` flag

## Monitoring & Observability

**Error Tracking:**
- None detected (no external error tracking)

**Logs:**
- systemd journal (default)
  - View Sunshine logs: `journalctl --user -u sunshine -n 200 --no-pager`
  - Live monitoring: `journalctl --user -u sunshine -f | grep -i "encoder\|fps"`
  - Captures: Service startup, NVENC encoding performance, FPS metrics
  - User-level service logging (not system-level)

- System logs (for Tailscale and X11):
  - X11 server logs: `/var/log/Xorg.0.log`
  - systemd system logs: `journalctl -u tailscale`

## CI/CD & Deployment

**Hosting:**
- Self-hosted on NVIDIA DGX Spark hardware (no cloud deployment)
- On-premises headless Linux server

**CI Pipeline:**
- None detected (no automated testing or deployment pipeline)
- Manual installation via shell script

## Environment Configuration

**Required env vars:**
- `DISPLAY` - X11 display identifier (e.g., `:0`)
  - Set by: Display manager at session start
  - Exported to systemd: `dbus-update-activation-environment --systemd DISPLAY XAUTHORITY`

- `XAUTHORITY` - X11 authentication file path
  - Typical: `~/.Xauthority`
  - Required by: Sunshine to access X11 session
  - Exported to systemd: `dbus-update-activation-environment --systemd DISPLAY XAUTHORITY`

- `TS_UP_EXTRA_ARGS` (optional)
  - Value: `"--ssh"` (or empty)
  - Location: `/etc/default/tailscale-autoconnect`
  - Purpose: Pass extra arguments to `tailscale up` at boot

- `TS_AUTH_KEY` (optional, temporary)
  - Format: `tskey-auth-...` (Tailscale machine auth key)
  - Used for: Non-interactive Tailscale authentication
  - Sourced from: User input during installation (not persisted)
  - Security: Read as secret input with `read -rs`

**Secrets location:**
- `/root/.config/sunshine/sunshine_state.json` - Sunshine credentials
- `/etc/default/tailscale-autoconnect` - Tailscale env config (non-secret)
- Tailscale auth key: Temporary, not stored (or in `/var/lib/tailscale/`)

## Webhooks & Callbacks

**Incoming:**
- None detected

**Outgoing:**
- None detected

## Network Ports

**Sunshine:**
- Port 47990 (HTTPS)
  - Web UI: `https://<DGX_IP>:47990`
  - Pairing interface for Moonlight clients
  - Accessible on: localhost (curl check), LAN, or Tailscale VPN

**Moonlight Client (Streaming):**
- Uses NVIDIA Sunshine streaming protocol (GameStream-compatible)
- Port negotiation: Handled by Sunshine Web UI during pairing

**Tailscale (VPN):**
- Port 41641 (UDP, default)
  - Tailscale control plane communication
- Custom IP assignment within tailnet (e.g., `100.x.y.z`)

## Security Considerations

**TLS/HTTPS:**
- Sunshine Web UI: Self-signed certificate on port 47990
- Connection check: `curl -k https://localhost:47990` (insecure flag for self-signed cert)

**Hardware Access:**
- Device groups:
  - `video` group - GPU access for NVENC encoding
  - `input` group - Input device access (mouse, keyboard)
  - Configured via: `sudo usermod -aG video,input ${USER}`

- udev rules:
  - `/etc/udev/rules.d/85-sunshine.rules` - uinput device access
  - Rule: `KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess"`

**Privilege Levels:**
- Sunshine runs as: User service (not root)
- systemd user service: `~/.config/systemd/user/sunshine.service`
- Root operations: Only for `/etc/X11/`, system services, and Tailscale setup

---

*Integration audit: 2026-02-04*
