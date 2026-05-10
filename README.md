# MikanRemote

A simple iPhone app to remote-control a Mac over your local network. Designed for when you're on an exercise bike and want to watch Netflix or YouTube on your Mac's display.

## Features

- Trackpad-style mouse control from your iPhone
- Browser tab management — close tab, switch between tabs
- Video controls — play/pause, skip forward/backward, fullscreen, escape
- **YouTube Controls popup** — chapter skip, playlist nav, captions, playback rate, ±5s seek, play/pause, fullscreen, all in a dedicated sheet (see below)
- **Utilities sheet** — screenshot (⇧⌘3 on Mac), one-tap paste-clipboard-to-Mac, typed URL → Mac (see below)
- **Share Sheet integration** — share any URL from Safari → MikanRemote and the Mac browser opens it
- Volume control buttons (simulates Mac media keys)
- Configurable quick-action buttons (open URLs or apps via URL schemes, max 6)
- Default buttons for Apple TV (`videos://`), Netflix, and YouTube
- All settings adjustable from iPhone — sensitivity, cursor size, action buttons, YouTube popup visibility
- Large custom cursor overlay — appears on movement, fades after 10s inactivity
- Automatic discovery via Bonjour — no IP address needed
- Security pairing — 4-digit code on first connect
- Auto-reconnects when app returns from background
- Menu bar app on Mac — stays out of the way, optional Launch at Login

## Requirements

- macOS 14.0+
- iOS 17.0+
- Both devices on the same local network
- Xcode 16+ and `xcodegen` (`brew install xcodegen`)

## Setup

### Mac (MikanRemoteServer)

1. (Optional but recommended) Copy `Local.xcconfig.example` to `Local.xcconfig` and set `BUNDLE_PREFIX` and `DEVELOPMENT_TEAM` so codesigning stays stable across rebuilds — otherwise macOS will keep re-prompting for Accessibility permission.
2. Build and install:
   ```bash
   cd MikanRemoteServer
   xcodegen generate
   xcodebuild -scheme MikanRemoteServer -configuration Release build
   APP_PATH=$(xcodebuild -scheme MikanRemoteServer -configuration Release -showBuildSettings 2>/dev/null | grep " BUILT_PRODUCTS_DIR" | awk '{print $3}')
   rm -rf /Applications/MikanRemoteServer.app && cp -R "$APP_PATH/MikanRemoteServer.app" /Applications/MikanRemoteServer.app
   ```
3. Launch `/Applications/MikanRemoteServer.app`. An antenna icon appears in the menu bar.
4. **Grant Accessibility permission** (required — CGEvent calls silently fail without it):
   - Click the menu bar icon. If permission isn't granted, an orange warning panel and a **Grant Permission** button appear at the top of the menu.
   - Click **Grant Permission**. macOS opens System Settings > Privacy & Security > Accessibility, and Finder reveals `MikanRemoteServer.app`.
   - Drag the app from the Finder window into the Accessibility list, then toggle it **on**.
   - The menu warning disappears automatically — no relaunch needed in most cases. If trackpad control still doesn't respond, quit and relaunch the server.
5. (Optional) Toggle **Launch at Login** in the menu so the server starts automatically when you log in.

### iPhone (MikanRemote)

1. Build to a physical iPhone (the simulator is impractical — it fights the Mac for cursor focus):
   ```bash
   cd MikanRemote
   xcodegen generate
   open MikanRemote.xcodeproj
   ```
2. In Xcode, set your development team under Signing & Capabilities, select your iPhone as the destination, and press **Cmd+R**.
3. On first launch, approve the **Local Network** prompt — Bonjour discovery requires it.
4. The iPhone auto-discovers and connects. On first connection, enter the 4-digit pairing code shown in the floating window on your Mac.

## Customizing

Tap the gear icon on iPhone, or click the Mac menu bar icon, to adjust:

- **Mouse sensitivity** (3.0x–20.0x, step 0.5)
- **Cursor overlay size** (60–300pt) — diameter of the soft halo
- **Cursor dot size** (1–15%) — center crosshair dot, as a percentage of the halo
- **Cursor gap size** (10–45%) — gap radius before the halo, as a percentage
- **Action buttons** — add, remove, reorder, edit label/URL/icon (max 6)
- **YouTube popup** — Auto / Always On / Always Off (see below)

The server is the single source of truth. Changes from either side sync instantly via WebSocket; nothing is persisted on the iPhone.

## YouTube Controls Popup

A dedicated sheet of YouTube web-player keyboard shortcuts you can pull up while a video is playing. Useful when you want to skip a chapter or bump playback speed without aiming the trackpad at small player controls.

### Opening it

A small red **▶︎** icon appears in the top status bar of the iPhone's main screen (between the Mac hostname and the gear icon). Tap it to open the popup. Tap **Done** in the top-right of the sheet — or swipe it down — to dismiss. The sheet **stays open across taps** so you can press `Faster >` three times to bump playback rate to 2.0× without having to re-open it.

### Buttons (top to bottom)

| Button | YouTube shortcut | What it does |
|---|---|---|
| Prev Video / Next Video | Shift+P / Shift+N | Move within a playlist |
| Prev Chapter / Next Chapter | Option+← / Option+→ | Jump to chapter markers (when present) |
| Captions | C | Toggle closed captions |
| Slower < / > Faster | Shift+, / Shift+. | Step playback rate down / up |
| Fullscreen | F | Toggle YouTube's player fullscreen (separate from macOS Ctrl+Cmd+F, which is still on the main screen) |
| Back 5s / Forward 5s | ← / → | Skip 5 seconds (same arrow keys the main remote uses) |
| Play / Pause | K | Toggle playback |

These all assume YouTube is the focused tab/window on the Mac when you tap. If a different app is in front, the keystrokes go there.

### Visibility setting

The launcher icon's visibility is controlled by a 3-state setting available on **both** the iPhone (gear icon → settings sheet → "YouTube Controls") and the Mac menu bar ("YouTube Popup" picker):

- **Auto** (default) — the icon shows only when one of your action buttons points at YouTube (`youtube.com`, `youtu.be`, or `m.youtube.com`). Delete the YouTube action and the icon disappears; add one back and it reappears.
- **Always On** — icon is always visible, even with no YouTube action button.
- **Always Off** — icon is hidden regardless.

The setting persists on the Mac (server is the single source of truth) and syncs to the iPhone whenever it changes.

## Utilities Sheet

A wrench icon (`🔧`) in the top status bar (between the YouTube launcher and the gear) opens the Utilities sheet — a small toolbox for one-off actions that aren't part of the main remote flow.

### Buttons

- **Take Screenshot** — fires ⇧⌘3 on the Mac (full-screen capture to the desktop).
- **Paste** — reads a URL from the iPhone clipboard and tells the Mac to open it. Uses SwiftUI `PasteButton`, so iOS doesn't show the "Pasted from <app>" privacy toast.
- **URL textbox + Send** — type or paste a URL, tap Send, the Mac opens it. Send is disabled until the URL parses and a connection is available.

All three reuse the existing `openURL` / `performCommand` WebSocket messages — no separate plumbing on the server side. The screenshot button used to live in Settings; it has moved here.

## Share Extension (Share-to-Mac)

MikanRemote registers as a destination in the iOS share sheet for URL shares. From Safari (or any app with a URL share), tap Share → MikanRemote and the Mac browser opens that URL.

### How it works

1. iOS launches the extension; it writes the URL into an App Group container (`group.<bundle-prefix>.mikanremote`).
2. The extension opens `mikanremote://share`, which brings the main MikanRemote app to the foreground.
3. The main app reads the URL from the App Group and forwards it via the existing `openURL` WebSocket message.
4. If the WebSocket isn't ready yet (the iPhone often needs 0–5 seconds to reconnect after foregrounding), the app shows a "Sending to <hostname>…" banner and drains the URL as soon as the connection is up.
5. On a 10-second timeout, the banner switches to "Couldn't reach Mac — Retry". The URL stays queued until you retry or close the app.

A second share before the first drains overwrites — only the latest URL is sent. There is no queue.

The Share Extension and main app must share an App Group entitlement. xcodegen wires this up from `MikanRemote/MikanRemote.entitlements` and `MikanRemote/MikanRemoteShare.entitlements`, both using `group.$(BUNDLE_PREFIX).mikanremote`. First build to device may prompt to register the App Group with the developer portal.

## Adding Action Buttons

You can edit action buttons from either the iPhone or the Mac. The result is the same — the server persists actions and pushes them to the iPhone.

### From the iPhone

1. Tap the **gear icon** in the top right of the trackpad screen.
2. Scroll to the **Action Buttons** section.
3. Tap **Add Action** (only visible when fewer than 6 actions exist) — a new row appears with placeholder values.
4. Edit:
   - **Label** — what shows on the button (e.g. `HBO`).
   - **URL** — see URL formats below.
   - **Icon** — pick an SF Symbol from the dropdown, or `None` to show the label only.
5. To **reorder** or **delete**, tap **Edit** in the top right of the settings sheet, then drag handles or swipe rows.
6. Tap **Done** — the change is pushed to the server, persisted, and the trackpad screen updates immediately.
7. To restore the defaults, scroll to the bottom and tap **Reset Actions to Defaults**.

### From the Mac

1. Click the menu bar icon and choose **Edit Actions...**
2. The editor opens as a window. Use **+** to add a row, **−** to remove the selected row, drag rows to reorder, edit label/URL/icon inline.
3. Click **Save** (or press **Cmd+Return**) to persist and push to the iPhone.

### URL Formats

Actions can target any URL macOS knows how to open:

- **Web pages** — `https://www.youtube.com/feed/playlists`, `https://netflix.com`, `https://www.hbomax.com`. These open in your default browser.
- **App URL schemes** — many native macOS apps register a custom scheme that launches the app:
  - `videos://` — Apple TV
  - `music://` — Apple Music
  - `podcasts://` — Apple Podcasts
- **Deep links** — some apps accept paths after the scheme (e.g. `videos://library`). Behavior depends on the app.

If you don't know an app's URL scheme, the simplest test is to type it into Safari's address bar — if the app launches, the scheme works as an action URL.

### Icons

The icon picker is a fixed list of SF Symbols (Apple TV, Play, Film, Music Note, Globe, Star, Heart, etc.). To add new icons, edit `iconChoices` in both `MikanRemote/MikanRemote/SettingsView.swift` and `MikanRemoteServer/MikanRemoteServer/ActionEditorView.swift` — the lists are intentionally kept identical so iPhone and Mac editors offer the same options.

## Project Structure

- `MikanRemoteServer/` — macOS menu bar app source (Xcode project, product bundle is `MikanRemoteServer.app`)
- `MikanRemote/` — iOS app (Xcode project)
- `MikanProtocol/` — Shared Swift Package defining WebSocket message types and the `Action` model
- `docs/testing-guide.md` — Detailed end-to-end test procedure
- `docs/superpowers/` — Design specs and implementation plans

Both Xcode projects are generated from `project.yml` via `xcodegen` — edit the YAML, regenerate, then build.

## License

MIT
