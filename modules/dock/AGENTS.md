# AGENTS.md - modules/dock/

## OVERVIEW
Application dock supporting icon-based app launching, running indicators, and
auto-hide with hover reveal. Can be integrated into the bar or float independently.

## STRUCTURE
- `Dock.qml` — Root PanelWindow; manages visibility, auto-hide, and screen reservation.
- `DockContent.qml` — Layout and item rendering; horizontal/vertical orientation support.
- `DockItem.qml` — Individual dock entry; icon, animation, click handling.
- `DockIndicator.qml` — Running window indicator dots.

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Entry point | `Dock.qml` | PanelWindow with layershell; registers with `Visibilities` |
| Layout | `DockContent.qml` | Flow layout; orientation-aware; auto-hide logic |
| Item rendering | `DockItem.qml` | App icon, hover/press animations, running indicator |
| Config | `Config.dock.*` | All dock settings (position, size, theme, etc.) |

## CONVENTIONS
- Uses `Styling.radius()`, `Styling.fontSize()` for consistent sizing.
- Uses `AxctlService` for app launching and window focus.
- Uses `CompositorData` for running window state.
- Dock items use `Drag`/`Drop` for potential future reordering support.
- Auto-hide uses `hoverActive` property + `hideDelayTimer` pattern (same as bar).

## ANTI-PATTERNS
- Don't hardcode icon sizes — use `Config.dock.iconSize`.
- Don't forget to register/unregister with `Visibilities` in `Component.onCompleted`/`onDestruction`.
- Don't bind to live properties without throttling (use `Timer` for polling).
