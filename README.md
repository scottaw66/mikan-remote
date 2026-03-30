# Mikan Remote

A simple iPhone app to remote-control a Mac over your local network. Designed for when you're on an exercise bike and want to watch Netflix or YouTube on your Mac's display.

## Features

- Trackpad-style mouse control from your iPhone
- Configurable quick-action buttons (open URLs in default browser)
- Automatic discovery via Bonjour — no IP address needed
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

## Customizing Actions

Click the Mikan menu bar icon > "Edit Actions..." to add, remove, or reorder quick-action buttons. Changes sync to connected iPhones instantly.

## Project Structure

- `MikanServer/` — macOS menu bar app (Xcode project)
- `MikanRemote/` — iOS app (Xcode project)
- `MikanProtocol/` — Shared Swift Package (message types)

## License

MIT
