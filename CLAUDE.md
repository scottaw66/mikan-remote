# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MikanRemote is an iPhone-to-Mac remote control for streaming video. Trackpad-style mouse control plus configurable quick-action buttons, all over the local network via Bonjour discovery and WebSocket.

## Architecture

Three components:

- **MikanRemoteServer** (`MikanRemoteServer/`) — macOS menu bar app. Advertises via Bonjour, runs a WebSocket server (Network.framework), controls mouse/keyboard via CGEvent, simulates media keys, renders a custom cursor overlay, opens URLs via NSWorkspace. Manages device pairing (PairingStore persists paired UUIDs to disk). Built with xcodegen.
- **MikanRemote** (`MikanRemote/`) — iOS thin client. Discovers Mac via Bonjour, connects over WebSocket, provides trackpad surface (UIKit multi-touch), action buttons, and a settings sheet for adjusting sensitivity, cursor size, and action buttons. Auto-reconnects on foreground. No local state — server is the single source of truth. Built with xcodegen.
- **MikanProtocol** (`MikanProtocol/`) — Swift Package shared by both apps. Defines `ClientMessage` (mouseMove, mouseClick, mouseScroll, openURL, performCommand, hello, pairResponse, updateSettings, updateActions), `ServerMessage` (actionConfig, serverStatus, pairRequired, pairAccepted, pairRejected, settingsSync), and `Action` as Codable types with flat JSON encoding using a `type` discriminator field.

## Build Commands

```bash
# MikanProtocol tests
cd MikanProtocol && swift test

# MikanRemoteServer (macOS) — signed + notarized install (preferred)
cd MikanRemoteServer && ./scripts/release.sh
# Archives → Developer ID export → notarize → staple → install to /Applications.
# Needs a "mikanremote" notarytool profile (see ~/Scripts/ai/apps/CLAUDE.md).

# Quick dev build (ad-hoc, local only — NOT notarized, Gatekeeper-flagged elsewhere):
cd MikanRemoteServer && xcodegen generate && xcodebuild -scheme MikanRemoteServer -configuration Release build
APP_PATH=$(xcodebuild -scheme MikanRemoteServer -configuration Release -showBuildSettings 2>/dev/null | grep " BUILT_PRODUCTS_DIR" | awk '{print $3}')
rm -rf /Applications/MikanRemoteServer.app && cp -R "$APP_PATH/MikanRemoteServer.app" /Applications/MikanRemoteServer.app

# MikanRemote (iOS) — must deploy to physical iPhone (not simulator)
cd MikanRemote && xcodegen generate && open MikanRemote.xcodeproj
# Then build and run to device from Xcode (Cmd+R) — scheme defaults to Release with no debugger
```

## Important: Accessibility Permission

MikanRemoteServer requires Accessibility permission for mouse/keyboard control. Grant it once in System Settings > Privacy & Security > Accessibility. If trackpad control silently stops working after a rebuild, try toggling the permission OFF then ON.

## Key Conventions

- Both Xcode projects use **xcodegen** — edit `project.yml`, then `xcodegen generate` to regenerate `.xcodeproj`. Sources are auto-discovered from the source directories.
- Deployment targets: macOS 14.0, iOS 17.0 (required for `@Observable`)
- WebSocket protocol: JSON messages with `"type"` field. See `MikanProtocol/Sources/MikanProtocol/Messages.swift`.
- MikanRemoteServer requires **Accessibility permission** for mouse/keyboard control via CGEvent (System Settings > Privacy & Security > Accessibility). If control stops working after a rebuild, toggle the permission off and on.
- MikanRemote requires a **physical iPhone** for testing — simulator is impractical since mouse control and URL opening fight with the simulator on the same Mac.
- MikanRemote run scheme is configured for **Release with no debugger** — do not change this.
- App icons: source SVGs at repo root (`icon.svg` for remote, `icon-server.svg` for server). Teal rings = server, orange rings = remote.
- **No right-click.** Right-click is permanently removed from the protocol, server, and client. The `MouseButton` enum no longer exists. `mouseClick` has no parameter — it is always a left click. Do NOT reintroduce right-click under any circumstances.
- **Security pairing:** On first connect, the server generates a 4-digit code shown in a floating window. The client sends `hello(deviceId:)` on connect; unknown devices receive `pairRequired` and must submit the code via `pairResponse`. Paired UUIDs are stored in `~/Library/Application Support/MikanRemoteServer/paired-devices.json` (legacy `MikanServer/` directory is migrated automatically on first launch). Use "Unpair All Devices" in the menu bar to reset.
- **Client settings:** Sensitivity, cursor size, action buttons, and YouTube popup mode are configurable from both the iPhone (gear icon → settings sheet) and the Mac menu bar. The server is the single source of truth — it pushes `settingsSync` and `actionConfig` on connect and on change. The client sends `updateSettings` or `updateActions` when the user makes changes. No client-side persistence.
- **Cursor overlay size** is configurable from iPhone or server menu bar (60–300pt range, step 20, persisted to UserDefaults). Default is 140pt.
- **Mouse sensitivity** is configurable from iPhone or server menu bar (3.0–20.0, step 0.5, persisted to UserDefaults). Default is 10.0.
- **Action buttons** are limited to 6 max, displayed 2 per row on iPhone. Editable from iPhone settings sheet (label, URL, icon picker) or server Edit Actions window. Buttons can open URLs (browser) or app URL schemes (e.g. `videos://` for Apple TV). Defaults: Apple TV, Netflix, YouTube.
- **Command buttons:** closeTab (Cmd+W), prevTab (Cmd+Shift+[), nextTab (Cmd+Shift+]), volumeUp, volumeDown, fullscreen (Ctrl+Cmd+F), arrowLeft, arrowRight, playPause (media key), escape.
- **YouTube popup commands:** `ytPrevVideo` (Shift+P), `ytNextVideo` (Shift+N), `ytPrevChapter` (Option+Left), `ytNextChapter` (Option+Right), `ytToggleCaptions` (C), `ytSlowDown` (Shift+,), `ytSpeedUp` (Shift+.), `ytFullscreen` (F — YouTube web player only, distinct from `fullscreen`), `ytPlayPause` (K). Helper methods are on `MouseController` as `sendYouTube*`. Dispatched from `MenuBarManager.handleCommand`.
- **Utilities sheet (iPhone):** wrench-icon launcher in the top status bar (between YouTube and gear) opens `UtilitiesView` (`MikanRemote/UtilitiesView.swift`). Sections, top-down: **Tools** (Take Screenshot — sends `performCommand("screenshot")`, the screenshot button moved here out of `SettingsView`'s old Utilities section) and **Open URL on Mac** (`PasteButton(payloadType: URL.self)` for toast-free clipboard paste, plus a URL textbox + Send). Send controls are disabled when `!connectionManager.isConnected` to avoid false-success flashes if the WS drops while the sheet is open. All paths reuse the existing `openURL` / `performCommand` WebSocket messages — no protocol or server changes.
- **Audio output device selection (iPhone):** The Utilities sheet has an "Audio Output" section (between Tools and Open URL) listing the Mac's output devices; tapping one switches the Mac default output. The server's `AudioDeviceController` (`MikanRemoteServer/MikanRemoteServer/AudioDeviceController.swift`) wraps the CoreAudio HAL: it enumerates devices with output streams (`kAudioDevicePropertyStreams`, scope output) excluding virtual devices whose name matches `AudioDeviceController.excludedNameFragments` (currently "Microsoft Teams Audio", case-insensitive substring), switches `kAudioHardwarePropertyDefaultOutputDevice`, and installs property listeners on `kAudioHardwarePropertyDevices` + `kAudioHardwarePropertyDefaultOutputDevice` for live updates. Devices are identified over the wire by their persistent **UID** (`kAudioDevicePropertyDeviceUID`), not the session-local `AudioDeviceID`, and CFString properties are read with `Unmanaged<CFString>` + `takeRetainedValue()`. Protocol: `ServerMessage.audioDevices(devices:currentDeviceId:)` pushed on connect/change, `ClientMessage.setAudioDevice(deviceId:)` on tap. A failed switch silently re-pushes the current list (self-correcting); on success the CoreAudio listener does the re-push. No `decodeIfPresent` shim (brand-new message types). Output only — no input/mic, no server menu bar UI.
- **Share Extension (`MikanRemoteShare`):** iOS share-sheet target registered for URL shares (activation rule restricts to `public.url`). On invocation, `ShareViewController` extracts the first URL (with `public.plain-text` + `NSDataDetector` fallback), writes it to the App Group via `SharedDefaults.shared.pendingShareURL`, opens `mikanremote://share` via responder-chain walk to `UIApplication.open(_:options:completionHandler:)`, and calls `extensionContext.completeRequest`. No compose UI, no networking — the extension is a one-way write to the App Group.
- **App Group + URL scheme:** `group.$(BUNDLE_PREFIX).mikanremote` (set in both `MikanRemote.entitlements` and `MikanRemoteShare.entitlements`; `$(BUNDLE_PREFIX)` is expanded by Xcode's `ProcessProductPackaging` step). The App Group ID is exposed to both targets via `MikanAppGroupIdentifier` in their Info.plists; `SharedDefaults` reads it from `Bundle.main` at startup and **`preconditionFailure`s** if either the key or the resolved container URL is missing. **The pending-share slot is a file** at `<appGroupContainer>/pendingShareURL.txt`, **not** `UserDefaults(suiteName:)` — `UserDefaults` writes propagate cross-process via `cfprefsd` + Darwin notifications, so the host app's in-process cache is stale for the read window right after the extension hands off, and a still-running host would read `nil` and drop the share. `Data.write(to:options:.atomic)` in the App Group container is synchronous and immediately visible to other processes; that property is exercised by `testWritesAreImmediatelyVisibleToFreshInstance`. URL scheme `mikanremote://` is registered in the main app's `Info.plist` `CFBundleURLTypes`; the extension uses `mikanremote://share` as the host-app handoff trigger.
- **`PendingShareDispatcher` (`MikanRemote/PendingShareDispatcher.swift`):** `@MainActor @Observable` state machine that drains the App Group slot when the WebSocket is truly ready (`isConnected && hostname != nil`). State: `idle | sending(url:) | sent | failed`. Triggered from `MikanRemoteApp` via `.onOpenURL` (for `mikanremote://share` handoffs) and `.onChange(of: scenePhase == .active)`; the readiness drain is wired via `.onChange(of: isConnected)` + `.onChange(of: hostname)` both calling `connectionBecameReady()`. **Single-slot, latest-wins:** if a second share arrives before the first drains, `attemptSend` re-reads `store.pendingShareURL` at send time so only the latest URL is forwarded. Hard **10-second timeout** before `state → .failed` and a **Retry** affordance; the slot stays populated through `.failed` so Retry just re-enters the cycle. Visual feedback above the trackpad via `DispatcherBanner` (`MikanRemote/Banner.swift`).
- **YouTube popup mode** is a 3-state setting (`"auto"` / `"on"` / `"off"`, default `"auto"`) controlling iPhone launcher visibility. Server-stored via `settingsSync.youtubePopupMode` and `updateSettings.youtubePopupMode` (both use `decodeIfPresent ?? "auto"` for backward-compat). In `"auto"` mode the launcher shows iff any action URL contains `youtube.com` or `youtu.be` (case-insensitive) — the pure check is `YouTubeVisibility.effectiveYouTubeButtonVisible(mode:actions:)`. The popup itself (`YouTubePopupView`) is iPhone-only; the server menu bar exposes only the mode picker.
- **Networking** runs on a background queue — do not dispatch back to MainActor unnecessarily; the existing pattern uses `DispatchQueue.main.async` only for UI updates.
- **WebSocket keepalive:** The server sends WebSocket pings every 5 seconds. If a pong is not received (e.g. client app killed), the connection is immediately dropped.
- **Settings UI must be behind deliberate taps** (gear icon → sheet), never swipeable or inline — the app is used during exercise and accidental triggers must be avoided.

## Key Files

- Design specs: `docs/superpowers/specs/`
- Implementation plans: `docs/superpowers/plans/`
- Testing guide: `docs/testing-guide.md`

## Project layout (iPhone target)

- `MikanRemote/MikanRemote/` — main iOS app sources
- `MikanRemote/MikanRemoteShare/` — Share Extension target (URL handoff only, no networking)
- `MikanRemote/Shared/` — sources compiled into **both** targets (currently just `SharedDefaults.swift`). Add files here when both the main app and the extension need them.
- `MikanRemote/MikanRemoteTests/` — XCTest target. Hosted (`BUNDLE_LOADER=$(TEST_HOST)`) so `@testable import MikanRemote` reaches `Shared/` and `MikanRemote/` sources. The test target's `GENERATE_INFOPLIST_FILE: YES` is set because xcodegen otherwise leaves it unsigned/un-plisted.
