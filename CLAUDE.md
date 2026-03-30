# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Mikan Remote is an iPhone-to-Mac remote control for streaming video. Trackpad-style mouse control plus configurable quick-action buttons, all over the local network via Bonjour discovery and WebSocket.

## Architecture

Three components:

- **MikanServer** (`MikanServer/`) — macOS menu bar app. Advertises via Bonjour, runs a WebSocket server (Network.framework), controls mouse via CGEvent, opens URLs via NSWorkspace. Built with xcodegen.
- **MikanRemote** (`MikanRemote/`) — iOS thin client. Discovers Mac via Bonjour, connects over WebSocket, provides trackpad surface (UIKit multi-touch) and action buttons. No local state. Built with xcodegen.
- **MikanProtocol** (`MikanProtocol/`) — Swift Package shared by both apps. Defines `ClientMessage`, `ServerMessage`, `Action`, `MouseButton` as Codable types with flat JSON encoding using a `type` discriminator field.

## Build Commands

```bash
# MikanProtocol tests
cd MikanProtocol && swift test

# MikanServer (macOS)
cd MikanServer && xcodegen generate && xcodebuild -scheme MikanServer build

# MikanRemote (iOS) — requires iOS simulator runtime matching Xcode version
cd MikanRemote && xcodegen generate && xcodebuild -scheme MikanRemote -sdk iphonesimulator build
```

## Key Conventions

- Both Xcode projects use **xcodegen** — edit `project.yml`, then `xcodegen generate` to regenerate `.xcodeproj`. Sources are auto-discovered.
- Deployment targets: macOS 14.0, iOS 17.0 (required for `@Observable`)
- WebSocket protocol: JSON messages with `"type"` field. See `MikanProtocol/Sources/MikanProtocol/Messages.swift`.
- MikanServer requires **Accessibility permission** for CGEvent mouse control.
- Design spec: `docs/superpowers/specs/2026-03-29-mikan-remote-design.md`
- Implementation plan: `docs/superpowers/plans/2026-03-29-mikan-remote.md`
