# BAR MODULE KNOWLEDGE BASE

## OVERVIEW
Primary system panel supporting horizontal (top/bottom) and vertical (left/right) orientations, reactive auto-hiding, and space reservation via Quickshell's `PanelWindow`. Rendered inside `UnifiedShellPanel`.

## STRUCTURE
- **Core Layout**:
  - `BarContent.qml` (767 lines): Orchestrates widget groups via `RowLayout`/`ColumnLayout`. Manages auto-hide with `reveal` property + `hideDelayTimer`.
  - `BarBg.qml` / `BarBgShadow.qml`: Background aesthetic layers.
- **Widgets**:
  - `clock/`: Time, date, weather integration (`Clock.qml` — 672 lines).
  - `systray/`: SNI-based system tray.
  - `workspaces/`: Compositor workspace visualization and navigation.
  - `IntegratedDock.qml`: Taskbar-style dock embedded directly into bar layout.
- **System Indicators**: Volume, brightness, battery, power profile sliders/buttons.

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **Auto-hide logic** | `BarContent.qml` | `reveal` property + `hideDelayTimer` |
| **Space reservation** | Parent: `shell.qml` → `ReservationWindows` | `exclusiveZone` calculation |
| **Adding widgets** | `BarContent.qml` | Update `horizontalLayout` or `verticalLayout` |
| **Integrated dock** | `IntegratedDock.qml` | App switching within bar |
| **Clock/Weather** | `clock/Clock.qml` | Complex: 672 lines, multiple display modes |

## CONVENTIONS
- **Adaptive styling**: Widgets use `startRadius`/`endRadius` for "pill" continuity based on group position.
- **Visibility registration**: Panels must register with `Visibilities` in `Component.onCompleted`.
- **Orientation**: ALWAYS handle both `horizontal` and `vertical` cases in UI components.
- **Config binding**: Use `Config.bar.*` properties for all layout-related state.
- **Screen filtering**: Respects `Config.bar.screenList` for multi-monitor control.
