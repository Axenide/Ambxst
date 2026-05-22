# Upstream Improvements from Ambxst — Analysis for NothingLess

> **Generated:** 2026-05-22
> **Source repo:** https://github.com/Axenide/Ambxst
> **Target repo:** NothingLess (fork)

This document catalogs all relevant pull requests and issues from the Ambxst repository, summarizing each change and recommending whether it should be applied to NothingLess, organized by priority.

---

## HIGH PRIORITY — Bugs & Missing Core Features

### 1. PR #177 — Thinking/Reasoning Models Support (OpenAI-compatible)

**Author:** ImIvanGil
**Status:** Open
**URL:** https://github.com/Axenide/Ambxst/pull/177

**What it does:**
Adds support for OpenAI-compatible "thinking" models (Kimi K2.5/K2.6, GPT o1 family, etc.) that emit a different stream shape and reject the default temperature of 0.7. Without this patch, every request to these models fails silently with "No response received from the API."

**Changes:**
- `OpenAiApiStrategy.getBody()` — dynamically sets `temperature: 1` for thinking models by regex: `/k2\.(5|6)|thinking|^o1(-|$)/`
- `parseStreamChunk()` and `parseResponse()` — handles `delta.reasoning_content` in addition to `delta.content`, so chain-of-thought is surfaced to the user

**Apply: YES — HIGH**
- Essential for supporting modern LLM thinking models
- Purely additive — non-thinking models unchanged
- NothingLess already has AI functionality; this closes a major gap

---

### 2. PR #176 — Wire `Config.ai.extraModels` for Custom OpenAI-compatible Providers

**Author:** ImIvanGil
**Status:** Open
**URL:** https://github.com/Axenide/Ambxst/pull/176

**What it does:**
Wires the existing `Config.ai.extraModels` schema field into Ai.qml so users can register custom OpenAI-compatible providers (OpenRouter, Moonshot/Kimi, LMStudio, llama.cpp servers, etc.) via `ai.json`.

**Changes:**
- `Ai.qml:fetchAvailableModels()` — iterates `Config.ai.extraModels` and registers each entry as a regular AiModel
- Leverages the existing "custom" provider → `OpenAiApiStrategy` route
- Schema: `{ name, model, endpoint, provider: "custom", description, requires_key, key_provider }`

**Apply: YES — HIGH**
- Without this, users can only use hardcoded providers
- Enables self-hosted and third-party AI backends
- No UI changes needed — config via `ai.json`

---

### 3. PR #178 — Surface Real HTTP Error Responses Instead of "No Response Received"

**Author:** ImIvanGil
**Status:** Open
**URL:** https://github.com/Axenide/Ambxst/pull/178

**What it does:**
When an OpenAI-compatible API returns a JSON error body (401/404/400/429), the old code showed the generic "No response received from the API." This PR captures the raw stdout from the curl process and parses `{"error":{"message":"..."}}` to surface the real error.

**Changes:**
- `OpenAiApiStrategy.qml` — adds `rawStdoutBuffer` property on the curl Process
- Adds `extractApiError()` function to parse JSON error bodies
- In `onExited`, falls through to real error message before showing the generic placeholder
- Resets buffer after each request

**Apply: YES — HIGH**
- Dramatically improves debugging AI integration issues
- No behavior change for the happy path
- Critical for PR #177 and #176 to be usable

---

### 4. PR #175 — Resolve Window Icons via StartupWMClass

**Author:** ImIvanGil
**Status:** Open
**URL:** https://github.com/Axenide/Ambxst/pull/175

**What it does:**
Fixes icon resolution for apps that use `StartupWMClass` in their `.desktop` files (Brave, Spotify, Steam, Slack, Discord flatpak variants, most Electron apps). Previously these showed the generic `image-missing` icon.

**Changes:**
- `getIconFromDesktopEntry()` — prepends a `app.startupClass === normalizedClassName` check
- Leverages Quickshell's `DesktopEntry.startupClass` property

**Apply: YES — HIGH**
- Fixes missing icons for popular apps
- Purely additive, trivial change
- Affects workspace indicator and dock

---

### 5. PR #174 — Terminal Launcher via `xdg-terminal-exec`

**Author:** ImIvanGil
**Status:** Open
**URL:** https://github.com/Axenide/Ambxst/pull/174

**What it does:**
Fixes launching `Terminal=true` apps (btop, htop, nvim, ranger, lazygit) from the app drawer. Previously these silently failed because they ran without a TTY.

**Changes:**
- `LauncherView.executeApp()` — delegates to `AppSearch.launchApp()` (was using `DesktopEntry.execute()` directly)
- `AppSearch.launchApp()` — prepends `xdg-terminal-exec` when `runInTerminal` is true
- Unifies app-launch behavior between dock and drawer

**Apply: YES — HIGH**
- Terminal apps completely broken in the drawer without this
- Uses the freedesktop standard mechanism
- Users need `xdg-terminal-exec` installed (AUR available)

---

### 6. PR #149 — Low Battery Notification with Sound

**Author:** BharathBala21
**Status:** Open
**URL:** https://github.com/Axenide/Ambxst/pull/149

**What it does:**
Adds configurable low-battery notifications with warning sound. Monitors battery percentage and triggers `notify-send` at low (default 20%) and critical (default 10%) thresholds, with configurable thresholds and a `.wav` sound effect.

**Changes:**
- New file: `BatteryNotification.qml` (~159 lines) — Singleton with battery monitoring logic
- `notificationProcess` using `notify-send` with urgency levels
- `SoundEffect` for warning tone
- Polls every 60s, plus triggers on `percentageChanged`, `isPluggedInChanged`, `isChargingChanged`
- 5s startup delay + 3s wake-from-suspend delay
- Config driven: `Config.system.batteryNotifications.{enabled, lowThreshold, criticalThreshold}`

**Apply: YES — HIGH**
- Essential feature for laptop users
- Configurable thresholds make it non-intrusive
- Sound file needed: `assets/sound/polite-warning-tone.wav`

---

### 7. PR #147 — Compositor Theming & Keybindings Not Applied at Runtime

**Author:** BluePhi09
**Status:** Open
**URL:** https://github.com/Axenide/Ambxst/pull/147

**What it does:**
Fixes two bugs where compositor theming and keybindings were silently not applied:
1. `CompositorKeybinds` was removed from `shell.qml` during a merge — never instantiated, so keybindings never worked
2. `CompositorConfig.applyCompositorConfigInternal()` was calling `CompositorTomlWriter.refresh()` instead of actually executing the built `batchCommand`

**Changes:**
- `shell.qml` — re-adds `CompositorKeybinds` instantiation
- `CompositorConfig.qml` — fixes method to execute the built batchCommand (uses `axctl config apply`)
- Second commit: switches back to `raw-batch` (axctl expects JSON for `config apply`, keyword commands need `raw-batch`)

**Apply: YES — HIGH**
- Compositor keybindings and theming literally don't work without this
- NothingLess likely has the same bug depending on merge state

---

## MEDIUM PRIORITY — Feature Improvements & Polish

### 8. PR #163 — Per-Monitor Shell Positions

**Author:** ROOCKY-dev
**Status:** Open
**URL:** https://github.com/Axenide/Ambxst/pull/163

**What it does:**
Adds per-monitor shell positioning for bar, notch, and dock, with global position as fallback. Screens without an override inherit the global setting.

**Changes (23 files):**
- `config/ScreenPositions.js` — shared per-screen position resolution helper
- `config/Config.qml` — wires new config fields and exposes per-screen helpers
- `config/ConfigValidator.js` — preserves arbitrary monitor keys inside `screenPositions`
- `config/defaults/{bar,dock,notch}.js` — add default `screenPositions`
- Updated in: `modules/bar/BarContent.qml`, `modules/notch/NotchContent.qml`, `modules/dock/DockContent.qml`, `modules/frame/ScreenFrame.qml`, `modules/desktop/Desktop.qml`, `modules/widgets/overview/*.qml`, `modules/widgets/defaultview/*.qml`, `modules/widgets/dashboard/controls/ShellPanel.qml`, `modules/globals/GlobalStates.qml`, `modules/shell/UnifiedShellPanel.qml`
- Tests: `tests/config-screen-positions.test.mjs`

**Apply: YES — MEDIUM**
- Valuable for multi-monitor setups
- Significant surface area (23 files) — careful merge needed
- Adds `screenPositions` config field to bar/notch/dock defaults

---

### 9. PR #159 — Animation Fixes, SafeLoader Component, Vulkan Backend Detection

**Author:** git-napkin
**Status:** Open
**URL:** https://github.com/Axenide/Ambxst/pull/159

**What it does:**
Multi-improvement PR with several independent changes:

1. **Avatar sourceSize** — explicit `sourceSize` on avatar images in notch, lock screen, resource monitor
2. **OSD polish** — fixes hover bug (instantly hiding on enter), adds slide+fade animation, wider pill (240×56), `%` suffix, 3s timer, font sizes via `Styling.fontSize()`
3. **Notch animation** — subtle Y-translate drop-in, tightened scale floor 0.8→0.85
4. **Lock screen** — animated date label below clock
5. **ToolTips** — fixes "desciription" typo, 1000→700ms delay, 70% opacity description text
6. **SysTrayItem** — fixes "desciription"→"description"
7. **SafeLoader component** — Loader wrapper with error handling, fallback UI, `retry()` method
8. **ErrorHandler singleton** — centralized error tracking
9. **QML unit test suite** — ConfigValidator, theme defaults, error patterns
10. **OSD visibility fix** — window stays alive until opacity animation finishes (was killing fade-out/slide-down mid-animation)
11. **Vulkan detection** — fixes `vulkaninfo` check to use `vulkaninfo --summary` instead of `command -v vulkaninfo || command -v glxinfo` (was enabling Vulkan on GLX-only systems)
12. **Package deps** — removes `vulkan-headers` (dev package) from Arch deps, keeps only `vulkan-icd-loader`
13. **BarContent** — removes redundant `!== undefined` checks
14. **PanelTitlebar** — uses `customContent` array instead of `children` at init
15. **AGENTS.md** — testing docs and error handling anti-pattern
16. **SafeLoader fixes** — `setFallback()` actually parents fallback into `fallbackContainer`, removes public `loader` property alias, makes `internalLoader` fully internal

**Apply: YES — MEDIUM**
- Independent improvements, can cherry-pick commits
- **Top picks:** OSD animation fix (#10), SafeLoader (#7), Vulkan detection fix (#11), typo fixes (#5, #6)
- The 23-commit scope needs careful review before full merge

---

### 10. PR #184 — Kirigami "Not Found" Fix for NixOS with Quickshell 3.0

**Author:** kagurazakei
**Status:** Open
**URL:** https://github.com/Axenide/Ambxst/pull/184

**What it does:**
Fixes a "kirigami not found" error on NixOS with Quickshell version 3.0 by overriding the quickshell package to include kirigami and related KDE packages as build inputs.

**Changes:**
- `packages/default.nix` — wraps `pkgs.quickshell` with `overrideAttrs` to add `buildInputs`: `qtdeclarative`, `qtbase`, `qtmultimedia`, `qtsvg`, `kirigami`, `kirigami-addons`, `qqc2-desktop-style`, `syntax-highlighting`
- `.gitignore` — adds `result/`
- Minor formatting cleanup in the nix expression

**Apply: YES — MEDIUM**
- Only relevant if NothingLess uses Nix/NixOS
- Temporary fix — proper fix would be in the quickshell package itself
- If NothingLess doesn't use Nix packaging: **SKIP**

---

## LOW PRIORITY — Feature Requests & Minor Issues

### 11. Issue #182 — Keyboard Layout Configuration

**URL:** https://github.com/Axenide/Ambxst/issues/182
**Reporter:** salvador-chile

**Request:** How to configure keyboard layout (specifically LATAM layout).

**Status:** Open, no responses.

**Recommendation:** LOW — Document how to configure keyboard layout via Hyprland config or add a settings UI entry. NothingLess should at minimum document keyboard layout configuration if not already covered.

---

### 12. Issue #173 — Hyprland Lua Support

**URL:** https://github.com/Axenide/Ambxst/issues/173
**Reporter:** (unnamed)

**Request:** Add `--lua` option for `ambxst install hyprland` because Hyprland now supports Lua configuration. The new `hyprland.lua` overwrites `hyprland.conf` and the `~/.local/share/ambxst/hyprland.conf` file doesn't load.

**Status:** Open, no responses.

**Recommendation:** LOW — Monitor Hyprland Lua adoption. If NothingLess targets Hyprland users, this could become MEDIUM priority as more users migrate to Lua configs.

---

### 13. Issue #172 — NixOS Declarative Settings via Nix Module

**URL:** https://github.com/Axenide/Ambxst/issues/172
**Reporter:** (unnamed)

**Request:** Make the NixOS module allow configuring everything the settings menu can do, mapping Nix language to JSON files in `~/.config/ambxst`.

**Status:** Open, no responses.

**Recommendation:** LOW — If NothingLess doesn't use Nix packaging, SKIP. If it does, nice-to-have. The NixOS module is a natural path for declarative config but significant work.

---

### 14. Issue #171 — Install Command Not Working (Cloudflare Block)

**URL:** https://github.com/Axenide/Ambxst/issues/171
**Reporter:** (unnamed)

**Problem:** `curl -L get.axeni.de/axctl | sh` hits a Cloudflare challenge page, returning HTML instead of the install script. Shell interprets the HTML as shell commands and fails with syntax errors.

**Status:** Open, no responses.

**Recommendation:** LOW — NothingLess has its own install.sh. Check if it has similar CDN/cURL issues. The takeaway: redirect install traffic through a direct URL or use a CDN that doesn't require JavaScript.

---

### 15. Issue #170 — Calendar First Day of Week Sunday Support

**URL:** https://github.com/Axenide/Ambxst/issues/170
**Reporter:** roeybenarieh

**Request:** Allow configuring the first day of the week as Sunday (instead of default Monday) in the calendar widget.

**Status:** Open, no responses.

**Recommendation:** LOW — Nice QoL improvement for locales where the week starts on Sunday. Add a `calendar.weekStartsOn` config option to the calendar widget.

---

### 16. Issue #169 — Support for Custom Layout Plugins (hy3)

**URL:** https://github.com/Axenide/Ambxst/issues/169
**Reporter:** (unnamed)

**Request:** Allow selecting custom Hyprland layout plugins (e.g., hy3) instead of having ambxst force `dwindle` on startup and every settings change.

**Status:** Open, no responses.

**Recommendation:** MEDIUM — If NothingLess manages Hyprland layout config, it should preserve custom layouts or provide a way to disable layout management. Laptop-mode layouts (mosaic) shouldn't override user preferences.

---

## Summary Table

| # | PR/Issue | Description | Priority | Effort |
|---|----------|-------------|----------|--------|
| 1 | #177 | Thinking/reasoning models | **HIGH** | Small (1 file) |
| 2 | #176 | Extra OpenAI-compatible providers | **HIGH** | Small (1 file) |
| 3 | #178 | Real API error messages | **HIGH** | Small (1 file) |
| 4 | #175 | Window icons via StartupWMClass | **HIGH** | Small (1 function) |
| 5 | #174 | Terminal app launcher | **HIGH** | Small (2 files) |
| 6 | #149 | Low battery notification | **HIGH** | Medium (1 new file + config) |
| 7 | #147 | Compositor theming/keybindings fix | **HIGH** | Small (2 files) |
| 8 | #163 | Per-monitor shell positions | **MEDIUM** | Large (23 files) |
| 9 | #159 | Animation fixes, SafeLoader, Vulkan | **MEDIUM** | Large (many commits, cherry-pick) |
| 10 | #184 | Kirigami nix fix | **MEDIUM** | Small (nix package only) |
| 11 | #169 | Custom layout plugins (hy3) | **MEDIUM** | Small (config management) |
| 12 | #182 | Keyboard layout docs | LOW | Trivial |
| 13 | #173 | Hyprland Lua support | LOW | Medium |
| 14 | #172 | NixOS declarative settings | LOW | Large |
| 15 | #171 | Cloudflare install issue | LOW | Small |
| 16 | #170 | Calendar Sunday start | LOW | Small |

---

## Recommended Merge Order

### Phase 1 — Bug Fixes (apply ASAP)
1. **PR #147** — Compositor keybindings/theming not working (blocking bug)
2. **PR #175** — Missing window icons (visible UX bug)
3. **PR #174** — Terminal apps broken in drawer (functional bug)
4. **PR #178** — API error messages (dev UX, unblocks AI features)

### Phase 2 — AI Features (after Phase 1)
5. **PR #176** — Extra AI providers (needs working error handling from #178)
6. **PR #177** — Thinking models (depends on #176)

### Phase 3 — Feature Enhancements
7. **PR #149** — Low battery notification
8. **PR #159** — Cherry-pick: OSD animation fix, SafeLoader, Vulkan detection
9. **PR #163** — Per-monitor shell positions
10. **PR #184** — Kirigami nix fix (if using Nix)

### Phase 4 — Polish
11. **Issue #170** — Calendar Sunday start
12. **Issue #169** — Custom layout plugin support
13. **Issue #182** — Keyboard layout docs
14. **Issue #173** — Lua support (monitor)
15. **Issue #172** — NixOS declarative (nice-to-have)
