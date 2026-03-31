# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Mikan Remote is an iPhone-to-Mac remote control for streaming video. Trackpad-style mouse control plus configurable quick-action buttons, all over the local network via Bonjour discovery and WebSocket.

## Architecture

Three components:

- **MikanServer** (`MikanServer/`) — macOS menu bar app. Advertises via Bonjour, runs a WebSocket server (Network.framework), controls mouse/keyboard via CGEvent, simulates media keys, renders a custom cursor overlay, opens URLs via NSWorkspace. Built with xcodegen.
- **MikanRemote** (`MikanRemote/`) — iOS thin client. Discovers Mac via Bonjour, connects over WebSocket, provides trackpad surface (UIKit multi-touch) and action buttons. Auto-reconnects on foreground. No local state. Built with xcodegen.
- **MikanProtocol** (`MikanProtocol/`) — Swift Package shared by both apps. Defines `ClientMessage` (mouseMove, mouseClick, mouseScroll, openURL, performCommand), `ServerMessage`, `Action`, `MouseButton` as Codable types with flat JSON encoding using a `type` discriminator field.

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
# Then build and run to device from Xcode (Cmd+R)
```

## Important: Accessibility Permission

After each MikanServer rebuild and install, macOS invalidates the Accessibility permission even though System Settings still shows it as ON. The user must **toggle Accessibility OFF then ON** for MikanServer in System Settings > Privacy & Security > Accessibility after each new build. Without this, trackpad mouse control silently fails.

## Key Conventions

- Both Xcode projects use **xcodegen** — edit `project.yml`, then `xcodegen generate` to regenerate `.xcodeproj`. Sources are auto-discovered from the source directories.
- Deployment targets: macOS 14.0, iOS 17.0 (required for `@Observable`)
- WebSocket protocol: JSON messages with `"type"` field. See `MikanProtocol/Sources/MikanProtocol/Messages.swift`.
- MikanServer requires **Accessibility permission** for mouse/keyboard control via CGEvent (System Settings > Privacy & Security > Accessibility). Permission must be re-toggled after each rebuild.
- MikanRemote requires a **physical iPhone** for testing — simulator is impractical since mouse control and URL opening fight with the simulator on the same Mac.
- App icons: source SVGs at repo root (`icon.svg` for remote, `icon-server.svg` for server). Teal rings = server, orange rings = remote.

## Key Files

- Design spec: `docs/superpowers/specs/2026-03-29-mikan-remote-design.md`
- Implementation plan: `docs/superpowers/plans/2026-03-29-mikan-remote.md`
- Testing guide: `docs/testing-guide.md`
