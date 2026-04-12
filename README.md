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
- Menu bar app on Mac — stays out of the way

## Requirements

- macOS 14.0+
- iOS 17.0+
- Both devices on the same local network

## Setup

1. Build and run **MikanServer** on your Mac
2. Grant Accessibility permission when prompted (System Settings > Privacy & Security > Accessibility)
3. Build and run **MikanRemote** on your iPhone
4. The iPhone auto-discovers and connects to your Mac
5. Enter the 4-digit pairing code shown on your Mac (first time only)

## Customizing

Tap the gear icon on iPhone to adjust:
- **Mouse sensitivity** (3x–20x)
- **Cursor overlay size** (60–300pt)
- **Action buttons** — add, remove, reorder, edit label/URL/icon (max 6)

Settings can also be changed from the Mac menu bar. Changes sync both ways instantly.

## Project Structure

- `MikanServer/` — macOS menu bar app (Xcode project)
- `MikanRemote/` — iOS app (Xcode project)
- `MikanProtocol/` — Shared Swift Package (message types)

## License

MIT
