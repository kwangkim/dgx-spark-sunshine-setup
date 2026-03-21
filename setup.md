# Setting up Sunshine + Moonlight (iPad and/or Monitor)

This guide explains how to connect to the Sunshine streaming server running on your DGX Spark system.

It includes two setup paths:

- From another computer (monitor) via SSH (recommended)
- Using only an iPad (Moonlight + Safari + SSH)

## Prerequisites

1.  **Sunshine Running**: Ensure Sunshine is installed and running on your DGX Spark system.
    *   Verify by accessing the Web UI at `https://<YOUR_DGX_IP>:47990`.
2.  **Network**: Your iPad and DGX Spark must be on the same network, or accessible via VPN/ZeroTier/Tailscale.

## Important: X session environment (DISPLAY/XAUTHORITY)

Sunshine runs as a user service and needs access to your X session. The recommended approach is to export your session environment into the systemd user manager at session start:

```bash
dbus-update-activation-environment --systemd DISPLAY XAUTHORITY
```

Verify the user manager sees it:

```bash
systemctl --user show-environment | grep -E 'DISPLAY|XAUTHORITY'
```

If `XAUTHORITY` is missing, Sunshine may start but capture a black screen.

The installer now adds a desktop autostart entry that runs this sync automatically on GUI login and restarts Sunshine if it was already running.

## Path A: Setup from another computer (monitor) via SSH (recommended)

This is the most common “no local peripherals” workflow: use a laptop/desktop with a monitor to SSH into the DGX Spark and configure everything.

1. From your other computer, SSH into the DGX as your normal user:
    ```bash
    ssh <user>@<YOUR_DGX_IP>
    ```
2. Run the installer:
    ```bash
    cd <path-to-this-repo>
    ./install.sh
    ```
    - When it runs `sudo`, you’ll be prompted for your password in the SSH session.
3. When prompted, choose to enable Sunshine auto-start.
4. Reboot:
    ```bash
    sudo reboot
    ```
5. Open the Sunshine Web UI from the other computer’s browser to confirm it’s reachable:
    - `https://<YOUR_DGX_IP>:47990`
6. Ensure the DGX actually has a running graphical session on `:0`.
    - Even if you configure Sunshine remotely, it still captures an X session running on the DGX.
    - If nobody ever logs into the DGX desktop, there may be no session to capture.
    - If you see a black screen later, you may need to log in once locally (just for initial login) or enable desktop auto-login in your display manager.
7. Once a session exists, export the environment into systemd user manager (run this inside that session when possible):
    ```bash
    dbus-update-activation-environment --systemd DISPLAY XAUTHORITY
    systemctl --user show-environment | grep -E 'DISPLAY|XAUTHORITY'
    systemctl --user restart sunshine
    ```
8. Pair Moonlight from your iPad (see Step 2 below) and launch **Desktop**.

## Path B: Setup using only an iPad (headless)

This path assumes you can SSH into the DGX from the iPad.

1. Install an SSH client on the iPad.
2. SSH to the DGX as your normal user:
    ```bash
    ssh <user>@<YOUR_DGX_IP>
    ```
3. Run the installer:
    ```bash
    cd <path-to-this-repo>
    ./install.sh
    ```
4. Reboot:
    ```bash
    sudo reboot
    ```
5. Ensure the DGX actually has a running graphical session on `:0`.
    - Sunshine is configured with `DISPLAY=:0`. If no one ever logs in, there may be no active X session to capture.
    - If you see a black screen, you may need to log in once locally (monitor/keyboard just for initial login) or enable desktop auto-login in your display manager.

## Step 1: Install Moonlight on iPad

1.  Open the **App Store** on your iPad.
2.  Search for **Moonlight Game Streaming**.
3.  Install the app (developed by Cameron Gutman).

## Step 2: Pair iPad with Sunshine

1.  Open **Moonlight** on your iPad.
2.  Wait for your DGX Spark PC to appear in the PC list.
    *   If it doesn't appear automatically, tap the **+** icon in the top right and enter your DGX Spark's IP address manually.
3.  Tap on your PC icon.
4.  A 4-digit PIN will appear on your iPad screen.
5.  Go to your computer (or access the Sunshine Web UI from your iPad browser) at `https://<YOUR_DGX_IP>:47990`.
6.  Navigate to the **PIN** tab in the top menu.
7.  Enter the 4-digit PIN displayed on your iPad and click **Send**.
8.  Your iPad should now be paired.

## Step 3: Configure Resolution & Settings

To get the best experience on iPad Pro 12.9" (or other models), you should match the streaming resolution to your device aspect ratio or the native resolutions we configured.

1.  In Moonlight on iPad, tap the **Settings** (gear icon).
2.  **Resolution**:
    *   For **iPad Pro 12.9"**, select **Native (2732x2048)** if available, or manually set a custom resolution if the option allows.
    *   If using the pre-configured dummy display modes from our `install.sh`, you can select **4K (3840x2160)** for high quality, or **1440p (2560x1440)** for better performance, depending on your bandwidth.
    *   *Note: Our setup script includes a custom mode for 2732x2048 to match the iPad Pro 12.9" aspect ratio perfectly.*
3.  **Frame Rate**: Set to **60 FPS** or **120 FPS** (if your iPad supports ProMotion and your network can handle it).
4.  **Bitrate**:
    *   Adjust based on your connection. **50-80 Mbps** is usually a good sweet spot for local Wi-Fi 5/6 connections.
5.  **Touchscreen Mode**:
    *   Moonlight supports different input modes. For desktop use, "Trackpad" mode might be useful, or use a Bluetooth mouse/keyboard paired to the iPad.

## Step 4: Connecting

1.  Tap your PC icon in the main Moonlight list.
2.  Select **Desktop** (or the specific application you want to launch).
3.  The stream should start.

### Troubleshooting

*   **Black Screen / No Display**:
    *   Ensure the X server is running: `systemctl status display-manager`.
    *   Check the systemd user environment: `systemctl --user show-environment | grep -E 'DISPLAY|XAUTHORITY'`
    *   If the local desktop went blank after install, disable the generated config and reboot: `sudo mv /etc/X11/xorg.conf /etc/X11/xorg.conf.disabled && sudo reboot`
*   **Input Lag**:
    *   Ensure Game Mode on your TV/Monitor is ON if connected (though less relevant for iPad).
    *   Use 5GHz Wi-Fi or a wired Ethernet adapter for the iPad for best results.
*   **Resolution Mismatch**:
    *   If the desktop looks stretched or has black bars, ensure the Linux desktop resolution matches the Moonlight stream resolution. You can change the Linux resolution via the Display Settings in the desktop environment (GNOME/KDE/XFCE) once you are connected.
*   **Permission Errors / No Encoder Found**:
    *   If you see errors like `Permission denied` for `/dev/dri/card*` or `Unable to create virtual mouse`, ensure your user is in the `video` and `input` groups.
    *   Run: `sudo usermod -aG video,input $USER` and **restart your computer**.
