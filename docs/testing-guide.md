# MikanRemote — Testing Guide

## Prerequisites

- Xcode 16+ with matching iOS platform installed
- xcodegen (`brew install xcodegen` if not already installed)
- macOS 14.0+
- A physical iPhone (iOS 17.0+) on the same Wi-Fi network as your Mac
- An Apple Developer account (free or paid) for signing the iOS app to your device

## Part 1: MikanRemoteServer (Mac)

The server source directory and target are both `MikanRemoteServer`, and the built product is `MikanRemoteServer.app`. The recommended install location is `/Applications/MikanRemoteServer.app`. Just double-click to launch.

### Optional: stable code signing

Copy `Local.xcconfig.example` (at the repo root) to `Local.xcconfig` and set:

```
BUNDLE_PREFIX = com.yourname
DEVELOPMENT_TEAM = ABCDE12345
```

This keeps the codesigning identity stable across rebuilds, so macOS doesn't drop the Accessibility permission and re-prompt every time.

### Build from source

```bash
cd MikanRemoteServer
xcodegen generate
xcodebuild -scheme MikanRemoteServer -configuration Release build

# Copy to /Applications
APP_PATH=$(xcodebuild -scheme MikanRemoteServer -configuration Release -showBuildSettings 2>/dev/null | grep " BUILT_PRODUCTS_DIR" | awk '{print $3}')
rm -rf /Applications/MikanRemoteServer.app && cp -R "$APP_PATH/MikanRemoteServer.app" /Applications/MikanRemoteServer.app
```

### First Launch — Grant Accessibility Permission

MikanRemoteServer needs Accessibility permission to control the mouse. CGEvent calls silently fail without it.

The menu bar icon shows the in-app accessibility flow:

1. Click the menu bar antenna icon. If permission isn't granted, an orange warning panel appears at the top of the menu with a **Grant Permission** button.
2. Click **Grant Permission**. macOS opens **System Settings > Privacy & Security > Accessibility**, and Finder is brought forward with `MikanRemoteServer.app` highlighted.
3. Drag `MikanRemoteServer.app` from the Finder window into the Accessibility list (or click **+** in System Settings and pick it).
4. Toggle the entry **on**.
5. The orange warning in the menu disappears within ~2 seconds (the server polls the trust state). In most cases you do not need to relaunch. If trackpad control still doesn't respond, quit and relaunch.

### Optional: Launch at Login

In the menu bar dropdown, toggle **Launch at Login** so the server starts automatically when you log into your Mac. Uses `SMAppService` — the entry shows up under System Settings > General > Login Items.

### Verify It's Running

- An **antenna icon** appears in the menu bar (slashed when no client is connected, solid when connected)
- Click it — you should see "Waiting for connection..."

## Part 2: MikanRemote (iPhone)

The iOS app must be run on a physical iPhone. The simulator won't work — moving the cursor and opening URLs on the same Mac you're using the simulator on makes testing impossible.

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

1. Launch MikanRemoteServer on your Mac (if not already running)
2. Launch MikanRemote on your iPhone
3. The app should show "Scanning for Mikan servers..."
4. Within a few seconds, it auto-connects
5. The status bar shows a green dot and your Mac's hostname
6. The Mac menu bar icon changes to the connected antenna (no slash)

### Security Pairing (First Connection)

The first time a device connects, the server requires a one-time pairing code:

1. On the iPhone, an "Enter Pairing Code" screen appears
2. On the Mac, a floating window shows a 4-digit code
3. Type the code into the iPhone and tap **Pair**
4. On success the normal trackpad UI appears
5. Subsequent connections from the same device skip pairing automatically

To force re-pairing: click the menu bar icon on the Mac and choose **Unpair All Devices**.

### Mouse Control

On the trackpad area (large gray rounded rectangle on the iPhone):

- **Drag finger** → cursor moves on Mac (a red cursor overlay appears)
- **Single tap** → left click (right-click is not supported and must never be added)
- **Two-finger drag** → scroll

The cursor overlay auto-hides after 10 seconds of no movement. Its size, dot size, and gap size are adjustable from either the Mac menu bar or the iPhone settings sheet.

### Command & Action Buttons

Above the trackpad (compact row):
- **Close tab** (Cmd+W) / **Prev tab** / **Next tab**
- **Vol−** / **Vol+** → Mac system volume

Below the trackpad (command row):
- **Left arrow** / **Right arrow** → seek video ±5 seconds (YouTube, etc.)
- **Play/Pause** → media key
- **Fullscreen** → toggles macOS fullscreen (Ctrl+Cmd+F)
- **Escape** → sends Escape key

App shortcut buttons (smaller, below commands, 2 per row, max 6):
- Defaults: **Apple TV**, **Netflix**, **YouTube**

### YouTube Controls Popup

A small red `▶︎` icon in the top status bar (between hostname and gear) opens a modal sheet of YouTube web-player keyboard shortcuts. The sheet stays open until you tap **Done** so multi-taps (e.g. `Faster >` three times) work cleanly.

**Buttons:** Prev/Next Video (Shift+P / Shift+N), Prev/Next Chapter (Option+arrow), Captions (C), Slower / Faster (Shift+, / Shift+.), Fullscreen (F — YouTube's player fullscreen, distinct from native Ctrl+Cmd+F), Back 5s / Forward 5s (left/right arrow), Play/Pause (K).

**Launcher visibility** is a 3-state setting (Auto / Always On / Always Off):
- iPhone: gear icon → settings sheet → "YouTube Controls" segmented picker.
- Mac: menu bar → "YouTube" / "Popup" picker.
- **Auto** shows the launcher iff at least one action button URL contains `youtube.com` or `youtu.be` (case-insensitive).
- The setting is server-stored (`youtubePopupMode` on `settingsSync` / `updateSettings`) and dual-editable.

**Verifying:**

1. With the default action set (which includes a YouTube action) and mode set to **Auto**, the red `▶︎` appears on the iPhone main screen.
2. Open YouTube in Safari on the Mac, start a video, tap the launcher.
3. Tap each button and confirm the expected behavior in YouTube — chapter skip, captions toggle, playback rate change, etc.
4. Delete the YouTube action via Edit Actions; the launcher disappears within ~1 second. Add it back; the launcher reappears.
5. Change the mode picker on either side; the other side reflects the change.
6. Quit and relaunch MikanRemoteServer; the persisted mode is restored.

### Utilities Sheet

A wrench icon (`🔧`) in the top status bar (between the YouTube launcher and the gear) opens a sheet with these controls:

- **Take Screenshot** — fires `performCommand("screenshot")` → server hits ⇧⌘3.
- **Audio Output** — lists the Mac's output devices; tapping one sends `setAudioDevice(deviceId:)` and the server switches the default output. The current device shows a checkmark; the list updates live.
- **Paste** — SwiftUI `PasteButton(payloadType: URL.self)` — reads a URL from the clipboard and sends `openURL`. No "Pasted from <app>" privacy toast.
- **Type a URL + Send** — `URL(string:)`-validated; Send is disabled while the field is empty/invalid or while disconnected.

**Verifying:**

1. With at least one action button (any URL), open the Utilities sheet. The screenshot button works → expect a screenshot on the Mac desktop and the shutter sound.
2. Copy any URL in Safari on the iPhone (e.g. tap and hold, "Copy"). Reopen MikanRemote (Utilities sheet may have closed) — tap **Paste**. The Mac's default browser opens the URL. No iOS privacy toast appears.
3. In the textbox, type `https://example.com` → tap **Send** → Mac browser opens it, field clears, "Sent" indicator briefly appears.
4. Try empty text and `not a url` → **Send** is disabled.
5. With the sheet open, drop the connection (quit MikanRemoteServer on the Mac) → both **Paste** and **Send** become disabled (greyed) within ~5s (matches the heartbeat-based disconnect detection). Re-launch the server; controls re-enable once the green dot reappears.

**Verifying Audio Output:**

1. Open the Utilities sheet. The **Audio Output** section lists the Mac's output devices with a checkmark on the current default.
2. Tap a different device. The Mac's output actually switches (play audio, or check System Settings > Sound) and the checkmark moves within a moment.
3. Live updates: with the sheet open, plug in or unplug headphones / connect AirPods → the list updates without reopening the sheet. Then change the output from the macOS menu-bar Sound control → the iPhone checkmark follows.
4. Drop the connection → the rows disable / the section shows "No devices". Reconnect → the list repopulates.

### Share Extension (Share-to-Mac)

MikanRemote appears in the iOS share sheet for URL shares (Safari, YouTube app, Reddit, anywhere with a URL). Selecting it writes the URL to the App Group, opens `mikanremote://share` to bring the main app forward, and the dispatcher sends `openURL` to the Mac.

**App Group setup (one-time per device):**

In Xcode, both `MikanRemote` and `MikanRemoteShare` targets must have the **App Groups** capability with `group.<bundle-prefix>.mikanremote` enabled. If the first device build fails with provisioning errors, open Signing & Capabilities for each target → click `+ Capability` → **App Groups** → add the group. Xcode may prompt to register it with the developer portal; accept.

**Verifying:**

1. **Happy path.** Open Safari on iPhone, share a YouTube link → MikanRemote. Expected: Mac browser opens the URL within ~1 second. No "Sending…" banner is visible because the WS is hot.
2. **Cold reconnect.** Force-quit MikanRemote (swipe up from app switcher). Share a URL. Expected: app launches, "Sending to <hostname>…" banner shows above the trackpad while the WS reconnects (0–5 seconds), then "Sent ✓" briefly, then disappears. Mac opens the URL.
3. **Timeout + Retry.** Force-quit MikanRemote, disconnect the Mac from the network. Share a URL. Wait ≥10 seconds. Expected: banner shows "Couldn't reach Mac — Retry". Reconnect the Mac; wait for the iPhone's green dot. Tap **Retry**. Mac opens the URL.
4. **Latest-wins overwrite.** Disconnect the Mac. Share URL #1 from Safari (it queues in the App Group). Without reconnecting, share URL #2 (overwrites). Reconnect the Mac. Expected: only URL #2 opens on the Mac.

The dispatcher's state machine is unit-tested (`PendingShareDispatcherTests`) so the timing behaviors above are covered automatically. Real-device verification is mostly to confirm the App Group plumbing and `mikanremote://` handoff work in practice.

### Adding / Editing Action Buttons

Actions can be edited from either side — the server is authoritative.

**From the iPhone:**

1. Tap the **gear icon** at the top right.
2. Scroll to the **Action Buttons** section.
3. Tap **Add Action** to append a new row (only enabled while fewer than 6 actions exist).
4. Edit the row:
   - **Label** — what shows on the button.
   - **URL** — a web URL (`https://...`) or an app URL scheme (`videos://`, `music://`, `podcasts://`).
   - **Icon** — pick an SF Symbol or `None`.
5. Tap **Edit** in the top-right of the sheet to drag-reorder or swipe-delete rows.
6. Tap **Done** — the change is pushed to the server (`updateActions`), persisted, and the trackpad refreshes.
7. **Reset Actions to Defaults** at the bottom restores Apple TV / Netflix / YouTube.

**From the Mac:**

1. Click the menu bar icon, then **Edit Actions...**
2. Use **+** / **−**, drag to reorder, edit fields inline.
3. Click **Save** (or press **Cmd+Return**) — pushes `actionConfig` to the iPhone immediately.

**Verifying a new action:**

1. Add an action with a known scheme (e.g. `videos://` and label "Apple TV").
2. Save.
3. The new button should appear on the iPhone within 1 second — no reconnect needed.
4. Tap the button on the iPhone — the server opens the URL via `NSWorkspace.shared.open`. For a scheme, the corresponding app launches. For an `https://` URL, the default browser opens it.

### Reconnection

1. Quit MikanRemoteServer on Mac (menu bar > Quit)
2. iPhone should show scanning/disconnected state
3. Relaunch MikanRemoteServer
4. iPhone auto-reconnects within a few seconds

### Disconnect Detection

1. Connect MikanRemote to MikanRemoteServer
2. On the Mac, verify the menu bar shows "Connected: iPhone"
3. On the iPhone, swipe-kill MikanRemote from the app switcher
4. Within ~5 seconds, the Mac menu bar should update to "Waiting for connection..." (5-second WebSocket ping with no pong drops the connection).

### Background/Foreground Reconnection

1. Switch away from MikanRemote (go to home screen or another app)
2. Wait 30+ seconds
3. Switch back to MikanRemote
4. App should automatically reconnect without needing to kill and relaunch

## Troubleshooting

**iPhone doesn't discover the Mac:**
- Ensure both devices are on the same Wi-Fi network
- Ensure MikanRemoteServer is running (check for menu bar icon)
- Ensure you approved the local network permission on the iPhone
- Try Settings > Apps > MikanRemote > Local Network and toggle it on

**Cursor doesn't move when dragging:**
- Click the menu bar icon — if the orange Accessibility warning is showing, follow the **Grant Permission** flow above.
- If permission was already granted, try toggling the entry off then on in System Settings > Privacy & Security > Accessibility (rare — usually only needed if you rebuilt the app with a different signing identity).
- Setting `DEVELOPMENT_TEAM` in `Local.xcconfig` prevents this from happening on future rebuilds.

**Pairing code window doesn't appear on Mac:**
- The pairing window opens automatically when a new client connects. If it doesn't appear, check the menu bar status text — it will say "Waiting for connection..." if no client has connected yet.

**iPhone stuck on pairing screen after entering correct code:**
- Verify the code matches exactly what the Mac floating window shows
- If you entered a wrong code first, try again — the same code remains valid

**Can't build to iPhone — signing error:**
- In Xcode, select the MikanRemote target > Signing & Capabilities
- Set Team to your Apple ID
- If using free provisioning, you may need to change the bundle ID to something unique (set `BUNDLE_PREFIX` in `Local.xcconfig`)

**Action buttons don't appear:**
- Check the Xcode console for the iPhone run — look for connection messages
- Verify MikanRemoteServer has actions configured (Edit Actions... > Reset to Defaults > Save)

**Action button does nothing when tapped:**
- Confirm the URL works in Safari on the Mac — type it directly into the address bar. If Safari can't open it, neither can the server.
- App URL schemes only work if the target app is installed (e.g. `videos://` needs Apple TV).

**Launch at Login toggle doesn't stick:**
- The toggle uses `SMAppService.mainApp.register()`. If macOS rejects the registration silently, check Console.app for errors from `com.apple.servicemanagement`. A common cause is running the app from a non-`/Applications` location — install to `/Applications/MikanRemoteServer.app` and try again.

**xcodegen not found:**
```bash
brew install xcodegen
```
