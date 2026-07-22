# AGENTS.md

Ambxst is a Quickshell desktop shell: QML + JS for the UI, Python/Bash backends in
`scripts/` for system tasks. Packaged via Nix (flake). There is **no test, lint, or
build step in-repo** — verification is running the live shell.

## Running / verifying a change
- `ambxst` is the launcher — a Bash wrapper (`cli.sh`) around `qs -p shell.qml`.
- From source: `nix develop` (sets `QML2_IMPORT_PATH`/`QML_IMPORT_PATH`), then `ambxst`.
  Running `qs -p shell.qml` bare needs those QML import paths, so prefer the dev shell.
- Quickshell hot-reloads on QML/JS file save — edit and save to see changes live.
- CLI subcommands live in `cli.sh`. Notable ones: `lock`, `brightness`, `refresh`
  (Nix dev profile upgrade), `update`, `goodbye`. `lock`/`brightness` talk to the
  **running** shell over IPC (`/tmp/ambxst_ipc.pipe`, falling back to `qs ipc`), so the
  shell must already be up — they don't launch it. `cli.sh` auto-detects Vulkan vs OpenGL
  and sets `QT_QUICK_BACKEND`; don't override it unless debugging.
- `ambxst install hyprland` / `ambxst remove hyprland` (`install`/`remove` take a
  *target* argument) **mutate the user's Hyprland config** by appending/removing an
  Ambxst import block in `~/.config/hypr/hyprland.lua` (or `.conf`). Don't run these from
  an agent session expecting a clean environment.
- Packaging: the Nix flake exposes `nix build`, `nix run` (app = `ambxst`), and a
  `nixosModule`. From source, `nix develop` then `ambxst`.
- `quickshell-docs/` is cloned reference docs (gitignored); useful for Quickshell APIs.

## Layout (read before editing)
- `shell.qml` — entry point; registers singletons and the init sequence.
- `config/` — reactive file-backed config system (see below).
- `modules/` — UI (`bar`, `notch`, `dock`, `notifications`, `widgets`, `theme`, `services`,
  `corners`, `desktop`, `frame`, `globals`, `lockscreen`, `shell`, `components`).
  Most have their own `AGENTS.md` — **read the module's `AGENTS.md` first** when
  working in that subtree instead of guessing conventions.
- `assets/` — presets, color schemes, fonts, icons, matugen config.
- `scripts/` — Python (output JSON) and Bash (output line-delimited text) backends
  invoked via `Quickshell.Io.Process`. They assume CLI tools are installed
  (`wl-paste`, `wl-copy`, `grim`, `slurp`, `brightnessctl`, `tesseract`, `hyprpicker`…).
- `nix/` — Nix packaging: `packages/` (package definitions), `modules/` (NixOS module),
  `lib.nix` (shared helpers).

## Config system (the biggest gotcha)
- `Config.qml` is the singleton source of truth; JSON persisted to
  `~/.config/ambxst/config/*.json`.
- **Adding a config key requires editing BOTH places**: `config/defaults/<domain>.js`
  (the blueprint/validation baseline) AND `Config.qml`. `ConfigValidator.js` deep-merges
  user JSON onto the blueprint and now *preserves* unknown keys (forward-compatible), but a
  new key still needs a `defaults/*.js` entry or it has no blueprint default.
- Bind UI to `Config.<module>.<prop>`; never store persistent settings in local state.
- Config writes auto-save via `FileView`; use `root.pauseAutoSave` for bulk updates.
- Gate code that needs fully-loaded config with `Config.initialLoadComplete`
  (avoid null derefs during load/reload).

## Theme system
- Colors come from `Colors.qml` (watches `~/.cache/ambxst/colors.json`),
  `Styling.qml` (`radius(offset)`, `fontSize(offset)`), `Icons.qml` (Phosphor-Bold map).
- **Never hardcode hex colors** — use `Colors.<prop>`. Use `Styling.radius()`/`fontSize()`
  instead of literal sizes. Icons go through `Icons.qml`, not raw glyphs.
- Prefer `Styling` helpers for new surfaces: `popupRadius()` (floating surfaces),
  `tint(color, alpha)` (apply alpha without unpacking channels), `Styling.hoverAlpha`/
  `pressAlpha` (interaction feedback), and `Styling.animEasing` (canonical motion easing).

## Conventions worth knowing
- Singletons use `pragma Singleton` + `Singleton { id: root }`; services self-init via
  `Component.onCompleted: update()`.
- Modify QML list/models inside `Process.onStdout` handlers only via `Qt.callLater()`.
- Submodule-specific guidance (services, scripts, theme, config, notch, …) is already
  captured in each directory's `AGENTS.md`; prefer those over duplicating here.
