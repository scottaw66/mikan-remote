# Audio Output Device Selection — Design

**Date:** 2026-05-29
**Status:** Approved (pending spec review)

## Summary

Let the user pick the Mac's default audio output device (Studio Display speakers, AirPods,
external DAC, etc.) from the iPhone remote. The device list appears as a new "Audio Output"
section in the existing Utilities sheet. Output devices only — input/microphone is out of scope.
The list updates live: when a device is plugged in, removed, or the default changes (from any
source, including macOS itself), the server pushes a fresh list to the iPhone.

## Decisions

- **UI placement:** New section in `UtilitiesView` (the wrench-icon sheet), alongside Tools and
  Open URL. Matches the established pattern; disabled when disconnected like the other controls.
- **Scope:** Output devices only.
- **Live updates:** Server watches CoreAudio and pushes on any change.
- **Server menu bar:** iPhone-only. No menu bar audio UI — the macOS system Sound menu already
  covers Mac-side switching, and the live-update listener keeps the iPhone in sync regardless.
- **Error handling:** Silent + self-correcting. A failed switch (e.g. device vanished between
  list and tap) triggers a re-push of the current device list, so the stale entry disappears.
  No error message type, no error banner.

## Mechanism: CoreAudio HAL

Switching uses the native CoreAudio HAL C API (`AudioObjectGetPropertyData` /
`AudioObjectSetPropertyData` on `kAudioObjectSystemObject`). No external dependencies. This also
provides property listeners (`AudioObjectAddPropertyListenerBlock`) for the live-update
requirement. Shelling out to a Homebrew tool such as `SwitchAudioSource` is explicitly rejected:
it is not bundled and would fail on a clean machine.

### Device identity over the wire

Devices are identified by their **persistent device UID** (`kAudioDevicePropertyDeviceUID`, a
stable `CFString`), not the session-local `AudioDeviceID` (`UInt32`, which can change on replug or
reboot). The server resolves UID → current `AudioDeviceID` at switch time by scanning the device
list. This means AirPods that reconnect later still match the same protocol identifier.

### Enumerating output devices

1. Read `kAudioHardwarePropertyDevices` on the system object → array of `AudioDeviceID`.
2. For each, check it has output streams: query `kAudioDevicePropertyStreams` with scope
   `kAudioObjectPropertyScopeOutput`; keep devices where the stream count > 0. This filters out
   input-only devices (e.g. a USB microphone).
3. For each output device read `kAudioDevicePropertyDeviceUID` (id) and
   `kAudioObjectPropertyName` (name).
4. Read `kAudioHardwarePropertyDefaultOutputDevice` → current `AudioDeviceID`, map to its UID for
   `currentDeviceId`.

### Switching

On `setAudioDevice(deviceId:)`: scan output devices for the one whose UID matches `deviceId`,
get its `AudioDeviceID`, and set `kAudioHardwarePropertyDefaultOutputDevice`. If no match or the
set call returns a non-zero `OSStatus`, re-push the current `audioDevices` state (self-correcting)
and return.

### Live updates

`AudioDeviceController` registers property listener blocks for:
- `kAudioHardwarePropertyDevices` (device added/removed)
- `kAudioHardwarePropertyDefaultOutputDevice` (default changed by any source)

On either, it re-enumerates and fires its `onChange` callback. Listeners run on a dispatched
queue; the callback hops to the main queue (where `MenuBarManager` and `server.send` live, since
the listener runs on `.main` like the rest of the server).

## Protocol changes (`MikanProtocol/Sources/MikanProtocol/Messages.swift`)

New `Codable` `Sendable` struct:

```swift
public struct AudioDevice: Codable, Sendable, Identifiable, Equatable {
    public let id: String   // device UID
    public let name: String
    public init(id: String, name: String) { self.id = id; self.name = name }
}
```

New `ServerMessage` case (flat JSON, `type` discriminator, consistent with existing cases):

- `audioDevices(devices: [AudioDevice], currentDeviceId: String)`
  - encoded keys: `type="audioDevices"`, `devices`, `currentDeviceId`

New `ClientMessage` case:

- `setAudioDevice(deviceId: String)`
  - encoded keys: `type="setAudioDevice"`, `deviceId`

Both follow the existing manual `init(from:)` / `encode(to:)` switch pattern. Add `devices`,
`currentDeviceId`, and `deviceId` to the respective `CodingKeys`. No `decodeIfPresent`
backward-compat shim is needed — these are new message types; an older peer simply never sends or
receives them.

## Server changes

### New file: `MikanRemoteServer/MikanRemoteServer/AudioDeviceController.swift`

`final class AudioDeviceController` (analogous to `MouseController`):
- `func currentState() -> (devices: [AudioDevice], currentDeviceId: String)`
- `func setDefaultOutput(uid: String) -> Bool` (false on failure)
- `var onChange: (() -> Void)?` — fired by CoreAudio listeners after re-enumeration
- registers/removes property listeners in `init`/`deinit`

### `MenuBarManager.swift`

- Own an `AudioDeviceController` instance.
- In `init`, set `audioController.onChange = { [weak self] in self?.pushAudioDevices() }`.
- Add `func pushAudioDevices()` → `server.send(.audioDevices(devices:currentDeviceId:))` using
  `audioController.currentState()`.
- Call `pushAudioDevices()` in `handleHello` (paired branch) and `handlePairResponse` (accepted
  branch), after `pushSettings()`, so the iPhone gets the list on connect.
- Handle the new client message in `handleMessage`:
  ```swift
  case .setAudioDevice(let deviceId):
      if !audioController.setDefaultOutput(uid: deviceId) { pushAudioDevices() }
      // success path: the CoreAudio default-device listener fires onChange → pushAudioDevices()
  ```

## Client changes

### `MikanRemote/MikanRemote/ConnectionManager.swift`

- Add published state:
  - `private(set) var audioDevices: [AudioDevice] = []`
  - `private(set) var currentAudioDeviceId: String = ""`
- Reset both in `disconnect()` and `handleDisconnect()` (to `[]` / `""`), matching the existing
  reset pattern.
- Handle `.audioDevices(let devices, let currentDeviceId)` in `handleServerMessage` → assign both.
- Add `func sendSetAudioDevice(_ deviceId: String) { send(.setAudioDevice(deviceId: deviceId)) }`.

### `MikanRemote/MikanRemote/UtilitiesView.swift`

New `Section("Audio Output")` placed between Tools and Open URL (top-down ordering: Tools,
Audio Output, Open URL):
- One row per `connectionManager.audioDevices`. Row is a `Button` showing the device name; a
  trailing `checkmark` (`systemImage: "checkmark"`) when `device.id ==
  connectionManager.currentAudioDeviceId`.
- Tap → haptic + `connectionManager.sendSetAudioDevice(device.id)`. No optimistic local update;
  the server's push (driven by the CoreAudio listener) updates the checkmark. This keeps the UI
  honest if the switch fails.
- The whole section's rows are `.disabled(!connectionManager.isConnected)`, consistent with the
  Open URL controls.
- If `audioDevices` is empty (not yet received, or disconnected), show a single disabled
  placeholder row ("No devices").

## Data flow

```
Connect / pair  ──► server pushes audioDevices ──► ConnectionManager state ──► UtilitiesView list
User taps device ─► setAudioDevice(uid) ─► MenuBarManager ─► AudioDeviceController.setDefaultOutput
CoreAudio default changes (any source) ─► listener ─► onChange ─► pushAudioDevices ─► iPhone refresh
Device added/removed ───────────────────► listener ─► onChange ─► pushAudioDevices ─► iPhone refresh
Switch fails ───────────────────────────► pushAudioDevices (re-push current) ─► iPhone refresh
```

## Testing

- **MikanProtocol (`swift test`):** round-trip encode/decode for `AudioDevice`,
  `ServerMessage.audioDevices`, and `ClientMessage.setAudioDevice`, asserting the flat JSON shape
  (`type` field + payload keys), consistent with existing message tests.
- **Manual (server + physical iPhone, per project constraints):**
  - On connect, the Audio Output section lists output devices with the current one checked.
  - Tapping a device switches the Mac's output (verify audibly / in System Settings) and the
    checkmark moves.
  - Plug in / unplug AirPods or headphones mid-session → list updates live on the iPhone.
  - Change output from the macOS Sound menu → iPhone checkmark follows.
  - Disconnect → section disables; reconnect → list repopulates.

## Out of scope

- Input/microphone device selection.
- Per-app output routing.
- Volume control (already exists as `volumeUp` / `volumeDown` commands).
- Server menu bar audio UI.
- Explicit switch-failure error messaging.
