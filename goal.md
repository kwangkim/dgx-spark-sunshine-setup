Update dgx-spark-sunshine-setup to use the latest version of sunshine and fix the issue of sunshine not starting automatically.

1. I will use ipad to connect to the dgx server via tailscale. Add ipad 12.9 pro M2 resolution to the sunshine config.
2. Update all. DGX spark uses the latest version, Ubuntu 24.04.3 LTS and DGX OS 7.3.1.
3. Install sunshine using the latest version from the official website.
4. Fix the issue of sunshine not starting automatically.
5. Add the current monitor DEll AW3420DW to the sunshine config.

## Fixes Applied

### Fix 1: GPU BusID Detection
The script was looking for "nvidia.*gb10" in lspci output, but the GPU shows up as `Device 2e12` (not GB10). Now it correctly detects the NVIDIA VGA controller and properly converts the bus ID from hex (`000f:01:00.0`) to decimal (`PCI:1:0:0`).

### Fix 2: Missing systemd Service File
Newer Sunshine versions (2025.924+) don't ship with a systemd service file. Created `templates/sunshine.service` and updated the installer to copy it to `~/.config/systemd/user/`.

### Fix 3: Use Ubuntu 24.04 ARM64 Package
The installer was downloading `sunshine-debian-trixie-arm64.deb` which has incompatible library versions (needs `libminiupnpc.so.18` and `libicuuc.so.76`). Updated to download `sunshine-ubuntu-24.04-arm64.deb` instead.

### Fix 4: Enable X11 and Auto-Login for Headless Operation
Sunshine requires an X11 graphical session to detect displays and encode video. DGX OS defaults to Wayland which is not supported.

**Applied changes to `/etc/gdm3/custom.conf`:**
```ini
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=devkwang
WaylandEnable=false
```

This enables:
- **WaylandEnable=false** - Forces X11 instead of Wayland (required for Sunshine)
- **AutomaticLogin** - Auto-logs into desktop on boot (required for headless streaming)

### Fix 5: X11 Display Connector Name
The xorg.conf was configured for `DFP-0` connector, but `nvidia-xconfig --query-gpu-info` shows the GB10 GPU uses `TV-0` as the display device name.

**Changed in `/etc/X11/xorg.conf` and `templates/xorg.conf.template`:**
```
Option "ConnectedMonitor" "TV-0"
Option "CustomEDID" "TV-0:/etc/X11/4k120.edid"
```

## Installation Steps

1. Run installer: `./install.sh`
2. Configure GDM for X11 and auto-login (see Fix 4 above)
3. Reboot: `sudo reboot`
4. Open firewall: `sudo ufw allow 47984:47990/tcp && sudo ufw allow 47998:48010/udp`
5. Start Sunshine: `systemctl --user start sunshine`
6. Configure credentials: Open https://192.168.2.200:47990 in browser
7. Connect with Moonlight on iPad
