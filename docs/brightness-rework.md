# Brightness Control Rework — Design Document

## Context

The current brightness control in ambxst exhibits several symptoms that
frustrate users:

1. The on-screen display (OSD) does not react to Hyprland keybinds
   (`XF86MonBrightnessUp` / `XF86MonBrightnessDown`).
2. The OSD / sliders "bounce" — values appear to snap back after a drag.
3. Idle hooks and external `axctl brightness …` calls take 0–5 seconds
   to propagate to the UI.

This rework unifies the slider / keybind / idle / external-CLI paths
through a single reactive pipeline that fixes all three symptoms.

## Root causes

### RC-1 — axctl broadcasts DELTA instead of absolute value

`axctl/pkg/server/server.go:1201`

```go
s.broadcastBrightnessChange(p.Monitor, p.Delta)
```

The `Brightness.Adjust` handler sends the **delta**, not the new
absolute value. Combined with RC-2 this is currently masked by an
empty monitor name that never matches QML, but it is a latent bug for
anyone scripting per-monitor increments.

### RC-2 — QML subscription loop never matches `monitor: ""`

`modules/services/Brightness.qml:159-165`

The Hyprland keybind uses `dispatcher: exec` →
`axctl brightness adjust 0.05`. axctl resolves the empty monitor name
to "all devices" and broadcasts
`Event.BrightnessChanged { monitor: "", value: 0.05 }`. The QML loop
compares `msg.monitor` against `m.monitorName()` which returns
`"backlight"` or `"ddc-N"` — empty string never matches.

### RC-3 — Hyprland exec bypasses the shell entirely

The Hyprland keybind (defined in `config/Config.qml:2431-2465`) runs as
a detached child via Hyprland's `exec` dispatcher. Neither the ambxst
Go daemon nor the QML singleton sees the event. Only `listProc`
polling picks it up — with up to 5 s lag.

### RC-4 — DDC quantization breaks the echo filter

`modules/services/Brightness.qml:323-325`

The echo filter uses a `0.02` tolerance within `1500 ms`. DDC monitors
typically quantize to 50–100 steps (0.01–0.02 per step). On coarse
monitors, the read-back may differ by more than 0.02, the filter
passes, and `monitor.brightness` snaps to the quantized value —
re-firing the OSD and the slider binding.

### RC-5 — No OSD suppression during slider drag

`modules/shell/osd/OSD.qml:194-206`

Every brightness change re-emits `brightnessChanged` → the OSD pops.
While dragging the slider, the OSD flickers continuously.

## Goals

- OSD reacts instantly to keybinds (no polling lag).
- OSD does NOT flicker during slider drag.
- DDC quantization no longer causes visible snap-back.
- Idle-hook brightness changes propagate immediately.
- Step size for keybinds: 5% (hardcoded, matches DMS default).
- Volume slider is intentionally out of scope.

## Non-goals

- Volume slider is NOT touched in this rework.
- Per-device exponential scaling / per-device minimums are NOT in
  scope.
- A Go `brightness.Manager` (the DMS pattern) is NOT introduced;
  axctl remains the single source of truth.

## Solution overview

The fix has three pillars:

1. **Broadcast semantics in axctl**: emit per-device events with the
   absolute value, keyed by `MonitorKey(d)` (e.g. `"backlight"`,
   `"ddc-N"`) so QML can match them.
2. **Two-flag echo suppression in QML**: separate "user is dragging"
   from "OSD should show on next echo" (DMS pattern from
   `DisplayService.qml:638-668`).
3. **`Binding { when: !isDragging }`** pattern in sliders (DMS pattern).

Plus a global `GlobalStates.suppressOsd` 2 s cooldown for cross-service
suppression (DMS `SessionData.suppressOSD` pattern).

## Detailed design

### 1. axctl changes (repo: Axenide/axctl)

#### `pkg/server/brightness.go`

Add `ReadCurrent(d Device) (float64, bool)` and
`MonitorKey(d Device) string` helpers. `ReadCurrent` re-reads the
post-apply value via `brightnessctl get` or `ddcutil getvcp 10`.
`MonitorKey` returns `"backlight"` or `"ddc-<bus>"` matching what QML's
`monitorName()` produces.

#### `pkg/server/server.go`

Replace `Brightness.Set` and `Brightness.Adjust` so that for every
device touched, a separate broadcast is emitted with the actual new
value and the matching monitor key.

### 2. QML changes

#### `modules/services/Brightness.qml`

- Subscription socket loop at line 159: when `name === ""`, apply to
  all ready monitors (defensive fallback).
- Per-monitor `_userControlledAt` (1 s lockout) + `_pendingOsd` (show
  OSD on next echo).
- `applyReportedBrightness(value, broadcast)` drops echoes while
  `isUserControlled()`.
- New public `setBrightness(value, suppressOsd)` so callers declare
  whether they want OSD feedback.
- New root signal `osdShouldShow(screen)` fired when pending flag
  matches an incoming echo.

#### `modules/globals/GlobalStates.qml`

Add `suppressOsd: bool` + `suppressOsdTimer` (2 s auto-clear) +
`suppressOsdTemporarily()`.

#### `modules/shell/osd/OSD.qml`

`onOsdShouldShow` gated by `GlobalStates.suppressOsd`. The
`onBrightnessChanged` continues to drive the visual value but no
longer triggers `osdVisible`.

#### `modules/services/OsdManager.qml` (NEW)

Singleton tracking which OSD is visible per screen. `showOsd(target)`
hides any existing OSD on the same screen before showing `target`.

### 3. Slider rewrite

Replace `Connections` blocks in `ControlsButton.qml` and
`WidgetsTab.qml` with declarative `Binding`:

```qml
Binding {
    target: brightnessSlider
    property: "brightnessValue"
    value: brightnessSlider.currentMonitor?.brightness ?? 0
    when: !brightnessSlider.isDragging
    restoreMode: Binding.RestoreBinding
}
```

This eliminates the snap-back: during drag the binding is suspended;
on release the binding snaps to the new value (which by then matches
the user's drag).

`onValueChanged` calls `GlobalStates.suppressOsdTemporarily()` and
passes `suppressOsd=true` to `monitor.setBrightness()` so the monitor
flags user-controlled state and drops subsequent echoes.

### 4. Config keys

#### `config/defaults/compositor.js`

```js
"osdSuppressOnDrag": true,
"osdHideInterval": 2500
```

#### `config/Config.qml`

Add `osdSuppressOnDrag` and `osdHideInterval` to the `compositorLoader`
JsonAdapter. Wire `OSD.qml` to read `Config.osdHideInterval`.

## Migration / rollback

- Phases 0–1 (axctl + monitor="" handling) are non-breaking — they
  only add events, not remove.
- Phases 2–5 (flags, suppressOsd, OSDManager) are additive in
  `Brightness.qml` and `GlobalStates.qml`. Rollback = remove the new
  properties/handlers.
- Phase 6 (Binding rewrite) replaces existing `Connections` blocks.
  Rollback = revert to git HEAD.
- axctl is installed as `/usr/local/bin/axctl`; rolling back means
  restoring the previous binary.

## Testing plan

1. Manual: drag brightness slider → OSD must NOT flicker, slider must
   not snap-back after release.
2. Manual: press `XF86MonBrightnessUp` → OSD must appear within ~50 ms.
3. Manual: external `axctl brightness set 0.5` → OSD must appear.
4. Manual: idle hook → on screen idle, OSD must update immediately
   (no 5 s wait).
5. Multi-monitor: drag one monitor's brightness → only that monitor's
   OSD appears (sync mode off); all OSDs appear (sync mode on).

## Key decisions

- **Keybind stays `dispatcher: exec`** to `axctl brightness adjust`
  (no IPC latency). axctl emits per-device broadcasts so the OSD
  reacts instantly.
- **Step size**: 5% hardcoded, no new Config key.
- **Volume**: out of scope for this rework.