# Utilities sheet & Share Extension — Design

**Date:** 2026-05-10
**Status:** Approved (brainstorming)

## Summary

Move the Take Screenshot button out of iPhone Settings into a new "Utilities" sheet, and add two new ways for the iPhone to send a URL for the Mac to open: a paste-from-clipboard button and a typed/pasted-into-textbox + Send pair (both inside the Utilities sheet), plus an iOS Share Extension so the user can share URLs from Safari (and any other URL host) directly to MikanRemote. All paths reuse the existing `openURL(url:)` WebSocket message — no protocol or server changes.

## Goals

- Surface the screenshot tool through the same affordance shape as the YouTube controls popup (top-bar launcher icon → SwiftUI sheet).
- Let the user send any URL to the Mac with one tap — from clipboard, typed input, or the iOS share sheet.
- Keep the round trip fast on the happy path and graceful when the WebSocket is reconnecting after a foreground transition.
- No protocol or server changes.

## Non-goals

- Self-contained Share Extension with its own WebSocket / Bonjour stack (rejected during brainstorming in favor of main-app handoff).
- Literal AirDrop transport (rejected — we already have a paired authenticated channel).
- Right-click anything (forbidden by project conventions).
- Server-side changes of any kind.
- A queue for multiple pending URLs — single slot, latest wins.

## Architecture

Three actors and one shared surface:

- **Main app (iPhone).** Owns the new `UtilitiesView` sheet, the launcher button in `ContentView`'s top bar, and a new `PendingShareDispatcher` that drains the queue when the connection is *truly* ready (`isConnected && hostname != nil` — `hostname` is the post-pairing handshake signal in `ConnectionManager`).
- **Share extension (new target `MikanRemoteShare`).** Single responsibility: pull the URL out of the share `NSExtensionItem`, write it into a shared App Group, open the host app via `mikanremote://share`, complete the request. No networking, no compose UI.
- **App Group container.** A single shared `UserDefaults(suiteName:)` slot — `pendingShareURL: String?`. Single-slot semantics: a second share before the first drains overwrites it.

### Send-ready semantics

A URL in the slot is dispatchable iff `connectionManager.isConnected && connectionManager.hostname != nil`. The dispatcher observes both via SwiftUI `onChange` (on the values exposed by the `@Observable` `ConnectionManager`); on the transition into ready, it drains.

### Reconnect-window UI

When the main app foregrounds with a pending URL and the WebSocket isn't ready yet, the Utilities sheet (or a small banner above the trackpad if the sheet isn't open) shows **"Sending to <hostname or "Mac">…"** with a spinner. On success → **"Sent ✓"** for ~1.2s, then auto-clear. On a 10s timeout → **"Couldn't reach Mac — tap to retry"** with a Retry button that re-runs the dispatcher; pending URL stays in the slot.

### Where the dispatcher lives

A small `@MainActor` `@Observable` class instantiated in `MikanRemoteApp`, given a reference to `ConnectionManager`. Hooks: `.onOpenURL` (covers the share-extension handoff path) and `.onChange(of: scenePhase)` for `.active` (covers the case where iOS skipped the URL callback or the app was already in memory). Both paths funnel into the same "drain or wait" code.

## Components & files

### iPhone main app — new files

- **`MikanRemote/MikanRemote/UtilitiesView.swift`** — the sheet. Sections, top-down:
  - **"Tools"** — Take Screenshot button (moved verbatim from `SettingsView`'s former Utilities section).
  - **"Open URL on Mac"** — a `TextField` (`.keyboardType(.URL)`, `.textInputAutocapitalization(.never)`) + Send button; a `PasteButton(payloadType: URL.self)` for the toast-free clipboard path.
  - Mirrors `YouTubePopupView`'s structure: `NavigationStack`, "Done" toolbar item, light haptics on send.
- **`MikanRemote/MikanRemote/PendingShareDispatcher.swift`** — `@MainActor` `@Observable` class. Reads/writes the App Group slot via `SharedDefaults`. Exposes `state: .idle | .sending(url) | .sent | .failed`. Methods: `consumePending()` (called on `onOpenURL` and on `scenePhase` activation), `retry()`. Owns the 10s timeout via a `Task`.
- **`MikanRemote/MikanRemote/SharedDefaults.swift`** — tiny wrapper exposing `var pendingShareURL: String?` over `UserDefaults(suiteName: "group.<bundle-prefix>.mikanremote")`. Used by both the main app and the share extension.

### iPhone main app — edited files

- **`ContentView.swift`** — add a launcher button (`wrench.and.screwdriver` symbol) to the top safe-area inset between the YouTube icon and the gear; add `.sheet(isPresented: $showUtilities) { UtilitiesView(...) }`; bump the YouTube, Utilities, and gear icons from `.font(.caption)` (~12pt) to `.system(size: 14)` (~17% larger) via a small style helper applied to all three for consistency; render a small banner above the trackpad while `dispatcher.state` is `.sending`/`.sent`/`.failed`.
- **`SettingsView.swift`** — remove the "Utilities" section entirely.
- **`MikanRemoteApp.swift`** — instantiate `PendingShareDispatcher`, install `.onOpenURL` and `.onChange(of: scenePhase)` hooks.
- **`Info.plist`** — register the `mikanremote://` URL scheme.

### Share extension — new target `MikanRemoteShare`

- **`MikanRemoteShare/ShareViewController.swift`** — subclass `UIViewController`. In `viewDidLoad`: locate the URL in `extensionContext.inputItems → NSExtensionItem.attachments → NSItemProvider.loadItem(forTypeIdentifier: UTType.url.identifier)`. Fall back to `.text` and try to parse a URL out of it. Write to `SharedDefaults.pendingShareURL`. Open `URL(string: "mikanremote://share")` via the `extensionContext?.open(_:completionHandler:)` responder-chain walk. Then `completeRequest`. No compose UI.
- **`MikanRemoteShare/Info.plist`** — `NSExtensionAttributes.NSExtensionActivationRule` set to a predicate string that activates only when the share contains at least one `public.url`-conforming attachment:
  ```
  SUBQUERY (
    extensionItems, $extensionItem,
    SUBQUERY($extensionItem.attachments, $a,
      ANY $a.registeredTypeIdentifiers UTI-CONFORMS-TO "public.url"
    ).@count > 0
  ).@count > 0
  ```

### Build system

- **`MikanRemote/project.yml`** — add the share-extension target, App Group entitlement (`group.<bundle-prefix>.mikanremote`) on both targets, URL scheme on the main target. Run `xcodegen generate`.
- **`Local.xcconfig`** — no new variables. The App Group ID derives from the existing `BUNDLE_PREFIX`.

### Server, protocol — no changes.

## Data flow

### Path A — share-sheet handoff

1. User taps Share in Safari (or any URL host) → picks **MikanRemote**.
2. `ShareViewController` extracts the URL, writes it to App Group (`pendingShareURL = "<url>"`), opens `mikanremote://share`, calls `completeRequest`. iOS dismisses the share UI and switches to MikanRemote.
3. MikanRemote foregrounds (or cold-launches). `MikanRemoteApp`'s `.onOpenURL` fires with `mikanremote://share` and calls `dispatcher.consumePending()`.
4. Dispatcher reads the slot. State → `.sending(url)`. Banner: "Sending to <hostname>…".
5. If `connectionManager.isConnected && hostname != nil` *now*, send `openURL(url:)` immediately, clear slot, state → `.sent`, banner "Sent ✓" for 1.2s, then `.idle`.
6. If not ready, dispatcher observes those two values; on the transition to ready, send and proceed as in (5). A 10s deadline `Task` races: if it fires first, state → `.failed`, banner "Couldn't reach Mac — Retry". URL stays in the slot.
7. On retry tap, dispatcher re-enters `.sending` and re-arms the deadline. `connectionManager.attemptReconnect()` is called if the connection is in a non-ready state.

**Already-foregrounded edge case:** if MikanRemote is already on screen when the share happens, `.onOpenURL` still fires; same flow. We do not rely on `scenePhase` transitions for this case.

**Second share before first drains:** the new `ShareViewController` writes its URL into the slot, overwriting the previous. The dispatcher always re-reads the slot on every state-machine tick rather than capturing the URL by value, so only the latest URL is sent.

### Path B — clipboard via `PasteButton` inside Utilities sheet

1. User opens the sheet, taps **Paste**. iOS hands a `URL` to the closure (no privacy toast — that is the entire reason for using `PasteButton` over `UIPasteboard.general.string`).
2. `connectionManager.send(.openURL(url: url.absoluteString))` immediately.
3. Light haptic. Button briefly shows "Sent ✓" then resets. Sheet stays open.

(No App Group involvement on this path — main app is already foregrounded and connected.)

### Path C — typed/pasted into textbox

1. User taps the TextField, types or pastes, taps **Send**.
2. URL validated by `URL(string:)`; if nil, the Send button is disabled.
3. Same `openURL` send + haptic + brief "Sent ✓" as path B. Field clears.

### Path D — Take Screenshot button

Unchanged behavior, moved location only. `connectionManager.send(.performCommand(command: "screenshot"))` — server hits ⇧⌘3.

## Testing

### Manual end-to-end

- **Path A happy.** Share a YouTube link from Safari → MikanRemote → Mac browser opens the URL within ~1s when WS is hot.
- **Path A cold reconnect.** Force-quit MikanRemote. Share a URL. Watch the banner sit at "Sending to <hostname>…" through reconnect, then flip to "Sent ✓".
- **Path A timeout.** Disable Mac Wi-Fi, share from iPhone, wait 10s → "Couldn't reach Mac — Retry". Re-enable Wi-Fi, tap Retry → success.
- **Path A overwrite.** Share URL #1 with WS down. Before reconnect, share URL #2. After reconnect, only URL #2 should open on the Mac.
- **Paste path.** Copy a URL in Safari, open Utilities, tap Paste → no iOS privacy toast, URL opens on Mac.
- **Textbox path.** Type a URL, tap Send → opens on Mac. Empty/malformed → Send disabled.
- **Screenshot path.** Open Utilities, tap Take Screenshot → ⇧⌘3 fires on Mac.
- **Settings cleanup.** Open Settings → confirm Utilities section is gone.
- **Icon sizing.** Eyeball the three top-bar icons (YouTube, wrench, gear) — all visibly larger and consistent.

### Unit tests (iPhone target)

- **`PendingShareDispatcherTests`** — feed a fake connection-state source and a fake clock; assert state transitions:
  - `idle → sending → sent` on ready connection.
  - `idle → sending → failed` after timeout.
  - Retry from `failed` re-enters `sending`.
  - Slot mutation while pending updates the URL that gets sent.
  - The clock fake is the reason this test is worth writing — the real-time deadline is the part most likely to regress.

### Skipped on purpose

- No XCUITest — manual is faster for a personal-use app, per the project's existing style.
- No share-extension unit test — the extension code is ~30 lines of boilerplate URL extraction; manual smoke covers it.
- No new MikanProtocol tests — `openURL` already round-trips in `MessagesTests`.
