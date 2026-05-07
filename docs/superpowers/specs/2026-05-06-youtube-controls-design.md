# YouTube Controls Popup — Design

**Date:** 2026-05-06
**Status:** Approved
**Scope:** Client-side popup of YouTube-specific keyboard shortcuts, with reactive auto-show logic tied to action buttons.

## Summary

Add a YouTube controls popup to the iPhone client. The popup is a modal sheet containing 8 buttons that send YouTube's web-player keyboard shortcuts (next/prev video, next/prev chapter, captions, slow down, speed up, fullscreen) to the Mac. The popup is launched from a dedicated button on the main screen. A 3-state setting (Auto / Always On / Always Off) controls whether the launcher button is visible; in Auto mode it shows iff the user has a YouTube action button defined.

## Goals

- Quick mid-video access to YouTube-specific shortcuts during exercise use, without leaving the trackpad screen.
- Settings-driven visibility that matches user intent without manual fiddling for the common case (Auto).
- Server stays the single source of truth for the new setting, matching existing pattern.

## Non-goals

- Server-side popup or YouTube submenu in the menu bar (the *setting* is editable from both sides; the popup itself is iPhone-only).
- Generic key-combo support — these 7 commands are added explicitly, not via a generalized key-injection protocol.
- A permanent, undeletable YouTube action button. (Considered and rejected; freedom of all 6 slots wins.)

## Architecture

### Protocol changes — `MikanProtocol`

#### New `performCommand` strings

The existing `performCommand(command: String)` carries a free-form string already; only the accepted server-side values change. Eight new strings:

| Command | Server keystroke | Modifiers |
|---|---|---|
| `ytPrevVideo` | `P` | Shift |
| `ytNextVideo` | `N` | Shift |
| `ytPrevChapter` | Left arrow | Option |
| `ytNextChapter` | Right arrow | Option |
| `ytToggleCaptions` | `c` | (none) |
| `ytSlowDown` | `,` | Shift (produces `<`) |
| `ytSpeedUp` | `.` | Shift (produces `>`) |
| `ytFullscreen` | `f` | (none) |

The existing `fullscreen` command (Ctrl+Cmd+F, native macOS fullscreen) is unchanged. `ytFullscreen` is YouTube's `f` key — a separate command.

#### New settings field

`updateSettings` and `settingsSync` gain a `youtubePopupMode: String` field with values `"auto"`, `"on"`, or `"off"`. Default is `"auto"`.

```swift
case updateSettings(
    sensitivity: Double,
    cursorSize: Double,
    cursorDotSize: Double,
    cursorGapSize: Double,
    youtubePopupMode: String
)

case settingsSync(
    sensitivity: Double,
    cursorSize: Double,
    cursorDotSize: Double,
    cursorGapSize: Double,
    youtubePopupMode: String
)
```

### Server changes — `MikanServer`

- **`MouseController`** — add 8 `CGEvent`-based methods, one per `yt*` command, mirroring the pattern used for existing commands (`prevTab`, `nextTab`, etc.). Each composes a key-down + key-up with the appropriate `CGEventFlags` (`.maskShift`, `.maskAlternate`).
- **`WebSocketServer`** — extend the `performCommand` dispatch switch to route the 8 new strings to the new `MouseController` methods.
- **Settings persistence** — add `youtubePopupMode` to the existing settings model (alongside sensitivity / cursor sizes), persisted via UserDefaults. Default `"auto"`.
- **`MenuBarManager`** — add a "YouTube Popup" submenu with three radio-style items: Auto / Always On / Always Off. Selection updates the setting and pushes `settingsSync` to all connected clients.
- **Settings sync** — when the field changes from either side (server menu bar or client `updateSettings`), the server broadcasts a fresh `settingsSync` to all connected clients.

### Client changes — `MikanRemote`

#### Main screen

A small YouTube-styled launcher button (red-tinted SF Symbol such as `play.rectangle.fill`) in the top-right corner of the main screen, well clear of the trackpad and action buttons. Visible only when the effective state is "show". Tap presents the popup as a SwiftUI `.sheet`.

#### Popup view (`YouTubePopupView`)

Modal sheet, dismissed by swipe-down or a "Done" button in the top bar. Stays open until explicitly dismissed so multi-tap (e.g. `>` repeatedly to bump playback rate) works.

Layout:

```
[Prev Video]    [Next Video]
[Prev Chapter]  [Next Chapter]
[         Captions          ]
[Slower <]      [> Faster]
[        Fullscreen         ]
```

Each tap sends `performCommand` with the matching `yt*` string and triggers a light haptic for confirmation. The sheet does not auto-close on tap. The sheet's natural background dim prevents accidental trackpad input while it is up.

#### Settings sheet — new section

A new "YouTube Controls" section in the existing settings sheet, with a picker (segmented or list) for Auto / Always On / Always Off. Help text under the picker explains Auto: "Shows the YouTube button when a YouTube link is in your action buttons." Selection sends `updateSettings` with the new mode; the server re-broadcasts.

#### Effective-visibility logic

A pure function on the client:

```
mode == "on"   → show launcher
mode == "off"  → hide launcher
mode == "auto" → show iff any action button URL contains
                 "youtube.com" or "youtu.be" (case-insensitive)
```

Recomputed on every `actionConfig` and `settingsSync` push, plus on local action-list changes before the server's echo arrives.

## Data flow

1. **Initial connect:** Server pushes `actionConfig` and `settingsSync` (now including `youtubePopupMode`) to the client. Client computes effective visibility.
2. **User taps a YouTube popup button:** Client sends `performCommand("yt*")`. Server dispatches to `MouseController`, which fires the `CGEvent` keystroke against the focused app (typically Safari/Chrome on a YouTube page).
3. **User changes mode in iPhone settings:** Client sends `updateSettings(... youtubePopupMode: ...)`. Server persists, re-broadcasts `settingsSync`. All clients (including the originator) reconcile to the new value. Server menu bar UI updates its radio selection.
4. **User changes mode in server menu bar:** Server persists, broadcasts `settingsSync`. Client reconciles its picker.
5. **User adds/removes a YouTube action button:** Existing `updateActions` flow runs. Server broadcasts `actionConfig`. Client recomputes effective visibility — in Auto mode this transitions show/hide automatically.

## Error handling

- Unknown `yt*` command on an outdated server: existing dispatch falls through to the default branch (logged, ignored). Client behavior unaffected.
- Missing `youtubePopupMode` field in a legacy `settingsSync` from an older server: client decodes with a default of `"auto"` (use `decodeIfPresent`). Same on the server side for an older client's `updateSettings`.

## Testing

### Unit tests (`MikanProtocol/Tests`)

- Round-trip `updateSettings` and `settingsSync` with each of the three mode values (`auto`, `on`, `off`).
- Round-trip `performCommand` for each of the 8 `yt*` strings (decode and re-encode produces identical JSON).

### Pure-function tests (client)

- `effectiveYouTubeButtonVisible(mode:actions:)`:
  - mode=on, no actions → true
  - mode=off, YouTube action present → false
  - mode=auto, no actions → false
  - mode=auto, action with `https://youtube.com` → true
  - mode=auto, action with `https://youtu.be/abc` → true
  - mode=auto, action with `https://m.youtube.com` → true
  - mode=auto, action with `https://YOUTUBE.COM` (uppercase) → true
  - mode=auto, action with `https://netflix.com` → false

### Manual on-device verification

Per project memory: physical iPhone, Release build, no merge before full on-device testing.

- Default config (YouTube action present, mode=auto): launcher visible.
- Delete YouTube action: launcher disappears.
- Re-add YouTube action: launcher reappears.
- Mode=on: launcher visible regardless of actions.
- Mode=off: launcher hidden regardless of actions.
- Open YouTube in Safari on Mac, tap each of the 8 buttons in the popup, confirm the expected YouTube behavior.
- Sheet stays open across multiple taps; haptic fires per tap; trackpad does not move while sheet is up.
- Mode change in server menu bar propagates to iPhone settings picker.
- Mode change in iPhone settings picker propagates to server menu bar.

## Build sequence

1. **MikanProtocol** — add `youtubePopupMode` to messages; add 8 `yt*` accepted command strings (no enum, but document them); add tests; `swift test` passes.
2. **Server** — extend `MouseController` with the 8 keystroke methods; extend `WebSocketServer` dispatch; add settings persistence for `youtubePopupMode`; add menu bar submenu; wire settings sync.
3. **Server install** — `xcodegen generate` and build Release; copy to `/Applications/MikanRemoteServer.app` per project convention.
4. **Client** — add `youtubePopupMode` to settings model; add settings sheet section; build `YouTubePopupView`; add launcher button to main screen with effective-visibility logic; wire `updateSettings` send.
5. **Client install** — `xcodegen generate`, open in Xcode, build to physical iPhone in Release.
6. **Verification** — run all manual on-device cases above before considering work complete.

## Open questions

None at design time. All choices resolved during brainstorming.
