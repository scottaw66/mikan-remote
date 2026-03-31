# Mikan Remote — Testing Guide

## Prerequisites

- Xcode 16+ with matching iOS platform installed
- xcodegen (`brew install xcodegen` if not already installed)
- macOS 14.0+
- A physical iPhone (iOS 17.0+) on the same Wi-Fi network as your Mac
- An Apple Developer account (free or paid) for signing the iOS app to your device

## Part 1: MikanServer (Mac)

MikanServer is already built and installed at `/Applications/MikanServer.app`. Just double-click to launch.

If you need to rebuild from source:

```bash
cd MikanServer
xcodegen generate
xcodebuild -scheme MikanServer -configuration Release build

# Copy to Applications
APP_PATH=$(xcodebuild -scheme MikanServer -configuration Release -showBuildSettings 2>/dev/null | grep " BUILT_PRODUCTS_DIR" | awk '{print $3}')
cp -R "$APP_PATH/MikanServer.app" /Applications/MikanServer.app
```

### First Launch — Grant Accessibility Permission

MikanServer needs Accessibility permission to control the mouse. CGEvent calls silently fail without it — there's no prompt.

1. Go to **System Settings > Privacy & Security > Accessibility**
2. Click the **+** button, navigate to `/Applications/MikanServer.app`, and add it
3. Toggle it **on**
4. Quit and relaunch MikanServer

### Verify It's Running

- An **antenna icon** appears in the menu bar (slashed when no client is connected)
- Click it — you should see "Waiting for connection..."

## Part 2: MikanRemote (iPhone)

The iOS app must be run on a physical iPhone. The simulator won't work for this project — moving the cursor and opening URLs on the same Mac you're using the simulator on makes testing impossible.

### Build and Deploy to iPhone

```bash
cd MikanRemote
xcodegen generate
open MikanRemote.xcodeproj
```

In Xcode:

1. Connect your iPhone via USB (or set up wireless debugging)
2. Select the **MikanRemote** scheme
3. Select your **iPhone** as the destination (not a simulator)
4. If prompted, set a development team in **Signing & Capabilities** (your Apple ID works for free provisioning)
5. Press **Cmd+R** to build and run on the device

### Approve Local Network Access

On first launch, iOS will prompt:

> "MikanRemote would like to find and connect to devices on your local network."

Tap **Allow**. Without this, Bonjour discovery won't work.

## Part 3: Testing

Make sure your Mac and iPhone are on the **same Wi-Fi network**.

### Connection

1. Launch MikanServer on your Mac (if not already running)
2. Launch MikanRemote on your iPhone
3. The app should show "Scanning for Mikan servers..."
4. Within a few seconds, it auto-connects
5. The status bar shows a green dot and your Mac's hostname
6. The Mac menu bar icon changes to the connected antenna (no slash)

### Mouse Control

On the trackpad area (large gray rounded rectangle on the iPhone):

- **Drag finger** → cursor moves on Mac (a large orange cursor overlay appears)
- **Single tap** → left click
- **Two-finger drag** → scroll

The custom cursor overlay auto-hides after 10 seconds of no movement.

### Command & Action Buttons

- **Vol−** / **Vol+** → Mac system volume (icon-only buttons)
- **Fullscreen** → toggles macOS fullscreen (Ctrl+Cmd+F)
- **Escape** → sends Escape key
- **Netflix** / **YouTube** → open URLs in default browser on Mac

### Action Editor

1. On your Mac, click the **Mikan menu bar icon**
2. Click **Edit Actions...**
3. Add a new action (click **+**), set a label and URL, click **Save**
4. The new button should appear on the iPhone immediately — no reconnect needed

### Reconnection

1. Quit MikanServer on Mac (menu bar > Quit)
2. iPhone should show scanning/disconnected state
3. Relaunch MikanServer
4. iPhone auto-reconnects within a few seconds

### Background/Foreground Reconnection

1. Switch away from MikanRemote (go to home screen or another app)
2. Wait 30+ seconds
3. Switch back to MikanRemote
4. App should automatically reconnect without needing to kill and relaunch

## Troubleshooting

**iPhone doesn't discover the Mac:**
- Ensure both devices are on the same Wi-Fi network
- Ensure MikanServer is running (check for menu bar icon)
- Ensure you approved the local network permission on the iPhone
- Try Settings > Apps > MikanRemote > Local Network and toggle it on

**Cursor doesn't move when dragging:**
- Grant Accessibility permission to MikanServer (see Part 1)
- Quit and relaunch MikanServer after granting

**Can't build to iPhone — signing error:**
- In Xcode, select the MikanRemote target > Signing & Capabilities
- Set Team to your Apple ID
- If using free provisioning, you may need to change the bundle ID to something unique

**Action buttons don't appear:**
- Check the Xcode console for the iPhone run — look for connection messages
- Verify MikanServer has actions configured (Edit Actions... > Reset to Defaults > Save)

**xcodegen not found:**
```bash
brew install xcodegen
```
