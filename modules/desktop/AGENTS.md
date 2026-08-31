# Desktop Module

## OVERVIEW
Desktop background layer with icon grid, supporting drag-and-drop reordering, thumbnails, and file operations via DesktopService.

## STRUCTURE
- `Desktop.qml` — PanelWindow with icon grid. Uses WlrLayershell Bottom layer. Grid computed from `iconSize` + `spacingVertical`.
- `DesktopIcon.qml` — Individual icon delegate. Handles click/double-click, context menu, thumbnail loading.

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Icon positioning | Desktop.qml:48-51 | Grid cell dimensions from `Config.desktop.iconSize` |
| Drag-and-drop | Desktop.qml:146-183 | DragHandler + DropArea with index calculation |
| Thumbnail logic | DesktopIcon.qml:20-48 | FileView watches thumbnail path; triggers refresh |
| Icon rendering | DesktopIcon.qml:137-208 | Normal vs tinted components via `Config.tintIcons` |
| File operations | Desktop.qml:104-133 | Context menu delegates to `DesktopService.executeDesktopFile/openFile/trashFile` |

## CONVENTIONS
- Grid uses `Repeater` bound to `DesktopService.items` (list model)
- Cell calculation: `maxRows = height / cellHeight`, `maxColumns = width / cellWidth`
- Icon index mapped to grid: `x = floor(index / maxRows) * cellWidth`, `y = (index % maxRows) * cellHeight`
- Layer: `WlrLayer.Bottom` with namespace `"ambxst:desktop"`
- Thumbnail refresh uses integer property increment pattern
- Context menu via `Visibilities.contextMenu.openCustomMenu()`

## ANTI-PATTERNS
- Never hardcode icon sizes. Use `Config.desktop.iconSize`, `Config.desktop.spacingVertical`
- Don't modify DesktopService.items directly. Use `DesktopService.moveItem()` for reordering
- Avoid raw Rectangle for icon backgrounds. Use `Styling.srItem()` with appropriate variant
- Don't calculate positions without considering bar position margins (top/bottom/left/right)
