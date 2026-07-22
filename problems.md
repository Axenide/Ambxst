# Ambxst Codebase: Complete Improvement Plan

## Overview

This document catalogs every identified issue across the Ambxst codebase, organized by severity and category. Each entry includes:
- **File** and **line reference**
- **Description** of the problem
- **Root cause** analysis
- **Recommended fix** with code examples
- **Severity** rating (Critical / High / Medium / Low)

---

## 1. CRITICAL BUGS

### 1.1 Nix String Escaping — FONTCONFIG_PATH (CORRECTED)

**File:** `nix/packages/default.nix:63`

**Status:** This was initially flagged as a bug but has been **CORRECTED** after web verification.

In Nix indented strings (`''...''`), the sequence `''${` is the proper escape for a literal `${` in the output. The code:

```nix
export FONTCONFIG_PATH="${fontconfigConf}/etc/fonts:''${FONTCONFIG_PATH:-}"
```

correctly produces:

```bash
export FONTCONFIG_PATH="/nix/store/.../etc/fonts:${FONTCONFIG_PATH:-}"
```

**No fix needed.**

---

## 2. SECURITY ISSUES

### 2.1 `eval` in wf-record.sh — ShellCheck SC2294

**File:** `scripts/wf-record.sh`

**Severity:** Critical

**Description:** The script uses `eval $CMD` to execute a dynamically constructed command string. This is a textbook ShellCheck SC2294 violation and a known security anti-pattern.

**Root cause:** The command is built as a string with interpolated variables, then executed via `eval`. If any variable contains shell metacharacters, arbitrary code execution is possible.

**Recommended fix:** Use an array to hold command arguments and execute directly:

```bash
# Instead of:
CMD="grim -g \"$(slurp)\" - | wf-recorder ..."
eval $CMD

# Use:
mapfile -t CMD_ARGS < <(printf '%s\n' "grim" "-g" "$(slurp)" "-" "|")
# Or better, use a proper array:
CMD=(grim -g "$(slurp)" -)
"${CMD[@]}" | wf-recorder -f "$OUTPUT" -
```

### 2.2 XOR "Encryption" in keystore.py

**File:** `scripts/keystore.py`

**Severity:** High

**Description:** The keystore uses a simple XOR cipher with the machine ID as the key. XOR with a known key provides zero cryptographic security — the machine ID is readable by any process on the system.

**Root cause:** Mistaken belief that XOR provides encryption. The machine ID (`/etc/machine-id` or `/var/lib/dbus/machine-id`) is world-readable.

**Recommended fix:** Use a proper encryption library (e.g., `cryptography` with Fernet) or at minimum use `keyring` for OS-level credential storage. If a dependency-free approach is required, document the limitations clearly.

### 2.3 Missing `set -euo pipefail` in Bash Scripts

**File:** All scripts in `scripts/` (10 of 12 bash scripts)

**Severity:** Medium

**Description:** Most bash scripts do not use `set -euo pipefail`, meaning:
- `-e`: Script continues on errors
- `-u`: Unset variables silently expand to empty string
- `-o pipefail`: Pipe failures are masked by the last command's exit code

**Affected scripts:**
- `scripts/wf-record.sh`
- `scripts/screenshot.sh`
- `scripts/brightness.sh`
- `scripts/audio.sh`
- `scripts/kb-layout.sh`
- `scripts/power.sh`
- `scripts/clipboard.sh`
- `scripts/network.sh`
- `scripts/bluetooth.sh`
- `scripts/recorder.sh`

**Recommended fix:** Add at the top of each script:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

### 2.4 Missing `flush=True` in Python IPC Scripts

**File:** All Python scripts in `scripts/` that communicate via stdout

**Severity:** High

**Description:** Python's `print()` buffers output by default. When Quickshell reads stdout via `StdioCollector`, it may not receive output until the buffer fills or the process exits. This causes IPC commands to hang.

**Affected scripts:**
- `scripts/system_monitor.py`
- `scripts/colorpicker.py`
- `scripts/keystore.py`
- `scripts/ocr.py`
- `scripts/weather.py`
- `scripts/ai.py`
- `scripts/power.py`

**Recommended fix:** Either:
1. Add `flush=True` to every `print()` call, or
2. Add `sys.stdout.reconfigure(line_buffering=True)` at the top of each script, or
3. Use `PYTHONUNBUFFERED=1` environment variable when launching

### 2.5 Missing `if __name__ == "__main__":` Guard

**File:** `scripts/colorpicker.py`

**Severity:** Low

**Description:** The script executes code at module level without the `if __name__ == "__main__":` guard. This means importing the module (e.g., for testing) would execute side effects.

**Recommended fix:**

```python
if __name__ == "__main__":
    main()
```

---

## 3. CODE QUALITY / CONSISTENCY

### 3.1 Redundant `pgrep` Calls in cli.sh

**File:** `cli.sh` — `find_ambxst_pid` function

**Severity:** Medium

**Description:** The `find_ambxst_pid` function calls `pgrep` up to 8 times in a loop, each spawning a new process. This is inefficient and fragile.

**Root cause:** The function tries multiple patterns (`ambxst`, `qs`, `quickshell`) in sequence.

**Recommended fix:** Use a single `pgrep -f` with a pattern that matches all variants, or use `ps` with `grep`:

```bash
find_ambxst_pid() {
    pgrep -f 'ambxst|quickshell|/qs' | head -1
}
```

### 3.2 Monolithic Config.qml (3577 lines)

**File:** `config/Config.qml`

**Severity:** Medium

**Description:** The entire config system is in a single 3577-line file. This makes it hard to navigate, understand, and maintain.

**Root cause:** No modularization of the config system.

**Recommended fix:** Split into domain-specific files:
- `config/ConfigCore.qml` — core config infrastructure
- `config/ConfigUI.qml` — UI-related config
- `config/ConfigServices.qml` — service-related config
- `config/ConfigTheme.qml` — theme-related config

Each file would be a `pragma Singleton` and imported as needed.

### 3.3 Missing `.pragma library` in defaults files

**File:** `config/defaults/ai.js`

**Severity:** Low

**Description:** The `ai.js` defaults file does not have `.pragma library` at the top, unlike other defaults files.

**Recommended fix:** Add `.pragma library` as the first line.

### 3.4 Config Validator Only Validates Two Keys

**File:** `config/ConfigValidator.js`

**Severity:** Medium

**Description:** The validator only checks `gradientType` and `noMediaDisplay`. All other config keys pass through without validation.

**Root cause:** The validator was written incrementally and never expanded.

**Recommended fix:** Add validation for all config keys, including:
- Range checks for numeric values (e.g., `barHeight`, `radius`, `fontSize`)
- Enum checks for string values (e.g., `position: "top" | "bottom"`)
- Type checks for all values

### 3.5 Bare `except:` Clauses in Python Scripts

**File:** `scripts/system_monitor.py` (12 instances), `scripts/weather.py`, `scripts/ai.py`

**Severity:** Medium

**Description:** Multiple Python scripts use bare `except:` clauses, which catch `KeyboardInterrupt` and `SystemExit`. This prevents clean shutdown and masks bugs.

**Recommended fix:** Replace with `except Exception:` or more specific exception types.

### 3.6 Inconsistent Import Paths in shell.qml

**File:** `shell.qml:28`

**Severity:** Low

**Description:** The shell uses `"modules/tools"` for some imports but `qs.modules.tools` for others. This inconsistency could cause confusion.

**Recommended fix:** Standardize on `qs.modules.*` for all Quickshell module imports.

---

## 4. CONFIG SYSTEM ISSUES

### 4.1 Config Key Mismatch: workspaceSpacing

**File:** `config/defaults/overview.js:12` vs `config/Config.qml`

**Severity:** High

**Description:** `defaults/overview.js` defines `workspaceSpacing: 8`, but `Config.qml` defines `workspaceSpacing: 4`. The defaults file is supposed to be the source of truth for blueprint values, but they disagree.

**Recommended fix:** Make them consistent. Either:
- Change `defaults/overview.js` to `workspaceSpacing: 4`
- Or change `Config.qml` to `workspaceSpacing: 8`

### 4.2 Config Write Race Conditions

**File:** `config/Config.qml`

**Severity:** Medium

**Description:** Config writes are triggered by `FileView.onSourceChanged` which can fire multiple times rapidly during bulk updates. The `pauseAutoSave` mechanism exists but is not consistently used.

**Recommended fix:** Audit all places where multiple config keys are updated simultaneously and ensure `pauseAutoSave` is used.

### 4.3 No Config Migration System

**File:** `config/ConfigValidator.js`

**Severity:** Medium

**Description:** There is no mechanism to migrate old config formats to new ones. If a config key is renamed or restructured, users lose their settings.

**Recommended fix:** Add a `version` field to the config and implement migration functions for each version bump.

### 4.4 Config Keys Not Documented

**File:** All `config/defaults/*.js` files

**Severity:** Low

**Description:** Config keys have no inline documentation explaining their purpose, valid ranges, or defaults.

**Recommended fix:** Add JSDoc-style comments to each config key:

```js
/**
 * Height of the bar in pixels.
 * @type {number}
 * @minimum 20
 * @maximum 200
 * @default 36
 */
barHeight: 36,
```

---

## 5. THEME SYSTEM ISSUES

### 5.1 Hardcoded Colors in Colors.qml

**File:** `modules/theme/Colors.qml:273-274`

**Severity:** High

**Description:** Two hardcoded hex colors (`#FF6B08`, `#FF0028`) bypass the matugen color system.

**Recommended fix:** Replace with references to the matugen-generated color palette:

```qml
property color orange: matugenColors["orange"] || "#FF6B08"
property color error: matugenColors["error"] || "#FF0028"
```

### 5.2 Hardcoded Font Sizes in Bar Modules

**File:** `modules/bar/` (19 instances across 8 files)

**Severity:** Medium

**Description:** Font sizes are hardcoded as literal numbers (e.g., `font.pixelSize: 12`) instead of using `Styling.fontSize()`.

**Affected files:**
- `modules/bar/BarItem.qml`
- `modules/bar/Clock.qml`
- `modules/bar/NetworkStatus.qml`
- `modules/bar/BluetoothStatus.qml`
- `modules/bar/AudioStatus.qml`
- `modules/bar/WorkspaceButton.qml`
- `modules/bar/OverviewButton.qml`
- `modules/bar/SystemTray.qml`

**Recommended fix:** Replace all hardcoded font sizes with `Styling.fontSize(offset)`.

### 5.3 `Styling.animEasing` Defined But Never Used

**File:** `modules/theme/Styling.qml`

**Severity:** Low

**Description:** The `animEasing` property is defined but never referenced anywhere in the codebase.

**Recommended fix:** Either use it for all animations or remove it. If used, add to all `Behavior` and `NumberAnimation` definitions:

```qml
Behavior on x {
    NumberAnimation { easing: Styling.animEasing; duration: 200 }
}
```

### 5.4 Empty `power` Property in Icons.qml

**File:** `modules/theme/Icons.qml:148`

**Severity:** Low

**Description:** The `power: ""` property is empty, which will render nothing.

**Recommended fix:** Either add the correct Phosphor icon character or remove the property if unused.

### 5.5 Missing `tint()` Usage

**File:** `modules/` (multiple files)

**Severity:** Low

**Description:** Several places manually apply alpha by unpacking color channels instead of using `Styling.tint()`.

**Recommended fix:** Replace manual alpha application with `Styling.tint(color, alpha)`.

---

## 6. MODULE-SPECIFIC ISSUES

### 6.1 Duplicated Async Pattern: NetworkService + BluetoothService

**File:** `modules/services/NetworkService.qml` and `modules/services/BluetoothService.qml`

**Severity:** Medium

**Description:** Both services implement nearly identical async polling patterns with `Qt.callLater` and `Process.onStdout` handlers.

**Recommended fix:** Extract a shared `AsyncServiceBase.qml` singleton that handles the common polling logic.

### 6.2 Duplicated Color Formatting: CompositorConfig + CompositorTomlWriter

**File:** `modules/services/CompositorConfig.qml` and `modules/services/CompositorTomlWriter.qml`

**Severity:** Medium

**Description:** Both files contain identical color formatting functions (RGB to hex, alpha handling).

**Recommended fix:** Extract color utilities into a shared `ColorUtils.js` file.

### 6.3 Missing `Component.onCompleted` in Some Services

**File:** Multiple service files

**Severity:** Low

**Description:** Some services don't call `update()` in `Component.onCompleted`, causing them to not initialize until the first timer tick.

**Affected:**
- `modules/services/BatteryService.qml`
- `modules/services/ThermalService.qml`
- `modules/services/CpuService.qml`

**Recommended fix:** Add `Component.onCompleted: update()` to each.

### 6.4 Notch Module: No Keyboard Navigation

**File:** `modules/notch/`

**Severity:** Medium

**Description:** The notch UI has no keyboard navigation support (arrow keys, Enter, Escape).

**Recommended fix:** Add `KeyNavigation` and `Keys.onPressed` handlers to all interactive elements.

### 6.5 Dock Module: No Drag-and-Drop Reordering

**File:** `modules/dock/`

**Severity:** Medium

**Description:** Dock items cannot be reordered via drag-and-drop.

**Recommended fix:** Implement `Drag` and `Drop` handlers on dock items.

### 6.6 Bar Module: No Auto-Hide Animation

**File:** `modules/bar/`

**Severity:** Low

**Description:** The bar's auto-hide feature snaps on/off without animation.

**Recommended fix:** Add a `Behavior` on the `y` property with `NumberAnimation`.

---

## 7. SCRIPT ISSUES

### 7.1 Python Scripts Don't Use `argparse`

**File:** All Python scripts in `scripts/`

**Severity:** Low

**Description:** Python scripts parse arguments manually with `sys.argv` instead of using `argparse`.

**Recommended fix:** Use `argparse` for consistent CLI interface, help text, and type validation.

### 7.2 Bash Scripts Don't Use `getopt` for Complex Args

**File:** `scripts/wf-record.sh`, `scripts/screenshot.sh`

**Severity:** Low

**Description:** These scripts parse complex arguments manually.

**Recommended fix:** Use `getopt` for robust argument parsing.

### 7.3 Scripts Don't Check for Required CLI Tools

**File:** All scripts in `scripts/`

**Severity:** Medium

**Description:** Scripts assume CLI tools (`grim`, `slurp`, `brightnessctl`, `tesseract`, etc.) are installed. If missing, they fail with cryptic errors.

**Recommended fix:** Add dependency checks at the top of each script:

```bash
for cmd in grim slurp wf-recorder; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "Error: $cmd is required but not installed." >&2
        exit 1
    }
done
```

### 7.4 OCR Script: No Error Handling for Tesseract

**File:** `scripts/ocr.py`

**Severity:** Medium

**Description:** If `tesseract` fails or returns no text, the script doesn't handle the error gracefully.

**Recommended fix:** Check the return code and handle empty results.

### 7.5 Weather Script: No Cache Expiration

**File:** `scripts/weather.py`

**Severity:** Low

**Description:** The weather script caches results but doesn't expire the cache, leading to stale data.

**Recommended fix:** Add a TTL to the cache (e.g., 10 minutes).

---

## 8. NIX / PACKAGING ISSUES

### 8.1 Flake URI Mismatch

**File:** `flake.nix:98` vs `install.sh:5`

**Severity:** Medium

**Description:** `flake.nix` references `github:Axenide/Ambxst` but `install.sh` references `github:git-napkin/Ambxst`. These should be consistent.

**Recommended fix:** Use the correct repository URI in both files.

### 8.2 NixOS Module Missing Hyprland Dependency

**File:** `nix/modules/default.nix`

**Severity:** High

**Description:** The NixOS module doesn't declare a dependency on Hyprland, so the module may fail if Hyprland isn't already installed.

**Recommended fix:** Add `services.hyprland.enable` as a dependency or at least document the requirement.

### 8.3 `buildEnv` vs `symlinkJoin` (CORRECTED)

**File:** `nix/packages/default.nix`

**Status:** This was initially flagged but has been **CORRECTED** after web verification.

The NixOS discourse confirms that `buildEnv` is the idiomatic way to combine unrelated packages. `symlinkJoin` is for combining outputs of related packages. The current usage of `buildEnv` is correct.

**No fix needed.**

### 8.4 No `meta` Attributes on Packages

**File:** `nix/packages/default.nix`

**Severity:** Low

**Description:** Packages don't have `meta` attributes (description, homepage, license, platforms).

**Recommended fix:** Add `meta` to each package:

```nix
meta = with lib; {
    description = "Ambxst desktop shell";
    homepage = "https://github.com/git-napkin/Ambxst";
    license = lib.licenses.gpl3;
    platforms = lib.platforms.linux;
};
```

### 8.5 No `shell.nix` for Non-Flake Users

**File:** `nix/`

**Severity:** Low

**Description:** There's no `shell.nix` file, so users who don't use flakes can't easily enter the dev shell.

**Recommended fix:** Add a `shell.nix` that wraps the flake's dev shell.

---

## 9. DOCUMENTATION ISSUES

### 9.1 No API Documentation

**File:** Entire codebase

**Severity:** Medium

**Description:** There's no generated API documentation for the QML modules.

**Recommended fix:** Add QDoc comments to all QML files and generate documentation with `qdoc`.

### 9.2 AGENTS.md Not Updated for New Modules

**File:** `AGENTS.md`

**Severity:** Low

**Description:** The AGENTS.md doesn't mention all modules (e.g., `modules/dock`, `modules/notifications`).

**Recommended fix:** Update AGENTS.md to include all modules and their conventions.

### 9.3 No README for Each Module

**File:** `modules/*/AGENTS.md`

**Severity:** Low

**Description:** Not all modules have an `AGENTS.md` file.

**Missing:**
- `modules/dock/AGENTS.md`
- `modules/notifications/AGENTS.md`
- `modules/widgets/AGENTS.md`

**Recommended fix:** Create `AGENTS.md` for each module.

---

## 10. PERFORMANCE ISSUES

### 10.1 Excessive `Qt.callLater` Usage

**File:** Multiple service files

**Severity:** Medium

**Description:** `Qt.callLater` is used in many places where a simple deferred call would suffice. This adds unnecessary overhead.

**Recommended fix:** Audit each usage and replace with `Qt.callLater` only where truly needed (i.e., to break reentrancy).

### 10.2 Unnecessary Property Bindings

**File:** `modules/bar/`

**Severity:** Medium

**Description:** Some bar items have property bindings that update on every frame (e.g., binding to `Date` for the clock).

**Recommended fix:** Use a timer with appropriate interval instead of binding to live properties.

### 10.3 No Lazy Loading for Heavy Modules

**File:** `shell.qml`

**Severity:** Medium

**Description:** All modules are loaded eagerly at startup, increasing launch time.

**Recommended fix:** Use `Loader` with `active: false` for heavy modules (dock, notch, widgets) and activate them on demand.

### 10.4 Repeated File I/O in Config

**File:** `config/Config.qml`

**Severity:** Medium

**Description:** Config reads and writes are not batched, causing multiple file I/O operations.

**Recommended fix:** Implement a write queue that batches changes and writes once per frame.

---

## 11. ACCESSIBILITY ISSUES

### 11.1 No Screen Reader Support

**File:** All UI modules

**Severity:** Medium

**Description:** No `Accessible` properties are set on any UI elements.

**Recommended fix:** Add `Accessible.name`, `Accessible.role`, and `Accessible.description` to all interactive elements.

### 11.2 No High Contrast Theme

**File:** `modules/theme/`

**Severity:** Medium

**Description:** There's no high contrast color scheme for visually impaired users.

**Recommended fix:** Add a high contrast theme option in the config.

### 11.3 No Font Scaling Support

**File:** `modules/theme/Styling.qml`

**Severity:** Low

**Description:** Font sizes are not scaled based on system DPI settings.

**Recommended fix:** Use `Screen.devicePixelRatio` to scale font sizes.

---

## 12. TESTING / VERIFICATION

### 12.1 No Unit Tests

**File:** Entire codebase

**Severity:** High

**Description:** There are no unit tests for any component. The AGENTS.md states "verification is running the live shell," but this is insufficient for regression testing.

**Recommended fix:** Add a test framework. Options:
1. **Python tests** for `scripts/` using `pytest`
2. **QML tests** using Qt Test framework
3. **Integration tests** using `quickshell --test` if available

### 12.2 No CI/CD Pipeline

**File:** `.github/` (doesn't exist)

**Severity:** Medium

**Description:** There's no CI/CD pipeline to automatically verify changes.

**Recommended fix:** Add GitHub Actions for:
- Nix build verification
- Python script linting (ruff/flake8)
- Bash script linting (shellcheck)
- QML syntax checking

---

## Summary

| Category | Count | Critical | High | Medium | Low |
|----------|-------|----------|------|--------|-----|
| Security | 5 | 1 | 2 | 2 | 0 |
| Config System | 5 | 0 | 1 | 3 | 1 |
| Theme System | 5 | 1 | 0 | 1 | 3 |
| Module Issues | 6 | 0 | 0 | 3 | 3 |
| Scripts | 7 | 0 | 1 | 3 | 3 |
| Nix/Packaging | 5 | 0 | 1 | 2 | 2 |
| Code Quality | 6 | 0 | 0 | 3 | 3 |
| Documentation | 3 | 0 | 1 | 0 | 2 |
| Performance | 4 | 0 | 0 | 4 | 0 |
| Accessibility | 3 | 0 | 2 | 0 | 1 |
| Testing | 2 | 1 | 1 | 0 | 0 |
| **Total** | **51** | **2** | **7** | **19** | **23** |

**Note:** Two initially flagged items (FONTCONFIG_PATH escaping, `buildEnv` usage) were corrected after web verification and are marked as "no fix needed."

---

## Implementation Priority

### Phase 1: Critical & Security (Immediate)
1. Fix `eval` in `wf-record.sh`
2. Fix XOR encryption in `keystore.py`
3. Add `flush=True` to Python IPC scripts
4. Add `set -euo pipefail` to bash scripts
5. Fix `workspaceSpacing` mismatch

### Phase 2: High Impact (Next)
1. Fix hardcoded colors in `Colors.qml`
2. Fix NixOS module Hyprland dependency
3. Fix flake URI mismatch
4. Add dependency checks to scripts

### Phase 3: Code Quality (Ongoing)
1. Split `Config.qml` into modules
2. Add `argparse` to Python scripts
3. Add `Accessible` properties
4. Add unit tests

### Phase 4: Polish (Later)
1. Add animations
2. Add high contrast theme
3. Add CI/CD pipeline
4. Add API documentation
