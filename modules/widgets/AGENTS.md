# AGENTS.md - modules/widgets/

## OVERVIEW
Dashboard widgets and overlay panels: overview, presets, powermenu, settings,
clipboard, notes, metrics, wallpapers, emoji, tmux, and more.

## STRUCTURE
| Subdirectory | Role |
|-------------|------|
| `overview/` | Mission Control-style workspace overview (grid + scrolling) |
| `presets/` | Color preset selector with live preview |
| `powermenu/` | Power actions (lock, suspend, reboot, shutdown) |
| `dashboard/` | Main dashboard with tabbed widgets |
| `config/` | Settings window with categorized tabs |
| `lockscreen/` | Lock screen UI (also in `modules/lockscreen/`) |

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Dashboard entry | `Dashboard.qml` | Tabbed container; lazy-loads tabs |
| Tab management | `DashboardTab.qml` | Base class for dashboard tabs |
| Window management | `OverviewPopup.qml` | PanelWindow; search, layout switching |
| Settings | `SettingsWindow.qml` | Scrollable settings with search |
| Config binding | All widgets | Use `Config.<module>.<prop>` for all settings |

## CONVENTIONS
- Dashboard tabs use `Loader` with `active: false` for lazy loading.
- Overview uses `AxctlService` for compositor commands.
- All widgets use `Styling.radius()`, `Styling.fontSize()`, `Styling.animEasing`.
- Icons go through `Icons.qml`, never raw glyphs.
- Colors come from `Colors.qml`, never hardcoded hex.
- Use `Qt.callLater()` when modifying models inside `Process.onStdout` handlers.

## ANTI-PATTERNS
- Don't load heavy widgets eagerly — use `Loader` with `active: false`.
- Don't bind to live system properties without throttling.
- Don't forget to clean up `Connections` targets when items are destroyed.
- Don't use `Component.onCompleted` for async initialization that depends on config —
  gate with `Config.initialLoadComplete` instead.
