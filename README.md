<p align="center">
<img src="./assets/ambxst/ambxst-logo-color.svg" alt="Ambxst Logo" style="width: 50%;" align="center" />
  <br>
  <br>
An <i><b>Ax</b>tremely</i> customizable shell.
</p>

  <p align="center">
  <a href="https://github.com/Axenide/Ax-Shell/stargazers">
    <img src="https://img.shields.io/github/stars/Axenide/Ambxst?style=for-the-badge&logo=github&color=E3B341&logoColor=D9E0EE&labelColor=000000" alt="GitHub stars">
  </a>
  <a href="https://ko-fi.com/Axenide">
    <img src="https://img.shields.io/badge/Support me on-Ko--fi-FF6433?style=for-the-badge&logo=kofi&logoColor=white&labelColor=000000" alt="Ko-Fi">
  </a>
  <a href="https://discord.com/invite/gHG9WHyNvH">
    <img src="https://img.shields.io/discord/669048311034150914?style=for-the-badge&logo=discord&logoColor=D9E0EE&labelColor=000000&color=5865F2&label=Discord" alt="Discord">
  </a>
</p>

---

<h2><sub><img src="https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Objects/Camera%20with%20Flash.png" alt="Camera with Flash" width="32" height="32" /></sub> Screenshots</h2>

<div align="center">
  <img src="./assets/screenshots/1.png" width="100%" />

  <br />

  <img src="./assets/screenshots/2.png" width="32%" />
  <img src="./assets/screenshots/3.png" width="32%" />
  <img src="./assets/screenshots/4.png" width="32%" />

  <img src="./assets/screenshots/5.png" width="32%" />
  <img src="./assets/screenshots/6.png" width="32%" />
  <img src="./assets/screenshots/7.png" width="32%" />

  <img src="./assets/screenshots/8.png" width="32%" />
  <img src="./assets/screenshots/9.png" width="32%" />
  <img src="./assets/screenshots/10.png" width="32%" />
</div>

---

<h2><sub><img src="https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Objects/Package.png" alt="Package" width="32" height="32" /></sub> Installation</h2>

```bash
curl -L get.axeni.de/ambxst | sh
```

This will install Ambxst and its dependencies. You will have the `ambxst` command available in your terminal, which you can use to start the shell.

### Hyprland (more compositors coming soon!)

1. Run the installation command above.

2. Run `ambxst install hyprland` to add Ambxst's configuration to Hyprland. This will source a config file that applies Ambxst's settings. If you use `hyprland.lua`, or if no Hyprland config exists yet, it will look like this:

```lua
-- Ambxst
loadfile(os.getenv("HOME") .. "/.local/share/ambxst/hyprland.lua")()

-- OVERRIDES
-- Down here you can write or source anything that you want to override from Ambxst's settings.
```

If you only have `hyprland.conf`, Ambxst will keep using the legacy import there for compatibility:

```bash
# Ambxst
source = ~/.local/share/ambxst/hyprland.conf

# OVERRIDES
# Down here you can write or source anything that you want to override from Ambxst's settings.
```

As stated, anything you want to override from Ambxst's settings should be written under the "OVERRIDES" section.

3. Start Ambxst by running `ambxst` in your terminal. If you want to keep it running without having the terminal window open, you can run `ambxst & disown`. This will be only necessary for your first test run, as Ambxst will start automatically on login after step 2.

Ambxst is currently supported on **Arch**, **Fedora**, and **NixOS**. This means both based and derivative distributions.

> [!IMPORTANT]
> The only pre-requisite is having Hyprland installed.

> [!NOTE]
> For NixOS users, the screen recording utility `gpu-screen-recorder` will only be able to use the `portal` backend until you add `programs.gpu-screen-recorder.enable = true;` to your `configuration.nix` or **home-manager**.

---

## Will this change my config?

Nope! Besides the Ambxst import block in your `hyprland.conf` or `hyprland.lua`, Ambxst is designed to be non-intrusive. It won't modify any of your existing configurations.

---

<h2><sub><img src="https://raw.githubusercontent.com/Tarikul-Islam-Anik/Telegram-Animated-Emojis/main/Activity/Sparkles.webp" alt="Sparkles" width="32" height="32" /></sub> Features</h2>

- [x] Customizable components
- [x] Themes
- [x] System integration
- [x] App launcher
- [x] Clipboard manager
- [x] Quick notes (and not so quick ones)
- [x] Wallpaper manager
- [x] Emoji picker
- [x] [tmux](https://github.com/tmux/tmux) session manager
- [x] System monitor
- [x] Media control
- [x] Notification system
- [x] Wi-Fi manager
- [x] Bluetooth manager
- [x] Audio mixer
- [x] [EasyEffects](https://github.com/wwmm/easyeffects) integration
- [x] Screen capture
- [x] Screen recording
- [x] Color picker
- [x] OCR
- [x] QR and barcode scanner
- [x] "Mirror" (webcam)
- [x] Game mode
- [x] Night mode
- [x] Power profile manager
- [x] AI Assistant
- [x] Weather
- [x] Calendar
- [x] Power menu
- [x] Workspace management
- [x] Support for different layouts (dwindle, master, scrolling, etc.)
- [x] Multi-monitor support
- [x] Customizable keybindings
- [ ] Plugin and extension system
- [ ] Compatibility with other Wayland compositors

---

## I need help!

If you are having trouble or have any questions:
- You can ask anything on [Discord](https://discord.com/invite/gHG9WHyNvH) or in the [GitHub discussions](https://github.com/Axenide/Ambxst/discussions).
- You can open an issue on the [GitHub repository](https://github.com/Axenide/Ambxst/issues).
- The main configuration is located at `~/.config/ambxst`.

---

## Credits
- [outfoxxed](https://outfoxxed.me/) for creating Quickshell and great documentation!
- [end-4](https://github.com/end-4) for his awesome projects. I learned a lot from them! (And *yoinked* a lot of code, too. 😅)
- [soramane](https://github.com/soramanew) for helping me when I started with Quickshell. (You probably don't remember, but still, heh.)
- [tr1x_em](https://trix.is-a.dev/) for being a great friend and helping me find great tools. You rock!
- [Darsh](https://github.com/its-darsh) for not killing me when I left Fabric. u_u (Also for being a great friend and creating Fabric! Without Fabric, Ax-Shell wouldn't exist, so Ambxst wouldn't either. Thank you!)
- [Mario](https://github.com/mariokhz) for being a great friend and showing me Quickshell!
- [Samouly](https://samouly.is-a.dev/) for being Samouly. :3
- [Brys](https://github.com/brys0) for being his continuous support and for being a great friend!
- [Zen](https://github.com/wer-zen) for being a great friend and helping me when I started with Quickshell too!
- [kh](https://www.youtube.com/watch?v=dQw4w9WgXcQ) for being an awesome human being and listening to my delusions about Ambxst. :D
- And you, the user, for trying out Ambxst! You're awesome! 💖

(If I forgot someone, please let me know. 🙏)
