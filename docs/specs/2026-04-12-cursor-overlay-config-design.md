# Cursor Overlay Configurability

**Date:** 2026-04-12

## Overview

Add two new configurable parameters to the cursor overlay: center dot size and transparent gap size. Combined with the existing overall overlay size, these three knobs fully define the cursor appearance. The outer ring thickness is derived automatically (overlay radius minus gap radius).

## New Parameters

| Parameter | Key | Type | Range | Step | Default | Unit |
|-----------|-----|------|-------|------|---------|------|
| Dot Size | `cursorDotSize` | Double | 1–15 | 1 | 5 | % of overlay diameter |
| Gap Size | `cursorGapSize` | Double | 10–45 | 1 | 33 | % of overlay diameter |

Existing parameter (unchanged):

| Parameter | Key | Type | Range | Step | Default | Unit |
|-----------|-----|------|-------|------|---------|------|
| Cursor Size | `cursorSize` | Double | 60–300 | 20 | 140 | points |

## Overlay Geometry

Given an overlay of diameter `cursorSize`:

```
outerRadius = cursorSize / 2 - 2
dotRadius   = outerRadius * (cursorDotSize / 100)
gapRadius   = outerRadius * (cursorGapSize * 2 / 100)
ringInner   = gapRadius  (derived, not stored)
```

Visual structure from center outward:
1. **Red center dot** — radius `dotRadius`
2. **Transparent gap** — from `dotRadius` to `gapRadius`
3. **Red outer ring** — from `gapRadius` to `outerRadius`

All three zones share the same center point. The dot and ring are the same red color (`RGB 0.9, 0.25, 0.15`).

## Protocol Changes

### ClientMessage.updateSettings

Add two parameters:

```swift
case updateSettings(sensitivity: Double, cursorSize: Double, cursorDotSize: Double, cursorGapSize: Double)
```

### ServerMessage.settingsSync

Add two parameters:

```swift
case settingsSync(sensitivity: Double, cursorSize: Double, cursorDotSize: Double, cursorGapSize: Double)
```

## Server Changes

### MenuBarManager

Add two new `Double` properties with `didSet` observers following the same pattern as `sensitivity` and `cursorSize`:

- `cursorDotSize` — persists to UserDefaults key `"cursorDotSize"`, calls `pushSettings()` and `cursorOverlay.updateStyle(dotSize:gapSize:)`
- `cursorGapSize` — persists to UserDefaults key `"cursorGapSize"`, calls `pushSettings()` and `cursorOverlay.updateStyle(dotSize:gapSize:)`

Initialize from UserDefaults on launch with fallback to defaults (5.0 and 33.0).

### CursorOverlayController

Add `updateStyle(dotSize: CGFloat, gapSize: CGFloat)` method that stores the new values and tears down the window (same pattern as `updateSize`). Pass dot/gap percentages into `CursorView` so `draw()` can compute radii.

### MikanServerApp (Menu Bar UI)

Move "Cursor Size" into a new **"Cursor"** section. Add two rows below it:

- **Dot Size** — minus/plus buttons, displays `"5%"` format, range 1–15%, step 1%
- **Gap Size** — minus/plus buttons, displays `"33%"` format, range 10–45%, step 1%

### Message Handling

Update `handleMessage` for `.updateSettings` to accept and apply the two new parameters. Update `pushSettings` to include them in `.settingsSync`.

## Client Changes

### ConnectionManager

Add two new `private(set) var` properties: `cursorDotSize: Double = 5.0` and `cursorGapSize: Double = 33.0`. Update `sendUpdateSettings` to include the new parameters. Update `handleServerMessage` for `.settingsSync` to store them.

### SettingsView

Move "Cursor Size" into a **"Cursor"** section. Add two rows:

- **Dot Size** — minus/plus, displays percentage, range 1–15%, step 1%
- **Gap Size** — minus/plus, displays percentage, range 10–45%, step 1%

Each button calls `sendUpdateSettings` with all four settings values.

## Files Modified

| File | Change |
|------|--------|
| `MikanProtocol/Sources/MikanProtocol/Messages.swift` | Add `cursorDotSize`, `cursorGapSize` to `updateSettings` and `settingsSync` |
| `MikanServer/MikanServer/MenuBarManager.swift` | Add properties, UserDefaults, didSet, update handleMessage/pushSettings |
| `MikanServer/MikanServer/CursorOverlayController.swift` | Add `updateStyle`, pass params to CursorView, update draw() |
| `MikanServer/MikanServer/MikanServerApp.swift` | Add Cursor section with Dot Size and Gap Size controls |
| `MikanRemote/MikanRemote/ConnectionManager.swift` | Add properties, update send/handle methods |
| `MikanRemote/MikanRemote/SettingsView.swift` | Add Cursor section with Dot Size and Gap Size controls |
| `MikanProtocol/Tests/MikanProtocolTests/MikanProtocolTests.swift` | Update any existing encode/decode tests |
