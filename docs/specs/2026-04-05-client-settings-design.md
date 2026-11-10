# Client Settings Design

Control cursor size, mouse sensitivity, and action buttons from the iPhone — without touching the Mac.

## Features

1. **Cursor overlay size** — adjustable from both iPhone and server menu bar (60–300pt, step 20, default 140)
2. **Mouse sensitivity** — adjustable from both iPhone and server menu bar (3.0–20.0, step 0.5, default 10.0)
3. **Action button editor** — full CRUD from the iPhone: add, delete, reorder, edit label/URL/icon, reset to defaults

## UI Placement

A gear icon (SF Symbol `gearshape`) in the status bar row of ContentView. Tapping it presents a `.sheet` with the settings. This keeps settings completely out of the way during active use — critical since the app is used while biking and accidental triggers must be avoided.

## Protocol Changes

### New ClientMessage cases

- `updateSettings(sensitivity: Double, cursorSize: Double)` — sent when the user adjusts either slider on iPhone. Always sends both values (simpler than optional fields; both are cheap scalars).
- `updateActions(actions: [Action])` — sent when the user saves changes in the action editor on iPhone

### New ServerMessage case

- `settingsSync(sensitivity: Double, cursorSize: Double)` — pushed to client on connect (initial sync) and whenever settings change on the server side (menu bar adjustment)

### Existing (no changes)

- `ServerMessage.actionConfig(actions: [Action])` — already pushed on connect; no changes needed

## Data Flow

The server is the single authoritative source for all settings. The client never persists settings locally.

### Client → Server

1. User taps +/- on sensitivity or cursor size in the settings sheet
2. Client sends `updateSettings(sensitivity:cursorSize:)` with both current values
3. Server applies values: sets `sensitivity` and `cursorSize` properties (persisted to UserDefaults via existing `didSet`), updates CursorOverlayController
4. No echo back to client — the client already has the values it just sent

### Server → Client

1. User adjusts sensitivity or cursor size via the Mac menu bar
2. Server persists to UserDefaults (existing behavior)
3. Server sends `settingsSync(sensitivity:cursorSize:)` to connected client
4. Client updates its published properties, settings sheet reflects new values live

### Actions: Client → Server

1. User edits actions in the iPhone settings sheet and saves
2. Client sends `updateActions(actions:)` with the full action list
3. Server replaces `actionStore.actions`, calls `actionStore.save()`
4. Server pushes `actionConfig(actions:)` back to client (confirms the save, updates button bar)

### On Connect

After pairing succeeds, server sends both `settingsSync` and `actionConfig` so the client starts with current values.

## Server Changes

### MenuBarManager

- `handleMessage` gains two new cases: `.updateSettings` and `.updateActions`
- `.updateSettings` handler sets `sensitivity` and `cursorSize` properties (existing `didSet` handles persistence and CursorOverlayController update)
- `.updateActions` handler replaces `actionStore.actions`, saves, and pushes `actionConfig` to client
- Existing `didSet` on `sensitivity` and `cursorSize` gains a call to send `settingsSync` to the connected client (for menu bar → client sync)

### WebSocketServer

No structural changes. Uses existing `send(_ message: ServerMessage)` for `settingsSync`.

### On connect flow

Add `settingsSync` push alongside existing `actionConfig` push after pairing completes.

## iOS Client Changes

### ConnectionManager

- New `@Published` properties: `sensitivity: Double`, `cursorSize: Double`
- Handle `.settingsSync` in `handleServerMessage` — update published properties
- New method `sendUpdateSettings(sensitivity:cursorSize:)` — encodes and sends `updateSettings`
- New method `sendUpdateActions(actions:)` — encodes and sends `updateActions`

### SettingsView (new)

Presented as a `.sheet` from ContentView. Contains:

- **Sensitivity control** — +/- buttons (step 0.5, range 3.0–20.0), displays value as "10.0x". Calls `sendUpdateSettings` on each tap.
- **Cursor size control** — +/- buttons (step 20, range 60–300), displays value as "140pt". Calls `sendUpdateSettings` on each tap.
- **Action editor** — list of actions with editable fields (label, URL, SF Symbol icon). Add, delete, drag-to-reorder, reset to defaults. Save calls `sendUpdateActions` with the full list.

### ContentView

- Gear icon button (`gearshape`) added to the status bar row, next to the green dot + hostname
- `@State var showSettings = false` — toggled by gear tap, presents SettingsView as sheet
- Passes ConnectionManager (or relevant properties + callbacks) to SettingsView

## Sync Model

- **Server is authoritative** — all settings persisted server-side only (UserDefaults for scalars, `actions.json` for actions)
- **Client is stateless** — gets fresh values on every connect
- **No echo suppression needed** — client changes go to server (no reply), server changes go to client (no reply)
- **No debouncing** — +/- buttons are discrete taps, not continuous sliders
- **Live updates** — if settings sheet is open and server changes a value, the sheet updates immediately via published property binding
- **Two-way sync** — both sides can change settings, both sides see changes from the other
