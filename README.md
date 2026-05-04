# Mikan Remote

A simple iPhone app to remote-control a Mac over your local network. Designed for when you're on an exercise bike and want to watch Netflix or YouTube on your Mac's display.

## Features

- Trackpad-style mouse control from your iPhone
- Browser tab management — close tab, switch between tabs
- Video controls — play/pause, skip forward/backward, fullscreen, escape
- Volume control buttons (simulates Mac media keys)
- Configurable quick-action buttons (open URLs or apps via URL schemes, max 6)
- Default buttons for Apple TV (`videos://`), Netflix, and YouTube
- All settings adjustable from iPhone — sensitivity, cursor size, action buttons
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
   cd MikanServer
   xcodegen generate
   xcodebuild -scheme MikanServer -configuration Release build
   APP_PATH=$(xcodebuild -scheme MikanServer -configuration Release -showBuildSettings 2>/dev/null | grep " BUILT_PRODUCTS_DIR" | awk '{print $3}')
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

The server is the single source of truth. Changes from either side sync instantly via WebSocket; nothing is persisted on the iPhone.

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

The icon picker is a fixed list of SF Symbols (Apple TV, Play, Film, Music Note, Globe, Star, Heart, etc.). To add new icons, edit `iconChoices` in both `MikanRemote/MikanRemote/SettingsView.swift` and `MikanServer/MikanServer/ActionEditorView.swift` — the lists are intentionally kept identical so iPhone and Mac editors offer the same options.

## Project Structure

- `MikanServer/` — macOS menu bar app source (Xcode project, product bundle is `MikanRemoteServer.app`)
- `MikanRemote/` — iOS app (Xcode project)
- `MikanProtocol/` — Shared Swift Package defining WebSocket message types and the `Action` model
- `docs/testing-guide.md` — Detailed end-to-end test procedure
- `docs/superpowers/` — Design specs and implementation plans

Both Xcode projects are generated from `project.yml` via `xcodegen` — edit the YAML, regenerate, then build.

## License

MIT
