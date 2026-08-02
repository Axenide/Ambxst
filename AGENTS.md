# AGENTS.md

Ambxst[+] is a Quickshell desktop shell: QML + JS for the UI, Python/Bash backends in
`scripts/` for system tasks. Packaged via Nix (flake). The display name is "Ambxst[+]",
but the binary/command is lowercase `ambxst+` — use that in shell commands.

## Running / verifying a change
- `ambxst+` is the launcher — a Bash wrapper (`cli.sh`) around `qs -p shell.qml`.
- From source: `nix develop` (sets `QML2_IMPORT_PATH`/`QML_IMPORT_PATH`), then `ambxst+`.
  Running `qs -p shell.qml` bare needs those QML import paths, so prefer the dev shell.
- Quickshell hot-reloads on QML/JS file save — edit and save to see changes live.
- The only in-repo verification is `python3 tests/test_scripts.py` (unittest for
  `scripts/`). The keystore tests need the `cryptography` module installed, or that
  class errors out; there is no lint/build step.
- CLI subcommands live in `cli.sh`. Notable: `lock`, `run <cmd>` (IPC to the running
  shell; `run lockscreen` is what `lock` does), `mic-mute`, `brightness`, `reload`,
  `quit`, `refresh` (Nix dev profile upgrade), `screen on|off`, `suspend`, `version`.
- IPC-based commands talk to the **running** shell: fast path writes to
  `/tmp/ambxst+_ipc.pipe`, fallback is `qs ipc --pid` with the PID found via
  `pgrep -f shell.qml` (the launcher also caches its PID in
  `${XDG_RUNTIME_DIR:-/tmp}/ambxst+.pid` at startup). The shell must already be up —
  these commands don't launch it. On launch, `cli.sh` forces
  `QT_QPA_PLATFORMTHEME=qt6ct`; don't override that.
- `ambxst+ install hyprland` / `ambxst+ remove hyprland` (`install`/`remove` take a
  *target* argument) **mutate the user's Hyprland config** by appending/removing an
  Ambxst[+] import block in `~/.config/hypr/hyprland.lua` (or `.conf`). `remove`
  refuses symlinked configs (dotfile-managed setups). Don't run these from an agent
  session expecting a clean environment. `goodbye` uninstalls Ambxst[+] entirely.
- `install.sh` is the standalone distro installer (Arch/Fedora/Debian/NixOS detection,
  clones the repo to `~/.local/src/ambxst+`, symlinks `/usr/local/bin/ambxst+`);
  the Nix flake is the alternative user install path. Neither is needed from source.
- Packaging: the Nix flake exposes `nix build`, `nix run` (app = `ambxst+`), and a
  `nixosModule`. From source, `nix develop` then `ambxst+`.
- `quickshell-docs/` is cloned reference docs (gitignored); useful for Quickshell APIs.

## Layout (read before editing)
- `shell.qml` — entry point; declares the Shell (`pragma ShellId ambxst+`), registers
  singletons and the init sequence.
- `config/` — reactive file-backed config system (see below).
- `modules/` — UI (`bar`, `notch`, `dock`, `notifications`, `widgets`, `theme`,
  `services`, `corners`, `desktop`, `frame`, `globals`, `lockscreen`, `sidebar`,
  `shell`, `tools`, `components`). Most have their own `AGENTS.md` — **read the
  module's `AGENTS.md` first** when working in that subtree instead of guessing
  conventions.
- `assets/` — presets (under `presets/`, one dir per preset), color schemes, fonts,
  icons, matugen config.
- `scripts/` — Python (output JSON) and Bash (output line-delimited text) backends
  invoked via `Quickshell.Io.Process`. They assume CLI tools are installed
  (`wl-paste`, `wl-copy`, `grim`, `slurp`, `brightnessctl`, `tesseract`, `hyprpicker`…).
- `nix/` — Nix packaging: `packages/` (package definitions), `modules/` (NixOS module),
  `lib.nix` (shared helpers).
- `tests/` — the only tests; runnable via `python3 tests/test_scripts.py`.

## Config system (the biggest gotcha)
- `Config.qml` is the singleton source of truth; JSON persisted to
  `~/.config/ambxst+/config/*.json` (note the lowercase path).
- **Adding a config key requires editing BOTH places**: `config/defaults/<domain>.js`
  (the blueprint/validation baseline) AND `Config.qml`. `ConfigValidator.js` deep-merges
  user JSON onto the blueprint and *preserves* unknown keys (forward-compatible), but a
  new key still needs a `defaults/*.js` entry or it has no blueprint default.
- Bind UI to `Config.<module>.<prop>`; never store persistent settings in local state.
- Config writes auto-save via `FileView`; use `root.pauseAutoSave` for bulk updates.
- Gate code that needs fully-loaded config with `Config.initialLoadComplete`
  (avoid null derefs during load/reload).

## Theme system
- Colors come from `Colors.qml` (watches `~/.cache/ambxst+/colors.json`),
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
- This checkout is a fork: `origin` is upstream `Axenide/Ambxst`, `git-napkin` is the
  fork's remote; work happens on the `dev` branch.
- Submodule-specific guidance (services, scripts, theme, config, notch, …) is already
  captured in each directory's `AGENTS.md`; prefer those over duplicating here.
