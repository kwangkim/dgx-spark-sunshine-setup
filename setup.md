# Setting up Moonlight on iPad with Sunshine

This guide explains how to connect your iPad to the Sunshine streaming server running on your DGX Spark system.

## Prerequisites

1.  **Sunshine Running**: Ensure Sunshine is installed and running on your DGX Spark system.
    *   Verify by accessing the Web UI at `https://<YOUR_DGX_IP>:47990`.
2.  **Network**: Your iPad and DGX Spark must be on the same network, or accessible via VPN/ZeroTier/Tailscale.

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
    *   Ensure the HDMI dummy plug is connected if the system is headless.
    *   Check if the X server is running: `systemctl status display-manager`.
*   **Input Lag**:
    *   Ensure Game Mode on your TV/Monitor is ON if connected (though less relevant for iPad).
    *   Use 5GHz Wi-Fi or a wired Ethernet adapter for the iPad for best results.
*   **Resolution Mismatch**:
    *   If the desktop looks stretched or has black bars, ensure the Linux desktop resolution matches the Moonlight stream resolution. You can change the Linux resolution via the Display Settings in the desktop environment (GNOME/KDE/XFCE) once you are connected.
*   **Permission Errors / No Encoder Found**:
    *   If you see errors like `Permission denied` for `/dev/dri/card*` or `Unable to create virtual mouse`, ensure your user is in the `video` and `input` groups.
    *   Run: `sudo usermod -aG video,input $USER` and **restart your computer**.
