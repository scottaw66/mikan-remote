# Mikan Remote — Design Spec

A simple iPhone-to-Mac remote control for streaming video from an exercise bike. Trackpad-style mouse control plus configurable quick-action buttons, all over the local network.

## Architecture

Three components in a monorepo:

1. **MikanServer** (macOS menu bar app) — Advertises on the local network, receives commands, controls the mouse and opens URLs.
2. **MikanRemote** (iOS app) — Discovers the Mac, provides a trackpad surface and action buttons. Thin client with no local state.
3. **MikanProtocol** (Swift Package) — Shared Codable message types used by both apps.

Each app is its own Xcode project. The shared package is a local Swift Package dependency.

## Networking

### Discovery

- Mac advertises a Bonjour service of type `_mikan._tcp` on a dynamic port.
- iPhone browses for `_mikan._tcp`. Auto-connects if one Mac is found; shows a picker if multiple are found.

### Transport

- WebSocket over the local network.
- Mac runs a WebSocket server on the Bonjour-advertised port.
- Single connection at a time (single-user tool).
- iPhone reconnects automatically on disconnect.

### Protocol

All messages are JSON-encoded with a `type` field for routing.

**iPhone → Mac:**

| Type | Fields | Purpose |
|------|--------|---------|
| `mouseMove` | `deltaX: Float`, `deltaY: Float` | Relative cursor movement |
| `mouseClick` | `button: String` ("left" / "right") | Click at current position |
| `mouseScroll` | `deltaX: Float`, `deltaY: Float` | Scroll gesture |
| `openURL` | `url: String` | Open a URL in the default browser |

**Mac → iPhone:**

| Type | Fields | Purpose |
|------|--------|---------|
| `actionConfig` | `actions: [Action]` | Button list (sent on connect + on change) |
| `serverStatus` | `connected: Bool`, `hostname: String` | Connection acknowledgment |

**Action object:** `{ id: String, label: String, url: String, icon: String? }`

Mouse move messages are throttled to ~60Hz on the iPhone side. The Mac applies a configurable sensitivity multiplier to incoming deltas.

## Mac App (MikanServer)

### Menu Bar

- Status icon that changes appearance when connected vs. idle.
- Dropdown menu:
  - Connection status line (e.g., "Connected: Scott's iPhone" or "Waiting for connection...")
  - Sensitivity slider for mouse speed multiplier
  - "Edit Actions..." opens a settings window
  - Quit

### Action Configuration

- Simple list editor: each row has a label, URL, and optional SF Symbol icon name.
- Stored as JSON at `~/Library/Application Support/MikanServer/actions.json`.
- Default config ships with Netflix and YouTube.
- Config changes are pushed to the connected iPhone immediately.

### Mouse Control

- Uses `CGEvent` API to move the cursor and simulate clicks.
- Requires Accessibility permission (prompted on first launch).
- Sensitivity multiplier applied to incoming deltas before moving the cursor.

### URL Opening

- `NSWorkspace.shared.open(url)` routes to the user's default browser.

### WebSocket Server

- Runs on the port advertised via Bonjour.
- Uses `Network.framework` (`NWListener` + `NWConnection` with WebSocket protocol) for the server. This is Apple's modern networking API, requires no third-party dependencies, and supports WebSocket natively on macOS 12+.
- Accepts one connection at a time.

## iPhone App (MikanRemote)

### Connection Flow

1. On launch, browse for `_mikan._tcp` services.
2. One found → auto-connect. Multiple → show picker. None → scanning indicator with retry.
3. On connect, Mac sends `serverStatus` and `actionConfig`.
4. Auto-reconnect on disconnect.

### Main Screen Layout

- **Top:** Connection status bar (Mac hostname, connected/disconnected).
- **Middle:** Large trackpad zone (majority of the screen).
- **Bottom:** Horizontally scrollable row of action buttons from the Mac's config.

### Trackpad Behavior

- Touch drag → `mouseMove` (relative deltas, throttled to ~60Hz).
- Single tap → `mouseClick` (left).
- Two-finger tap → `mouseClick` (right).
- Two-finger drag → `mouseScroll`.
- Visual feedback: subtle ripple on tap, highlight on trackpad while touching.

### Action Buttons

- Rendered dynamically from the Mac's `actionConfig`.
- Each button shows label and optional SF Symbol icon.
- Tap sends `openURL` with the configured URL.
- Buttons update live if the Mac pushes a new config.

### No Local State

The iPhone stores nothing. Server list comes from Bonjour, buttons come from the Mac. It's a pure thin client.

## Permissions and Security

- **Mac:** Requires Accessibility permission for mouse control. The app prompts on first launch via the standard macOS dialog.
- **Network:** Local network only. No authentication — the assumption is that your home network is trusted. The Bonjour service is only visible to devices on the same network.
- **iPhone:** Requires local network permission (iOS prompt on first Bonjour browse).

## Repo Structure

```
mikan-remote/
├── MikanServer/          # macOS Xcode project
├── MikanRemote/          # iOS Xcode project
├── MikanProtocol/        # Swift Package (shared types)
├── docs/
│   └── superpowers/specs/
├── Design.md
├── README.md
└── CLAUDE.md
```
