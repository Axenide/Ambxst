# AGENTS.md - modules/widgets/overview/

## OVERVIEW
Mission Control-style workspace overview. Two layout modes: grid (default) and scrolling. Shows all workspaces with window previews, supports window dragging between workspaces, and fuzzy search.

## STRUCTURE

| File | Role |
|------|------|
| `OverviewPopup.qml` | PanelWindow container. Handles search input, backdrop, visibility state |
| `OverviewView.qml` | Loader switching between grid/scrolling layouts based on `GlobalStates.compositorLayout` |
| `Overview.qml` | Standard grid overview. Workspace grid with scaled window previews |
| `ScrollingOverview.qml` | Vertical scrolling layout. Auto-centers on active workspace |
| `ScrollingWorkspace.qml` | Individual workspace in scrolling mode. Handles horizontal scroll for window overflow |
| `OverviewWindow.qml` | Window delegate in grid view. Drag, focus, close, search highlighting |
| `OverviewButton.qml` | Toggle button to open/close overview |

## WHERE TO LOOK

| Task | File | Notes |
|------|------|-------|
| Entry point | `OverviewPopup.qml` | PanelWindow with layershell, search input, loads OverviewView |
| Grid layout | `Overview.qml` | Workspace grid, window positioning, active indicator |
| Scrolling layout | `ScrollingOverview.qml` | Vertical Flickable, workspace list, auto-scroll to active |
| Window rendering | `OverviewWindow.qml` | ScreencopyView preview, drag handling, tooltip |
| Search logic | `Overview.qml:60-134` | Fuzzy matching algorithm, score calculation |
| Workspace groups | `Overview.qml:31` | `workspaceGroup = floor((activeWorkspaceId - 1) / workspacesShown)` |

## CONVENTIONS

- Uses `AxctlService.dispatch()` for Hyprland commands (workspace switch, window move/focus)
- Uses `CompositorData.windowList` and `CompositorData.monitors` for window data
- Uses `ToplevelManager.toplevels` + `ScreencopyView` for live window previews
- Uses `Styling.srItem("overprimary")` for overview accent color
- Config keys: `Config.overview.scale`, `rows`, `columns`, `workspaceSpacing`
- Two layouts via conditional Component in `OverviewView`: `GlobalStates.compositorLayout === "scrolling"`
- Drag reparenting in scrolling mode uses `dragOverlay` Item to escape clipping
- Search in child components synced via property binding from parent

## ANTI-PATTERNS

- Don't hardcode workspace dimensions. Use `monitorData.scale`, `barPosition`, `barReserved` to calculate
- Don't use window position directly. Scale by `Config.overview.scale` for overview display
- Don't forget `Qt.callLater()` for async focus after overview closes
- Don't calculate workspace ID from mouse position without bounds checking
- Don't forget to reset `horizontalScrollOffset` when workspace windows change in scrolling mode