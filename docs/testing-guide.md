# Mikan Remote — Testing Guide

## Prerequisites

- Xcode 16+ (with matching iOS simulator runtime installed)
- xcodegen (`brew install xcodegen` if not already installed)
- macOS 14.0+

## Part 1: MikanServer (Mac)

### Build and Run from Xcode

```bash
cd MikanServer
xcodegen generate
open MikanServer.xcodeproj
```

In Xcode, select the **MikanServer** scheme and press **Cmd+R** to build and run.

### Build from Command Line and Run as App Bundle

```bash
cd MikanServer
xcodegen generate
xcodebuild -scheme MikanServer -configuration Debug build
```

The built app bundle lands in DerivedData. To find it and copy it somewhere convenient:

```bash
# Find the built .app
APP_PATH=$(xcodebuild -scheme MikanServer -configuration Debug -showBuildSettings 2>/dev/null | grep " BUILT_PRODUCTS_DIR" | awk '{print $3}')
cp -R "$APP_PATH/MikanServer.app" ~/Desktop/MikanServer.app
```

Then double-click `MikanServer.app` on your Desktop to launch it. You can also drag it to `/Applications` if you want.

### First Launch — Grant Accessibility Permission

On first run, MikanServer needs Accessibility permission to control the mouse:

1. macOS will **not** prompt automatically — CGEvent calls silently fail without permission
2. Go to **System Settings > Privacy & Security > Accessibility**
3. Click the **+** button, navigate to the MikanServer app, and add it
4. Toggle it **on**
5. You may need to quit and relaunch MikanServer for the permission to take effect

### Verify It's Running

- A menu bar icon appears: **antenna icon** (with a slash when no client is connected)
- Click it — you should see "Waiting for connection..."
- Check Console.app or the Xcode debug console for: `Mikan server listening on port XXXXX`

## Part 2: MikanRemote (iOS Simulator)

### Install iOS Simulator Runtime (if needed)

If you see "no destinations found" errors when building:

1. Open **Xcode > Settings > Components** (or Platforms)
2. Download the **iOS simulator runtime** that matches your Xcode version
3. Wait for the download to complete (~5-10 GB)

### Build and Run

```bash
cd MikanRemote
xcodegen generate
open MikanRemote.xcodeproj
```

In Xcode:

1. Select the **MikanRemote** scheme
2. Pick a simulator destination (e.g., **iPhone 16**)
3. Press **Cmd+R** to build and run

### Approve Local Network Access

When the app launches in the simulator, iOS will prompt:

> "MikanRemote would like to find and connect to devices on your local network."

Tap **Allow**. Without this, Bonjour browsing won't work.

## Part 3: Testing the Connection

### Automatic Discovery

With MikanServer running on your Mac and MikanRemote in the simulator:

1. MikanRemote should show "Scanning for Mikan servers..."
2. Within a few seconds, it should auto-connect (since there's one server)
3. The status bar shows a green dot and your Mac's hostname
4. The menu bar icon on Mac changes to the connected antenna (no slash)
5. Click the menu bar icon — it should show "Connected: ..."

### Testing Mouse Control

In the simulator, interact with the trackpad area (the large gray rounded rectangle):

- **Click and drag** on the trackpad area → cursor moves on your Mac
- **Single tap** → left click at the current cursor position
- **Option+tap** (hold Option for second touch) → right click
- **Option+drag** → scroll

Note: Since the simulator runs on the same Mac, you're controlling your own cursor. This can feel recursive — the cursor moves while you're trying to use the simulator. This is expected and normal for local testing.

### Testing Action Buttons

- Default buttons should appear at the bottom: **Netflix** and **YouTube**
- Tap **Netflix** → your default browser opens netflix.com
- Tap **YouTube** → your default browser opens youtube.com

### Testing Action Editor

1. Click the **Mikan menu bar icon** on your Mac
2. Click **Edit Actions...**
3. The action editor window opens
4. Add a new action (click **+**), set a label and URL
5. Click **Save**
6. The new button should appear on the iPhone immediately (no reconnect needed)

### Testing Reconnection

1. Quit MikanServer (menu bar icon > Quit)
2. MikanRemote should show "Scanning for Mikan servers..." or "Connecting..."
3. Relaunch MikanServer
4. MikanRemote should auto-reconnect within a few seconds

## Troubleshooting

**"No destinations found" when building MikanRemote:**
Install the iOS simulator runtime via Xcode > Settings > Components.

**Simulator doesn't discover the Mac server:**
- Ensure MikanServer is running (check for the menu bar icon)
- Check that you approved the local network permission prompt in the simulator
- Try resetting the simulator (Device > Erase All Content and Settings) and relaunch

**Cursor doesn't move when dragging on trackpad:**
- Grant Accessibility permission to MikanServer (see Part 1)
- Quit and relaunch MikanServer after granting permission

**Action buttons don't appear:**
- Check the Xcode console for MikanRemote — look for `actionConfig` messages
- Verify MikanServer has a valid `actions.json` (or reset to defaults in the editor)

**xcodegen not found:**
```bash
brew install xcodegen
```
