# PROJECT KNOWLEDGE BASE

**Generated:** 2026-03-01
**Framework:** QtQuick / Quickshell
**Language:** QML / JavaScript

## IMPORTANT: axctl Build Requirement

When changes are made to axctl (in `/home/adriano/Repos/Axenide/axctl/`), manual build and install is required:

1. Build: `cd /home/adriano/Repos/Axenide/axctl && go build -o bin/axctl .`
2. Install: Replace `/usr/local/bin/axctl` with the new binary (requires manual intervention)

The agent cannot test axctl changes directly because the daemon runs in the user's session environment.

## OVERVIEW
Ambxst is a highly customizable Wayland shell built with Quickshell. It provides a unified panel (bar, dock, notch), dashboard, lockscreen, desktop widgets, and notification system, driven by a reactive JSON configuration system. Multi-monitor support via `Variants` on `Quickshell.screens`.

## STRUCTURE
```
./
├── config/               # Config singleton + JSON defaults (see config/AGENTS.md)
│   └── defaults/*.js     # Blueprint for each config domain (bar, theme, ai, etc.)
├── modules/
│   ├── bar/              # Panel widgets: clock, systray, workspaces, indicators
│   ├── components/       # Reusable UI primitives + GLSL shaders (55 files)
│   ├── corners/          # Rounded screen corners overlay
│   ├── desktop/          # Desktop background + icon grid
│   ├── dock/             # App dock (standalone or integrated into bar)
│   ├── frame/            # Screen border/glow effect
│   ├── globals/          # GlobalStates.qml — transient runtime state
│   ├── lockscreen/       # WlSessionLock + PAM authentication
│   ├── notch/            # Dynamic island UI (launcher, dashboard, notifications)
│   ├── notifications/    # Notification popup system + history
│   ├── services/         # Backend singletons (30+): Battery, AI, Network, etc.
│   ├── shell/            # UnifiedShellPanel + ReservationWindows + OSD
│   ├── theme/            # Colors, Icons, Styling singletons + app generators
│   ├── tools/            # Screenshot, screen recording, mirror, color picker
│   └── widgets/          # Complex overlays: dashboard, launcher, overview, etc.
│       ├── config/       # Standalone settings window
│       ├── dashboard/    # Main hub: controls, metrics, assistant, clipboard, notes
│       ├── defaultview/  # Notch idle content (compact player, notification indicator)
│       ├── launcher/     # App search + multi-tab launcher
│       ├── overview/     # Mission Control workspace overview
│       ├── powermenu/    # Lock, logout, shutdown actions
│       ├── presets/      # Theme/layout preset switcher
│       └── tools/        # Quick utility access (OCR, recording, etc.)
├── assets/               # Wallpapers, color presets, AI provider configs, sounds
├── scripts/              # Python/Bash backends (system monitor, clipboard, OCR)
├── nix/                  # Nix flake, packages, and module definitions
├── shell.qml             # Entry point: ShellRoot, Variants, service init
└── cli.sh                # Launch wrapper and IPC controller
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **Entry Point** | `shell.qml` | `ShellRoot` → `Variants` per screen for each layer |
| **Config Logic** | `config/Config.qml` | >3100 lines. `FileView` + `JsonAdapter` persistence |
| **Transient State** | `modules/globals/GlobalStates.qml` | Window visibility, active modes, runtime flags |
| **Services** | `modules/services/*.qml` | 30+ singletons. System integration layer |
| **Theme/Colors** | `modules/theme/Colors.qml` | Watches `~/.cache/ambxst/colors.json` reactively |
| **Styling** | `modules/theme/Styling.qml` | `radius()`, `fontSize()`, `getStyledRectConfig()` |
| **UI Primitives** | `modules/components/` | `StyledRect`, `BarPopup`, `SearchInput`, shaders |
| **Dashboard** | `modules/widgets/dashboard/` | Tabbed hub with LRU lazy-loading |
| **Launcher** | `modules/widgets/launcher/LauncherView.qml` | Unified search: apps, clipboard, emoji |
| **Bar Layout** | `modules/bar/BarContent.qml` | Auto-hide, horizontal/vertical, widget groups |
| **Notch** | `modules/notch/Notch.qml` | Dynamic island with StackView navigation |
| **Overview** | `modules/widgets/overview/` | Mission Control workspace view |
| **Lockscreen** | `modules/lockscreen/LockScreen.qml` | PAM auth + `WlSessionLockSurface` |
| **Notifications** | `modules/notifications/` | Popup system + delegate + history |
| **Adding Config** | `config/defaults/*.js` + `Config.qml` | Always update both when adding keys |

## CODE MAP

| Symbol | Type | Location | Role |
|--------|------|----------|------|
| `Config` | Singleton | `config/Config.qml` | Central config store. Reactive to JSON file changes |
| `GlobalStates` | Singleton | `modules/globals/GlobalStates.qml` | Shared runtime state (non-persistent) |
| `Visibilities` | Singleton | `modules/services/Visibilities.qml` | UI visibility/layering manager per screen |
| `Colors` | Singleton | `modules/theme/Colors.qml` | Dynamic color palette from JSON |
| `Styling` | Singleton | `modules/theme/Styling.qml` | Shared style utilities (radius, font, variants) |
| `Icons` | Singleton | `modules/theme/Icons.qml` | Phosphor-Bold icon font character map |
| `StyledRect` | Component | `modules/components/StyledRect.qml` | Base themed container (300+ usages) |
| `GradientCache` | Singleton | `modules/components/GradientCache.qml` | GPU texture sharing optimization |
| `UnifiedShellPanel` | Component | `modules/shell/UnifiedShellPanel.qml` | Full-screen `PanelWindow` for Bar + Notch + Dock |
| `ShellRoot` | Component | `shell.qml` | Root window. `Variants` per screen |
| `AxctlService` | Singleton | `modules/services/AxctlService.qml` | Compositor abstraction (focus, dispatch) |
| `StateService` | Singleton | `modules/services/StateService.qml` | JSON persistence for session state |
| `FocusGrabManager` | Singleton | `modules/services/FocusGrabManager.qml` | Input focus coordination |

## CONVENTIONS
- **Singletons**: `pragma Singleton` + `Singleton { id: root }` for all services and global state.
- **Imports**: `import qs.modules.*` namespace. Resolved by Quickshell's module system, not `qmldir` files.
- **Persistence**: `FileView` watches JSON on disk; `JsonAdapter` creates bidirectional QML bindings.
- **Formatting**: 4-space indent.
- **Defaults**: New config keys MUST have entries in `config/defaults/*.js`.
- **Multi-monitor**: `Variants { model: Quickshell.screens }` pattern for per-screen instances.
- **StyledRect variants**: Use `"pane"`, `"popup"`, `"common"`, `"internalbg"`, `"focus"` for containers.
- **Null safety**: Always null-check nested properties in QML to avoid `TypeError: Value is undefined`.
- **Bulk config**: Use `root.pauseAutoSave` when updating multiple Config properties at once.
- **Service init**: Critical services init on next tick via `Qt.callLater`; non-critical deferred 2s (see `shell.qml:280-302`).
- **Async safety**: Use `Qt.callLater()` when modifying lists inside process handlers.

## ANTI-PATTERNS (THIS PROJECT)
- **Hardcoding**: NEVER hardcode colors/sizes. Use `Config.theme.*`, `Config.bar.*`, `Colors.*`, `Styling.*`.
- **Direct Config Props**: AVOID modifying `Config` properties directly; they are bound to `JsonAdapter`.
- **Global Pollution**: Do not add properties to `root` in `shell.qml`. Use `GlobalStates`.
- **Raw JS Objects**: `JSON.parse()` results have NO QML signals. Never use them in `Connections` blocks.
- **Missing Defaults**: NEVER add a config key without updating `config/defaults/*.js`.
- **StyledRect bypass**: NEVER create raw `Rectangle` containers. Use `StyledRect` with a variant.

## COMMANDS
```bash
# Run shell (requires Quickshell + Hyprland)
qs -p shell.qml
# Or via CLI wrapper:
./cli.sh

# Install (Arch/Fedora/NixOS)
curl -L get.axeni.de/ambxst | sh
```

## NOTES
- `Config.qml` is >3100 lines. Modify with care; use `pauseAutoSave` for bulk edits.
- Large files (>1000 lines): `ClipboardTab`, `NotesTab`, `TmuxTab`, `BindsPanel`, `ShellPanel`, `PresetsTab`, `ThemePanel`, `LauncherView`, `AssistantTab`, `Ai.qml`.
- The `qs.` import prefix is a Quickshell VFS construct, not a physical directory.
- `screenshotToolMode` in `GlobalStates.qml` is **DEPRECATED**.
- Gemini AI provider doesn't support the `system` role; handled in `services/ai/strategies/`.
- `axctl` is a core part of this project. It abstracts compositor interactions. It is one of Axenide's projects and the source code is available at `/home/adriano/Repos/Axenide/axctl/`.
- We register a changelog in a website. The local repo for this website is at `/home/adriano/Repos/Axenide/web/`. The changelog entries are stored in `content/ambxst/changelog/` as Zola markdown files. Write following the structure by referencing other entries, and add links to PRs and issues when relevant. Only write a changelog when the user asks for it.

- Some projects to keep in mind for reference:
  - DankMaterialShell (DMS): https://github.com/AvengeMedia/DankMaterialShell
  - Noctalia: https://github.com/noctalia-dev/noctalia-shell
  - end-4 Dotfiles: https://github.com/end-4/dots-hyprland
  - Hyprland: https://github.com/hyprwm/hyprland
  - MangoWC: https://github.com/DreamMaoMao/mangowc
  - Niri: https://github.com/YaLTeR/niri
