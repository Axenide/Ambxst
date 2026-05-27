# AGENTS.md - modules/notch/

## OVERVIEW
Dynamic island UI with StackView navigation, themes (default/island), and notification popup system.

## STRUCTURE

| File | Purpose |
|------|---------|
| `Notch.qml` | Core dynamic island: StackView, rounded corners with mask, theme rendering, animations |
| `NotchContent.qml` | Screen-specific wrapper: hover detection, reveal logic, persistent Loaders, visibility bindings |
| `NotchWindow.qml` | PanelWindow wrapper (disabled, commented out) |
| `NotchAnimationBehavior.qml` | Reusable animation behavior component |
| `NotchNotificationView.qml` | Notification display with StackView navigation, timestamps, hover states |

## WHERE TO LOOK

- **StackView navigation**: `Notch.qml:326-452` - push/pop transitions with scale+opacity animations
- **Theme rendering**: `Notch.qml:79-142` (default) and `Notch.qml:232-285` (island) - StyledRect with mask system
- **Reveal logic**: `NotchContent.qml:101-124` - auto-hide based on `keepHidden`, bar position, fullscreen
- **Hover detection**: `NotchContent.qml:95-148` - delay timer prevents flickering on mouse leave
- **Notification popup**: `NotchContent.qml:306-411` - styled popup below notch with StackView
- **Notification navigation**: `NotchNotificationView.qml:202-291` - wheel/scroll navigation, direction-aware transitions

## CONVENTIONS

Follows parent AGENTS.md. No additional conventions.

## ANTI-PATTERNS

- Never hardcode notch dimensions - use `Config.notchTheme`, `Config.roundness`, `Config.notchPosition`
- Avoid direct stack manipulation - use `Visibilities` service signals (onLauncherChanged, onDashboardChanged, etc.)
- Don't skip `Qt.callLater()` when pushing to StackView from Connections - prevents async list modification issues