<p align="center">
  <img src="./assets/nothingless/nothingless-logo-color.svg" alt="NothingLess" width="400"/>
  <br><br>
  A minimal & performant fork of <a href="https://github.com/Axenide/Ambxst">Ambxst</a>.
  <br><br>
  <i>Inspired by Nothing — less is more.</i>
</p>

<p align="center">
  <a href="https://github.com/Leriart/NothingLess">
    <img src="https://img.shields.io/badge/NothingLess-0A0A0A?style=for-the-badge&logo=github&logoColor=FFFFFF" alt="repo">
  </a>
  <a href="https://github.com/Axenide/Ambxst">
    <img src="https://img.shields.io/badge/Fork%20of-Ambxst-E80012?style=for-the-badge&logo=github&logoColor=FFFFFF&labelColor=0A0A0A" alt="fork">
  </a>
</p>

---

## Concept

NothingLess strips the bloat and doubles down on speed, responsiveness, and clean design.

- No unnecessary animations
- No heavy dependencies
- No visual clutter
- Lightweight components
- Minimal resource usage
- Monochrome-first design language
- Dot-matrix aesthetic (Ndot font)

---

## Installation

```bash
curl -sL https://github.com/Leriart/NothingLess/raw/main/install.sh | sh
```

Or clone manually:

```bash
git clone https://github.com/Leriart/NothingLess.git ~/.local/src/nothingless
sudo ln -s ~/.local/src/nothingless/cli.sh /usr/local/bin/nothingless
```

Then run:

```bash
nothingless
```

Supported on **Arch**, **Fedora**, and **NixOS** (requires Hyprland).

---

## Commands

### NothingLess CLI

```bash
nothingless                          # Start NothingLess shell
nothingless reload                   # Reload NothingLess
nothingless quit                     # Quit NothingLess
nothingless run <command>            # Run a NothingLess module
```

| `nothingless run ...` | Description |
|---|---|
| `launcher` | Open app launcher |
| `dashboard` | Open dashboard |
| `assistant` | Open AI assistant |
| `clipboard` | Open clipboard manager |
| `emoji` | Open emoji picker |
| `notes` | Open notes |
| `tmux` | Open tmux terminal |
| `wallpapers` | Open wallpaper picker |
| `overview` | Open workspace overview |
| `powermenu` | Open power menu |
| `tools` | Open tools menu |
| `config` | Open settings |
| `screenshot` | Take screenshot |
| `screenrecord` | Screen record |
| `lens` | Open lens (OCR capture) |
| `toggle-metrics` | Toggle notch metrics overlay |
| `lockscreen` | Lock session |

### Keybinds

| Key | Action |
|---|---|
| `SUPER` (hold) | Launcher |
| `SUPER + D` | Dashboard |
| `SUPER + A` | Assistant |
| `SUPER + V` | Clipboard |
| `SUPER + PERIOD` | Emoji picker |
| `SUPER + N` | Notes |
| `SUPER + T` | Tmux |
| `SUPER + COMMA` | Wallpapers |
| `SUPER + TAB` | Workspace overview |
| `SUPER + ESC` | Power menu |
| `SUPER + S` | Tools menu |
| `SUPER + SHIFT + C` | Settings |
| `SUPER + SHIFT + S` | Screenshot |
| `SUPER + SHIFT + R` | Screen record |
| `SUPER + SHIFT + A` | Lens |
| `SUPER + SHIFT + L` | Lock session |
| `SUPER + SHIFT + BACKSPACE` | Toggle notch metrics overlay |

### FPS Monitoring (`nothing-fps`)

NothingLess includes a modified MangoHud that captures FPS data and displays it in the notch metrics overlay.

#### Usage

```bash
# Launch a game with FPS monitoring
nothing-fps ./my-game

# Steam launch options (right-click game → Properties → Launch Options)
nothing-fps %command%
```

The FPS overlay appears as a small counter in the top-right corner (via MangoHud), and the FPS value is also shown in the NothingLess notch when metrics mode is active (`SUPER + SHIFT + BACKSPACE`).

#### How it works

1. `nothing-fps` sets up a modified MangoHud (`libMangoHud_shim.so`) via `LD_PRELOAD`
2. MangoHud hooks Vulkan/OpenGL to capture frame-present events
3. Calculated FPS is written to `/dev/shm/nothingless_fps`
4. NothingLess reads this file in real-time and displays FPS in the notch

#### Rebuilding MangoHud from source

```bash
./scripts/mangohud-patch/build-mangohud.sh
```

Requires: `meson`, `ninja`, `gcc`, `glslang`, `python-mako`.

---

## Differences from Ambxst

| Area | Ambxst | NothingLess |
|------|--------|-------------|
| Animations | Heavy, ornate | Minimal, functional |
| Color scheme | Vibrant themes | Monochrome / subtle red |
| Typography | Roboto, varied | Ndot (dot-matrix) |
| Performance | Feature-rich | Lightweight & fast |
| Default preset | Axenide's config | Leriart's config |
| Commands | `ambxst` | `nothingless` |
| Branding | Color glyphs | Red + white dot-matrix |

---

## Author

- **Leriart** — fork maintainer
- **Axenide** — original Ambxst creator

---

## License

- NothingLess modifications are provided under the same license as the upstream.
- Ambxst and the Ambxst logo are trademarks of Adriano Tisera (Axenide).
- See [LICENSE](./LICENSE) and [TRADEMARK.md](./assets/nothingless/TRADEMARK.md) for details.
