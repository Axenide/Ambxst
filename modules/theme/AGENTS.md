# THEME KNOWLEDGE BASE

## OVERVIEW
Dynamic theming layer providing colors, icons, and style utilities as singletons. Also generates config files for external apps (Kitty, GTK, Discord, etc.) from the active color palette.

## STRUCTURE
| File | Type | Role |
|------|------|------|
| `Colors.qml` | Singleton | Watches `~/.cache/ambxst/colors.json`. Provides reactive palette (`primary`, `secondary`, `surface`, `onSurface`, etc.) |
| `Styling.qml` | Singleton | `radius(offset)`, `fontSize(offset)`, `getStyledRectConfig(variant)`. Animation durations, spacing constants |
| `Icons.qml` | Singleton | Character map for Phosphor-Bold icon font (`lock`, `power`, `layout`, etc.) |
| `*Generator.qml` | Components | Translate `Colors` palette into config files for other apps |

### Generators
- `GtkGenerator.qml` — GTK3/4 CSS theme
- `KittyGenerator.qml` — Kitty terminal colors
- `DiscordGenerator.qml` — Discord CSS injection
- `NvChadGenerator.qml` — NvChad/Neovim theme
- `PywalGenerator.qml` — Pywal color export
- `QtCtGenerator.qml` — Qt widget theme

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **Change colors** | `Colors.qml` | Modify `~/.cache/ambxst/colors.json` or change color preset |
| **Add StyledRect variant** | `Styling.qml` → `getStyledRectConfig()` | Returns gradient, border, opacity config per variant |
| **Adjust radius/font** | `Styling.qml` | `radius(offset)` and `fontSize(offset)` apply global scaling |
| **Add icon** | `Icons.qml` | Add Phosphor-Bold unicode mapping |
| **Add app generator** | New `*Generator.qml` | Follow existing generator pattern, read from `Colors.*` |

## CONVENTIONS
- **Color access**: Always use `Colors.<property>` (e.g., `Colors.primary`, `Colors.surface`). Never hardcode hex values.
- **Radius**: Use `Styling.radius(offset)` where offset adjusts from base `Config.roundness`.
- **Font size**: Use `Styling.fontSize(offset)` for consistent text scaling.
- **Generators**: Read-only consumers of `Colors`. Write via `FileView` to app config paths.
