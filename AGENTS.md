# AGENTS.md — Ambxst

**Project:** Ambxst  
**Version:** 1.1.5  
**Framework:** QtQuick / Quickshell  
**Primary Languages:** QML, JavaScript, Python, Bash, Nix  
**Compositor:** Hyprland (via `axctl` abstraction)  
**Target Platforms:** Arch Linux, Fedora, NixOS  

---

## 1. Project Overview

Ambxst is a highly customizable Wayland shell built on [Quickshell](https://git.outfoxxed.me/outfoxxed/quickshell). It provides a unified desktop environment layer including a status bar, dynamic notch ("dynamic island"), app dock, dashboard, lockscreen, desktop widgets, notification popups, and an AI assistant sidebar. The shell is driven by a reactive JSON configuration system and supports multi-monitor setups via per-screen `Variants`.

The project was forked from [Ambxst](https://github.com/Axenide/Ambxst) and maintains the same upstream license. All Ambxst-specific modifications are provided under that same license.

### Key Differentiators from Upstream
- **130+ compositor settings** across 11 categories (vs. ~40 upstream)
- **Hardware-accelerated video wallpapers** via QtMultimedia + FFmpeg (instead of mpv)
- **Custom MangoHud integration** for real-time FPS display in the notch
- **Configurable rendering backend:** OpenGL (default) or Vulkan with threaded render loop
- **Ndot dot-matrix typography** and monochrome-with-red-accents design language

---

## 2. Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **UI Framework** | Qt 6 (QtQuick, QtQuick.Controls, QtQuick.Effects, QtQuick.Layouts) | Rendering, animations, controls |
| **Shell Runtime** | Quickshell (`qs`) | Wayland panel/surface manager, QML engine, IPC |
| **Compositor Bridge** | `axctl` (Go binary, external repo) | Hyprland abstraction: window focus, workspace dispatch, config persistence |
| **Configuration** | JSON on disk + `Quickshell.Io.FileView` / `JsonAdapter` | Reactive, file-backed persistent config |
| **Backend Scripts** | Python 3, Bash | System monitoring, clipboard, OCR, screenshots, wallpaper thumbs |
| **Color Generation** | `matugen` | Material You color extraction from wallpapers |
| **Packaging** | Nix Flake (`flake.nix`) | Reproducible builds, NixOS module, dev shells |
| **Install Script** | `install.sh` (Bash) | Arch / Fedora dependency install, repo clone, launcher setup |

### Runtime Dependencies
- **Core:** `quickshell`, `qt6-base`, `qt6-declarative`, `qt6-wayland`, `qt6-svg`, `qt6-multimedia`, `qt6-shadertools`, `kf6-syntax-highlighting`, `kf6-breeze-icons`
- **Compositor:** `hyprland`, `axctl`
- **System:** `brightnessctl`, `grim`, `slurp`, `wl-clipboard`, `wlsunset`, `wtype`, `upower`, `power-profiles-daemon`, `NetworkManager`, `bluetooth`
- **Media:** `playerctl`, `ffmpeg`, `gpu-screen-recorder`, `wf-recorder`
- **Fonts:** `ttf-phosphor-icons`, `ttf-ndot` (custom), `ttf-roboto`, `noto-fonts`, `noto-fonts-emoji`
- **Tools:** `kitty`, `tmux`, `fuzzel`, `matugen`, `tesseract`, `zenity`, `jq`, `sqlite`
- **Python packages** (installed via pipx where applicable): script dependencies are runtime-checked

---

## 3. Project Structure

```
./
├── shell.qml                 # Entry point: ShellRoot, Variants per screen, service init
├── cli.sh                    # Launch wrapper & IPC controller (brightness, lock, install, etc.)
├── install.sh                # Distribution-aware installer (Arch, Fedora, NixOS)
├── flake.nix                 # Nix flake: packages, devShells, apps, NixOS module
├── version                   # Single-line version string (e.g., "1.1.5")
│
├── config/                   # Central configuration system
│   ├── Config.qml            # >3700 lines. Singleton. FileView + JsonAdapter persistence
│   ├── ConfigValidator.js    # Deep-merge validation against defaults
│   ├── KeybindActions.js     # Keybind action dispatch table
│   └── defaults/*.js         # 14 default blueprints: bar.js, theme.js, ai.js, compositor.js, etc.
│
├── modules/                  # All QML code organized by domain
│   ├── bar/                  # Panel widgets: clock, systray, workspaces, battery, volume
│   ├── components/           # Reusable UI primitives + GLSL shaders (55 files)
│   ├── corners/              # Rounded screen-corners overlay
│   ├── desktop/              # Desktop background + icon grid
│   ├── dock/                 # App dock (standalone or integrated)
│   ├── frame/                # Screen border / glow effect
│   ├── globals/              # GlobalStates.qml — transient runtime state (non-persistent)
│   ├── lockscreen/           # WlSessionLock + PAM authentication
│   ├── notch/                # Dynamic island UI (launcher, dashboard, notifications)
│   ├── notifications/        # Popup system + delegate + history
│   ├── services/             # 43+ backend singletons (Battery, AI, Network, AxctlService, etc.)
│   ├── shell/                # UnifiedShellPanel + ReservationWindows + OSD
│   ├── sidebar/              # AI assistant sidebar
│   ├── theme/                # Colors, Icons, Styling singletons + app config generators
│   ├── tools/                # Screenshot, screen recording, mirror, color picker
│   └── widgets/              # Complex overlays
│       ├── config/           # Standalone settings window
│       ├── dashboard/        # Main hub: controls, metrics, assistant, clipboard, notes
│       ├── defaultview/      # Notch idle content (compact player, notification indicator)
│       ├── launcher/         # App search + multi-tab launcher
│       ├── overview/         # Mission Control workspace overview
│       ├── powermenu/        # Lock, logout, shutdown actions
│       ├── presets/          # Theme/layout preset switcher
│       └── tools/            # Quick utility access (OCR, recording, etc.)
│
├── scripts/                  # Python & Bash backends invoked by QML via Quickshell.Io.Process
│   ├── system_monitor.py     # CPU/RAM/GPU/disk/temp JSON output
│   ├── clipboard_watch.sh    # wl-paste --watch wrapper
│   ├── thumbgen.py           # Wallpaper thumbnail generation
│   ├── lockwall.py           # Lockscreen wallpaper blur preprocessing
│   ├── colorpicker.py        # hyprpicker wrapper
│   ├── ocr.sh                # Screenshot → OCR text extraction
│   ├── wf-record.sh          # Screen recording wrapper
│   ├── weather.sh            # Weather data fetching
│   └── ...
│
├── assets/                   # Wallpapers, color presets, AI provider configs, sounds, fonts
│   ├── presets/              # Default theme/layout presets (copied to ~/.config on first run)
│   ├── ambxst/          # Brand assets (logo, animations)
│   ├── aiproviders/          # Per-provider config templates
│   ├── colors/               # Color preset JSONs
│   └── sound/                # UI sounds
│
└── nix/                      # Nix-specific packaging
    ├── lib.nix               # `forAllSystems` helper
    ├── modules/default.nix   # NixOS module (enables services, fonts)
    └── packages/             # Granular package sets: core, apps, tools, media, fonts, tesseract
```

### Module Registration
Quickshell uses a VFS import prefix `qs.` rather than physical `qmldir` files for most modules. A few directories (e.g., `modules/bar/`, `modules/widgets/launcher/`) contain `qmldir` files for legacy compatibility, but the primary resolution mechanism is Quickshell's built-in module system.

---

## 4. Build, Run, and Test Commands

### Running Locally (Development)
```bash
# Direct Quickshell launch (requires qs in PATH)
qs -p shell.qml

# Or via the CLI wrapper (sets up QML import paths, config presets, etc.)
./cli.sh
```

### Installation (End Users)
```bash
# One-liner installer (Arch / Fedora / NixOS)
curl -sL https://github.com/Axenide/Ambxst/raw/main/install.sh | sh

# Manual clone + symlink
git clone https://github.com/Axenide/Ambxst.git ~/.local/src/ambxst
sudo ln -s ~/.local/src/ambxst/cli.sh /usr/local/bin/ambxst
```

### Nix Development Shell
```bash
# Enter a shell with all dependencies and QML_IMPORT_PATH set
nix develop

# Run directly from the flake
nix run github:Axenide/Ambxst
```

### Compositor Integration
```bash
ambxst install hyprland           # Auto-detect config mode
ambxst install hyprland --conf    # Force .conf mode (safe default)
ambxst install hyprland --lua     # Force Lua mode (Hyprland >= 0.48)
ambxst remove hyprland            # Remove integration
```

### Testing
**There is currently no automated test suite.** The project relies on:
- Manual runtime testing on Hyprland
- Visual regression testing via screenshots in PRs (see `.github/pull_request_template.md`)
- Nix flake evaluation (`nix flake check`) for packaging correctness

When modifying UI, authors are expected to provide before/after screenshots in pull requests.

---

## 5. Runtime Architecture

### Entry Point (`shell.qml`)
1. **`ShellRoot`** initializes a global `ContextMenu` and per-screen `Variants`.
2. **Per-screen layers** (stacked bottom to top):
   - `Wallpaper` (per screen)
   - `Desktop` icon grid (if enabled)
   - `UnifiedShellPanel` — contains Bar, Notch, Dock, Frame
   - `ScreenCorners` rounded overlay (if enabled)
   - `ReservationWindows` — Wayland exclusive-zone reservations for bar/dock/sidebar
   - `OverviewPopup`, `PresetsPopup` (conditional)
3. **Global overlays** (single instance):
   - `WlSessionLock` → `LockScreen` (secure lockscreen)
   - `ScreenshotTool`, `ScreenshotOverlay`, `ScreenrecordTool`, `MirrorWindow`
   - `SettingsWindow`, `OSD`
4. **Service initialization** is deferred:
   - Critical services (`CaffeineService`, `IdleService`, `GlobalShortcuts`, `BatteryAlertService`) init on next tick via `Qt.callLater`
   - Non-critical services (`NightLightService`, `GameModeService`) deferred 2s
5. **Boot splash** (`assets/ambxst/NOTHING_splash.webp`) auto-fades after ~5.3s.

### Config Lifecycle
- `Config.qml` watches `~/.config/ambxst/config/*.json` via `FileView`
- Missing files are bootstrapped from `assets/presets/Ambxst Default/`
- `JsonAdapter` creates bidirectional QML property bindings
- Changes auto-persist to disk; use `Config.pauseAutoSave` for batch updates
- `Config.initialLoadComplete` gates components that need fully initialized config

### Color System
- `Colors.qml` watches `~/.cache/ambxst/colors.json` (generated by `matugen`)
- On change, it regenerates app configs: Qt6ct, GTK, Pywal, Kitty, NvChad, Discord
- `Config.resolveColor(name)` maps semantic names (e.g., `"surface"`, `"primary"`) to actual colors

### Compositor Integration (`axctl`)
- `AxctlService.qml` is the single point of contact with Hyprland
- It reads/writes `~/.local/share/ambxst/axctl.toml`
- Dispatches workspace/window/monitor commands via the `axctl` CLI daemon
- `CompositorConfig.qml` applies shell theme colors to Hyprland decoration settings
- `CompositorKeybinds.qml` manages dynamic keybind injection

---

## 6. Code Organization and Key Symbols

### Singletons (Services & Globals)
All services use `pragma Singleton` and expose `Singleton { id: root }`.

| Symbol | File | Responsibility |
|--------|------|----------------|
| `Config` | `config/Config.qml` | Central reactive config store |
| `GlobalStates` | `modules/globals/GlobalStates.qml` | Transient runtime state (visibility flags, wallpaper manager, layout) |
| `Visibilities` | `modules/services/Visibilities.qml` | Per-screen UI visibility/layering manager |
| `Colors` | `modules/theme/Colors.qml` | Dynamic color palette from `matugen` output |
| `Styling` | `modules/theme/Styling.qml` | Shared style utilities: `radius()`, `fontSize()`, `getStyledRectConfig()` |
| `Anim` | `modules/theme/Anim.qml` | Material 3 animation system: `duration()`, `easing()`, `configure()`, global speed scale |
| `Icons` | `modules/theme/Icons.qml` | Phosphor-Bold icon font character map |
| `AxctlService` | `modules/services/AxctlService.qml` | Compositor abstraction (focus, dispatch, state sync) |
| `PerMonitorConfig` | `modules/services/PerMonitorConfig.qml` | Per-monitor config overrides (bar/notch/dock position) |
| `StateService` | `modules/services/StateService.qml` | JSON persistence for session state (layout, presets) |
| `FocusGrabManager` | `modules/services/FocusGrabManager.qml` | Input focus coordination for popups |
| `GradientCache` | `modules/components/GradientCache.qml` | GPU texture sharing optimization for gradients |

### Component Primitives
| Component | File | Usage |
|-----------|------|-------|
| `StyledRect` | `modules/components/StyledRect.qml` | Base themed container (300+ usages). Supports gradient, halftone, border, shadow variants |
| `StateLayer` | `modules/components/StateLayer.qml` | M3 interaction overlay: ripple + hover/press/focus state opacity |
| `Surface` | `modules/components/Surface.qml` | M3 elevated surface wrapper (`StyledRect` + `StateLayer`). Elevation 0-4 mapping |
| `BarPopup` | `modules/components/BarPopup.qml` | Popup anchored to bar items |
| `SearchInput` | `modules/components/SearchInput.qml` | Universal search field |
| `PaneRect` | `modules/components/PaneRect.qml` | Pane variant container |

### `StyledRect` Variants
Always use one of these string values for the `variant` property:
`"transparent"`, `"bg"`, `"popup"`, `"internalbg"`, `"barbg"`, `"pane"`, `"common"`, `"focus"`, `"primary"`, `"primaryfocus"`, `"overprimary"`, `"secondary"`, `"secondaryfocus"`, `"oversecondary"`, `"tertiary"`, `"tertiaryfocus"`, `"overtertiary"`, `"error"`, `"errorfocus"`, `"overerror"`

---

## 7. Development Conventions

### QML & JavaScript
- **Indentation:** 4 spaces
- **Imports:** Use `qs.modules.<domain>` namespace. Example: `import qs.modules.services`
- **Null safety:** Always null-check nested properties. QML configs may be undefined during load.
- **Async safety:** Use `Qt.callLater()` when modifying lists inside process handlers.
- **Raw JS objects:** Results from `JSON.parse()` have NO QML signals. Never use them in `Connections` targets.
- **Focus management:** Never call `forceActiveFocus()` directly on popups. Use `FocusGrabManager.requestGrab(item)` / `releaseGrab(item)`.
- **Color resolution:** Never hardcode colors. Use `Config.resolveColor(name)` or bind to `Colors.*`.

### Configuration
- **Atomic defaults:** Every new config key MUST have a corresponding entry in `config/defaults/<domain>.js`.
- **Bulk updates:** Wrap multi-property config changes in `Config.pauseAutoSave = true` ... `Config.pauseAutoSave = false`.
- **Bind to Config:** UI elements should bind to `Config.<module>.<property>`. Avoid local state for persistent settings.
- **Validation:** Add type constraints in `ConfigValidator.js` when introducing new config shapes.

### Anti-Patterns (Strictly Avoid)
1. **Hardcoding:** NEVER hardcode colors, sizes, or durations. Use `Config.theme.*`, `Config.bar.*`, `Colors.*`, `Styling.*`.
2. **Direct Config Props:** AVOID modifying `Config` properties directly outside the `JsonAdapter` binding system.
3. **Global Pollution:** Do not add properties to `root` in `shell.qml`. Use `GlobalStates` for shared transient state.
4. **Missing Defaults:** NEVER add a config key without updating `config/defaults/*.js`.
5. **StyledRect bypass:** NEVER create raw `Rectangle` containers. Use `StyledRect` with an appropriate variant.

---

## 8. Security Considerations

- **Lockscreen:** Uses `WlSessionLock` (Wayland secure session lock protocol) + PAM authentication via `Quickshell.Services.Pam`. The PAM config is in `config/pam/`.
- **Credential storage:** API keys (AI providers) are stored via `KeyStore.qml` which delegates to a Python script (`scripts/keystore.py`). No credentials are committed to the repo.
- **Process execution:** QML spawns external processes via `Quickshell.Io.Process`. All shell commands are constructed internally; no user input is passed directly to shell interpreters without sanitization.
- **Compositor config:** `axctl.toml` is written to the user's data directory (`~/.local/share/ambxst/`). The `axctl` daemon runs as the user and communicates over IPC, not network sockets.
- **File paths:** Avoid traversing outside `~/.config/ambxst/` and `~/.local/share/ambxst/` for user-facing file operations.

---

## 9. Deployment and Release Process

### Versioning
- The version is stored in the plain-text file `version` at the repo root.
- `flake.nix` reads this file at evaluation time.

### Nix Package
- `nix/packages/default.nix` builds a `buildEnv` named `Ambxst-${version}`.
- The launcher script (`ambxst`) wraps `cli.sh` with:
  - `AMBXST_QS` pointing to the Quickshell binary
  - `QML2_IMPORT_PATH` / `QML_IMPORT_PATH` set for Nix store Qt modules
  - `FONTCONFIG_PATH` for bundled fonts

### Installer (`install.sh`)
1. Detects distro (Arch, Fedora, NixOS, or unknown)
2. Installs dependencies via `pacman`/`yay` (Arch), `dnf` (Fedora), or `nix profile` (NixOS)
3. Clones or updates the repo to `~/.local/src/ambxst`
4. Builds Quickshell from source if not available (on unsupported distros)
5. Creates `/usr/local/bin/ambxst` launcher
6. Configures systemd services: disables `iwd`, enables `NetworkManager` and `bluetooth`

### Pull Requests
- Template is in `.github/pull_request_template.md`
- Required: description of changes, screenshots for UI changes, behavior impact statement
- No CI/CD workflows are configured; reviewers rely on Nix flake evaluation and manual testing

---

## 10. Where to Look for Common Tasks

| Task | Primary Location | Notes |
|------|------------------|-------|
| **Add config key** | `config/defaults/<domain>.js` + `config/Config.qml` | Both MUST be updated |
| **Change bar layout** | `modules/bar/BarContent.qml` | Auto-hide, horizontal/vertical, widget groups |
| **Change notch behavior** | `modules/notch/Notch.qml`, `modules/notch/NotchContent.qml` | StackView navigation, animations |
| **Add AI provider** | `modules/services/ai/strategies/` | Implement `ApiStrategy` interface |
| **Theme / colors** | `modules/theme/Colors.qml`, `modules/theme/Styling.qml` | Watches `~/.cache/ambxst/colors.json` |
| **Animations (M3)** | `modules/theme/Anim.qml` | Standard / Emphasized / Spatial curves with global speed scale |
| **Interaction states** | `modules/components/StateLayer.qml`, `modules/components/Surface.qml` | Ripple + M3 elevation surfaces |
| **System monitoring** | `modules/services/SystemResources.qml` | Reads `scripts/system_monitor.py` JSON output |
| **Clipboard** | `modules/services/ClipboardService.qml` | Interacts with `scripts/clipboard_*.sh` |
| **Lockscreen** | `modules/lockscreen/LockScreen.qml` | `WlSessionLockSurface` + PAM |
| **Screenshots** | `modules/tools/ScreenshotTool.qml` | Uses `grim`/`slurp` |
| **Screen recording** | `modules/tools/ScreenrecordTool.qml` | Uses `wf-recorder` / `gpu-screen-recorder` |
| **Add new widget/tab to dashboard** | `modules/widgets/dashboard/` | Lazy-loaded LRU tabs |
| **Overview / Mission Control** | `modules/widgets/overview/` | Workspace window overview |
| **Notifications** | `modules/notifications/` | Popup system + history |
| **Compositor settings** | `modules/services/CompositorConfig.qml` | Live apply to Hyprland via `axctl` |

---

## 11. Important Notes for Agents

- `Config.qml` is >3700 lines. Modify with extreme care; use `pauseAutoSave` for bulk edits.
- Large files (>1000 lines): `ClipboardTab`, `NotesTab`, `TmuxTab`, `BindsPanel`, `ShellPanel`, `PresetsTab`, `ThemePanel`, `LauncherView`, `AssistantTab`, `Ai.qml`.
- The `qs.` import prefix is a Quickshell VFS construct, not a physical directory.
- `screenshotToolMode` in `GlobalStates.qml` is **DEPRECATED**.
- Gemini AI provider does not support the `system` role; this is handled in `modules/services/ai/strategies/GeminiApiStrategy.qml`.
- `axctl` is maintained in a separate repository (`github:Axenide/axctl`). When changes are made there, a manual build and install is required (the daemon runs in the user's session environment and cannot be tested by this agent directly).
- Changelog entries for the project website are stored in a separate repo at `/home/adriano/Repos/Axenide/web/content/Ambxst/changelog/` as Zola markdown files. Only write a changelog when explicitly asked.
