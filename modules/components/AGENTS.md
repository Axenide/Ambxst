# COMPONENTS KNOWLEDGE BASE

## OVERVIEW
Atomic design library for the Ambxst shell. 26 QML components + 29 GLSL shaders (`.frag`/`.vert`/`.qsb`). Every themed container in the shell ultimately uses `StyledRect`. Shader-driven UI for gradients, wavy animations, and panel blur effects.

## STRUCTURE
### Layout & Containers
| Component | Role |
|-----------|------|
| `StyledRect.qml` | **THE** base container. 300+ usages. `variant` prop selects style from `Styling.qml` |
| `PaneRect.qml` | Simplified pane-specific container |
| `Separator.qml` | Visual divider between sections |
| `ActionGrid.qml` | Flexible button grid (row or grid layout). Used by PowerMenu, ToolsMenu |

### Input
| Component | Role |
|-----------|------|
| `SearchInput.qml` | Text entry with icon, prefix, escape-to-clear |
| `StyledSlider.qml` | Standard slider (volume, brightness, progress) |
| `PositionSlider.qml` | Media position/seek slider |
| `SegmentedSwitch.qml` | Multi-option toggle (radio-button style) |
| `CircularControl.qml` | Circular knob for volume/mic |
| `ToggleButton.qml` | Icon button with tooltip and toggle state |

### Display & Feedback
| Component | Role |
|-----------|------|
| `StyledToolTip.qml` | Themed tooltip |
| `BarPopup.qml` | Base for all bar/notch flyout popups. Requires `anchorItem` + `bar` ref |
| `ContextMenu.qml` | Right-click context menu |
| `OptionsMenu.qml` | Dropdown option selector |

### Animation & Visuals
| Component | Role |
|-----------|------|
| `WavyLine.qml` | Signature animated progress line (custom shader) |
| `CircularWavyProgress.qml` | Circular animated progress indicator |
| `CarouselProgress.qml` | Step-based progress dots |
| `DiagonalStripePattern.qml` | Decorative pattern overlay |
| `BgShadow.qml` / `Shadow.qml` | Drop shadow effects |
| `Outline.qml` | Border outline effect |
| `Tinted.qml` / `TintedWallpaper.qml` | Color tint overlays |

### Utility & Core
| Component | Role |
|-----------|------|
| `GradientCache.qml` | **Singleton**. Shares GPU gradient textures across `StyledRect` instances |
| `GradientCanvas.qml` | Canvas-based gradient renderer |
| `UnifiedPanelEffect.qml` | Complex shader for panel shadows + borders |

## CONVENTIONS
- **StyledRect variants**: Always pass `variant` as one of: `"pane"`, `"popup"`, `"common"`, `"internalbg"`, `"focus"`. Variant config comes from `Styling.getStyledRectConfig()`.
- **Property aliasing**: Components expose internal state via `property alias` for clean external APIs.
- **Reactive styling**: All components use `Config.resolveColor()` and `Styling.radius()`. Changing a JSON preset updates the entire library instantly.
- **BarPopup pattern**: Flyouts require an `anchorItem` and `bar` reference to anchor correctly to the shell panel.
- **Shader binaries**: `.qsb` files are pre-compiled shaders. Regenerate with `qsb` tool if `.frag`/`.vert` sources change.

## ANTI-PATTERNS
- Using raw `Rectangle` instead of `StyledRect` for any container.
- Hardcoding colors, radii, or font sizes instead of using `Colors.*`, `Styling.radius()`, `Styling.fontSize()`.
- Creating popups without the `anchorItem`/`bar` reference pattern from `BarPopup`.
