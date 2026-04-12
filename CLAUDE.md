# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Mikan Remote is an iPhone-to-Mac remote control for streaming video. Trackpad-style mouse control plus configurable quick-action buttons, all over the local network via Bonjour discovery and WebSocket.

## Architecture

Three components:

- **MikanServer** (`MikanServer/`) — macOS menu bar app. Advertises via Bonjour, runs a WebSocket server (Network.framework), controls mouse/keyboard via CGEvent, simulates media keys, renders a custom cursor overlay, opens URLs via NSWorkspace. Manages device pairing (PairingStore persists paired UUIDs to disk). Built with xcodegen.
- **MikanRemote** (`MikanRemote/`) — iOS thin client. Discovers Mac via Bonjour, connects over WebSocket, provides trackpad surface (UIKit multi-touch), action buttons, and a settings sheet for adjusting sensitivity, cursor size, and action buttons. Auto-reconnects on foreground. No local state — server is the single source of truth. Built with xcodegen.
- **MikanProtocol** (`MikanProtocol/`) — Swift Package shared by both apps. Defines `ClientMessage` (mouseMove, mouseClick, mouseScroll, openURL, performCommand, hello, pairResponse, updateSettings, updateActions), `ServerMessage` (actionConfig, serverStatus, pairRequired, pairAccepted, pairRejected, settingsSync), and `Action` as Codable types with flat JSON encoding using a `type` discriminator field.

## Build Commands

```bash
# MikanProtocol tests
cd MikanProtocol && swift test

# MikanServer (macOS) — build and install
cd MikanServer && xcodegen generate && xcodebuild -scheme MikanServer -configuration Release build
# Copy built app to /Applications:
APP_PATH=$(xcodebuild -scheme MikanServer -configuration Release -showBuildSettings 2>/dev/null | grep " BUILT_PRODUCTS_DIR" | awk '{print $3}')
rm -rf /Applications/MikanServer.app && cp -R "$APP_PATH/MikanServer.app" /Applications/MikanServer.app

# MikanRemote (iOS) — must deploy to physical iPhone (not simulator)
cd MikanRemote && xcodegen generate && open MikanRemote.xcodeproj
# Then build and run to device from Xcode (Cmd+R) — scheme defaults to Release with no debugger
```

## Important: Accessibility Permission

MikanServer requires Accessibility permission for mouse/keyboard control. Grant it once in System Settings > Privacy & Security > Accessibility. If trackpad control silently stops working after a rebuild, try toggling the permission OFF then ON.

## Key Conventions

- Both Xcode projects use **xcodegen** — edit `project.yml`, then `xcodegen generate` to regenerate `.xcodeproj`. Sources are auto-discovered from the source directories.
- Deployment targets: macOS 14.0, iOS 17.0 (required for `@Observable`)
- WebSocket protocol: JSON messages with `"type"` field. See `MikanProtocol/Sources/MikanProtocol/Messages.swift`.
- MikanServer requires **Accessibility permission** for mouse/keyboard control via CGEvent (System Settings > Privacy & Security > Accessibility). If control stops working after a rebuild, toggle the permission off and on.
- MikanRemote requires a **physical iPhone** for testing — simulator is impractical since mouse control and URL opening fight with the simulator on the same Mac.
- MikanRemote run scheme is configured for **Release with no debugger** — do not change this.
- App icons: source SVGs at repo root (`icon.svg` for remote, `icon-server.svg` for server). Teal rings = server, orange rings = remote.
- **No right-click.** Right-click is permanently removed from the protocol, server, and client. The `MouseButton` enum no longer exists. `mouseClick` has no parameter — it is always a left click. Do NOT reintroduce right-click under any circumstances.
- **Security pairing:** On first connect, the server generates a 4-digit code shown in a floating window. The client sends `hello(deviceId:)` on connect; unknown devices receive `pairRequired` and must submit the code via `pairResponse`. Paired UUIDs are stored in `~/Library/Application Support/MikanServer/paired-devices.json`. Use "Unpair All Devices" in the menu bar to reset.
- **Client settings:** Sensitivity, cursor size, and action buttons are configurable from both the iPhone (gear icon → settings sheet) and the Mac menu bar. The server is the single source of truth — it pushes `settingsSync` and `actionConfig` on connect and on change. The client sends `updateSettings` or `updateActions` when the user makes changes. No client-side persistence.
- **Cursor overlay size** is configurable from iPhone or server menu bar (60–300pt range, step 20, persisted to UserDefaults). Default is 140pt.
- **Mouse sensitivity** is configurable from iPhone or server menu bar (3.0–20.0, step 0.5, persisted to UserDefaults). Default is 10.0.
- **Action buttons** are limited to 6 max, displayed 2 per row on iPhone. Editable from iPhone settings sheet (label, URL, icon picker) or server Edit Actions window. Buttons can open URLs (browser) or app URL schemes (e.g. `videos://` for Apple TV). Defaults: Apple TV, Netflix, YouTube.
- **Command buttons:** closeTab (Cmd+W), prevTab (Cmd+Shift+[), nextTab (Cmd+Shift+]), volumeUp, volumeDown, fullscreen (Ctrl+Cmd+F), arrowLeft, arrowRight, playPause (media key), escape.
- **Networking** runs on a background queue — do not dispatch back to MainActor unnecessarily; the existing pattern uses `DispatchQueue.main.async` only for UI updates.
- **WebSocket keepalive:** The server sends WebSocket pings every 5 seconds. If a pong is not received (e.g. client app killed), the connection is immediately dropped.
- **Settings UI must be behind deliberate taps** (gear icon → sheet), never swipeable or inline — the app is used during exercise and accidental triggers must be avoided.

## Key Files

- Design specs: `docs/superpowers/specs/`
- Implementation plans: `docs/superpowers/plans/`
- Testing guide: `docs/testing-guide.md`
