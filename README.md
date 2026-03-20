# NVIDIA DGX Spark Sunshine Streaming Setup

![DGX Spark Sunshine Installer](img/install.png)

One-command installer that sets up [Sunshine](https://github.com/LizardByte/Sunshine) + a virtual X11 display on NVIDIA DGX Spark (GB10), so you can stream the desktop with Moonlight without a monitor attached.

## Quick Start

```bash
git clone https://github.com/seanGSISG/dgx-spark-sunshine-setup.git
cd dgx-spark-sunshine-setup
./install.sh
sudo reboot
./after-install.sh
```

Then open Sunshine Web UI and pair Moonlight:

- `https://<YOUR_DGX_IP>:47990`
- Moonlight client: https://moonlight-stream.org

## Overview

### What the Installer Does

- Creates backups in `~/.sunshine-setup-backups/`
- Installs Sunshine (ARM64 .deb)
- Installs EDID to `/etc/X11/4k120.edid`
- Generates `/etc/X11/xorg.conf` using NVIDIA `CustomEDID`
- Writes Sunshine config to `~/.config/sunshine/sunshine.conf`
- Installs a systemd **user** service for Sunshine
- Optionally enables autostart and attempts to enable lingering (`sudo loginctl enable-linger $(whoami)`)
- Optionally offers to install/configure Tailscale

### Requirements

- DGX Spark (GB10), Ubuntu 24.04
- X11 desktop session on the DGX (Sunshine captures an X session on `:0`)
  - For headless operation, you typically need desktop auto-login so a session exists after reboot

### Hardware Limitation (GB10)

GB10 has a ~165 MHz pixel clock limit. Practical impact: 4K@120Hz won't work; 4K@60Hz and 1440p@120Hz do.

### Repository Structure

```
dgx-spark-sunshine-setup/
├── install.sh              # Main installation script
├── after-install.sh        # Post-reboot configuration
├── uninstall.sh            # Removal script
├── setup.md                # Detailed setup guide
├── edid/                   # EDID files for virtual displays
├── img/                    # Documentation images
└── templates/              # Configuration templates
    ├── xorg.conf.template
    ├── sunshine.conf.template
    ├── sunshine.service
    ├── sunshine-override.conf
    ├── tailscale-autoconnect.service
    └── tailscale-autoconnect.env.template
```

## Technical Details

### Virtual Display Technology

This setup uses NVIDIA's proprietary **CustomEDID** option in xorg.conf to create a virtual display without a physical monitor. The EDID (Extended Display Identification Data) file tells the GPU what resolutions and refresh rates the "monitor" supports.

Key differences from other approaches:
- **No kernel parameters needed** - Works with NVIDIA's proprietary driver
- **No dummy HDMI plug required** - Completely virtual
- **Persistent across reboots** - Configured in X11, not runtime

### Hardware Encoding

Sunshine is configured to use NVIDIA's **NVENC** hardware encoder, which:
- Offloads video encoding from CPU to dedicated GPU hardware
- Achieves high quality at high bitrates with minimal performance impact
- Supports HEVC, H.264, and AV1 codecs
- Uses negligible VRAM (~100-200 MB)

### Performance Impact

When idle (not streaming):
- **CPU**: ~0%
- **GPU**: ~0%
- **Memory**: ~100 MB

When actively streaming 1440p @ 120Hz:
- **CPU**: ~5-10% (one core)
- **GPU**: ~10-20% (encoding only)
- **Memory**: ~200 MB
- **Network**: Based on your selected bitrate

## Configuration

### X Session Environment (DISPLAY/XAUTHORITY)

The Sunshine user service needs access to your X session. Don't hardcode `XAUTHORITY` in the systemd override; instead, export it into the systemd user manager at session start:

```bash
dbus-update-activation-environment --systemd DISPLAY XAUTHORITY
systemctl --user show-environment | grep -E 'DISPLAY|XAUTHORITY'
```

If you want it to run every login, `~/.xprofile` is a simple option on many desktops.

### Tailscale (Optional)

During install you can choose to install Tailscale.

- The installer can enable `tailscaled` and optionally run `sudo tailscale up --accept-dns=false`
- It can also install an optional boot-time unit `templates/tailscale-autoconnect.service` that runs `tailscale up` on boot
  - Default is safe for general internet access: it preserves the machine's existing DNS with `--accept-dns=false`
  - If you want Tailscale SSH later, set `TS_UP_EXTRA_ARGS="--accept-dns=false --ssh"` in `/etc/default/tailscale-autoconnect`
  - If you want tailnet DNS or MagicDNS later, change the setting to `TS_UP_EXTRA_ARGS="--accept-dns=true"`

### iPad / SSH Setup

See [setup.md](setup.md) for a step-by-step guide for:

- Configuring everything from another computer via SSH
- Configuring using only an iPad (Moonlight + Safari + SSH)

## Troubleshooting

### Sunshine Service Status

```bash
systemctl --user status sunshine
journalctl --user -u sunshine -n 200 --no-pager
```

### Black Screen / Capture Issues

- Ensure a graphical session exists on the DGX (`DISPLAY=:0`). If nobody logs in, there may be nothing to capture
- Ensure the systemd user environment has `XAUTHORITY`:

```bash
systemctl --user show-environment | grep -E 'DISPLAY|XAUTHORITY'
```

### Autostart After Reboot

Systemd user services may require lingering.

```bash
sudo loginctl enable-linger $(whoami)
loginctl show-user $(whoami) --property=Linger
```

Policy note: `loginctl enable-linger` is governed by PolicyKit (`org.freedesktop.login1.set-user-linger`). If PolicyKit is missing/restrictive, it may fail with "Access denied"; `sudo loginctl ...` is the fallback.

### Low Performance / Stuttering

If streaming is choppy or low quality:

```bash
# Check GPU utilization
nvidia-smi

# Monitor encoding performance
journalctl --user -u sunshine -f | grep -i "encoder\|fps"

# Adjust bitrate in ~/.config/sunshine/sunshine.conf
# Lower bitrate for unstable connections
# Increase bitrate for LAN with stable gigabit connection
```

### Credentials Reset

If you forgot Sunshine username/password:

```bash
# Stop Sunshine
systemctl --user stop sunshine

# Remove credentials file
rm ~/.config/sunshine/sunshine_state.json

# Start Sunshine
systemctl --user start sunshine

# Reconfigure at https://localhost:47990
```

### Connectivity

```bash
curl -k https://localhost:47990
sudo ufw status
```

### Tailscale DNS Health Warning

If Tailscale reports `can't reach the configured DNS servers`, the tailnet is advertising DNS servers that this machine cannot currently reach. The installer defaults to `--accept-dns=false` to avoid breaking normal internet access on headless streaming boxes.

To disable tailnet DNS on an already-configured machine:

```bash
sudo tailscale set --accept-dns=false
sudoedit /etc/default/tailscale-autoconnect
# Set: TS_UP_EXTRA_ARGS="--accept-dns=false"
sudo systemctl restart tailscale-autoconnect
```

If you do want MagicDNS or split DNS, confirm the advertised DNS servers are reachable from this device, update `/etc/default/tailscale-autoconnect` to `TS_UP_EXTRA_ARGS="--accept-dns=true"` if that service is installed, and then re-enable it:

```bash
sudo tailscale set --accept-dns=true
sudo systemctl restart tailscale-autoconnect
```

## Advanced Usage

### Backups

All backups are automatically created in `~/.sunshine-setup-backups/` with timestamps:

```
~/.sunshine-setup-backups/YYYYMMDD-HHMMSS/
├── xorg.conf                    # Original X11 configuration
├── *.edid                       # Original EDID files
├── sunshine/                    # Original Sunshine configuration
└── sunshine-override.conf       # Original systemd override
```

To restore a backup:
```bash
# Navigate to backup directory
cd ~/.sunshine-setup-backups/YYYYMMDD-HHMMSS/

# Restore xorg.conf
sudo cp xorg.conf /etc/X11/xorg.conf

# Restore Sunshine config
cp -r sunshine/* ~/.config/sunshine/

# Reboot
sudo reboot
```

### Custom EDID Files

If the bundled Samsung Q800T EDID doesn't work for your use case:

1. Extract EDID from your monitor (on another system):
   ```bash
   # Linux
   cat /sys/class/drm/card0-HDMI-A-1/edid > my-monitor.bin

   # Windows (use tools like Custom Resolution Utility)
   ```

2. Run installer and select "custom EDID" option
3. Provide path to your .bin file

**Note**: Custom EDIDs must respect GB10's 165 MHz pixel clock limitation.

### Changing Configuration

To change resolution, codec, or bitrate after installation:

1. Edit `~/.config/sunshine/sunshine.conf`
2. Restart Sunshine:
   ```bash
   systemctl --user restart sunshine
   ```

For display resolution changes, you'll need to:
1. Obtain a compatible EDID file
2. Replace `/etc/X11/4k120.edid`
3. Reboot

### Uninstalling

Run the uninstaller as your normal user (do not run it under sudo):

```bash
./uninstall.sh
```

Or manually remove the installation:

```bash
# Stop and disable Sunshine
systemctl --user stop sunshine
systemctl --user disable sunshine

# Remove Sunshine
sudo apt-get remove sunshine

# Restore original configurations from backup
cd ~/.sunshine-setup-backups/YYYYMMDD-HHMMSS/
sudo cp xorg.conf /etc/X11/xorg.conf

# Reboot
sudo reboot
```

## Contributing

This is a community project for DGX Spark users. Contributions welcome!

### Reporting Issues

Please include:
- DGX OS version (`cat /etc/dgx-release`)
- NVIDIA driver version (`nvidia-smi`)
- Selected configuration (resolution, codec, bitrate)
- Relevant logs (`journalctl --user -u sunshine`)

### Pull Requests

Improvements to the installer, documentation, or EDID files are welcome.

## Resources

### Official Documentation
- **Sunshine GitHub**: https://github.com/LizardByte/Sunshine
- **Sunshine Docs**: https://docs.lizardbyte.dev/projects/sunshine/
- **Moonlight**: https://moonlight-stream.org
- **NVIDIA DGX Spark**: https://docs.nvidia.com/dgx/dgx-spark/

### Related Projects
- **DGX Spark Playbooks**: https://github.com/NVIDIA/dgx-spark-playbooks
- **DGX Spark Portal**: https://build.nvidia.com/spark

### EDID Resources
- **Linux TV EDID Repository**: https://git.linuxtv.org/v4l-utils.git/tree/utils/edid-decode/data
- **EDID Decode Tool**: `apt-get install edid-decode`

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- **Sunshine/Moonlight Team** - For the excellent streaming protocol
- **NVIDIA** - For DGX Spark hardware and driver support
- **Linux TV Project** - For the EDID database
- **Community Contributors** - For testing and feedback
