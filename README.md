<p align="center">
<img src="./assets/ambxst/ambxst-banner.png" alt="Ambxst Logo" style="width: 60%;" align="center" />
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
</div>

---

<h2><sub><img src="https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Objects/Package.png" alt="Package" width="32" height="32" /></sub> Installation</h2>

```bash
curl -L get.axeni.de/ambxst | sh
````

> [!WARNING]
> Ambxst is currently in early development.

---

### What does the installation do?

> [!IMPORTANT]
> For now Ambxst is installed via Nix flakes, so **Nix is required** for supporting it on as many distros as possible. But we are looking for contributions to support other package managers (and make this easier for everyone).

On **non-NixOS** distros, the installation script does the following:

* Installs [Nix](https://en.wikipedia.org/wiki/Nix_%28package_manager%29) if it's not already installed.
* Installs some necessary system dependencies (only a few that Nix cannot handle by itself).
* Installs Ambxst as a Nix flake. (*Dependency hell*? No, thanks. 😎)
* Creates an alias to launch `ambxst` from anywhere
  (for example: `exec-once = ambxst` in your `hyprland.conf`).
* Gives you a kiss on the cheek. 😘 (Optional, of course.)

On **NixOS**:

* Installs Ambxst via:

  ```bash
  nix profile add github:Axenide/Ambxst
  ```

> [!NOTE]
> The installation script doesn't do anything else on NixOS, so you can declare it however you like in your system.

---

<h2><sub><img src="https://raw.githubusercontent.com/Tarikul-Islam-Anik/Telegram-Animated-Emojis/main/Activity/Sparkles.webp" alt="Sparkles" width="32" height="32" /></sub> Features</h2>

* [x] Customizable components
* [x] Themes
* [x] System integration
* [x] App launcher
* [x] Clipboard manager
* [x] Quick notes (and not so quick ones)
* [x] Wallpaper manager
* [x] Emoji picker
* [x] [tmux](https://github.com/tmux/tmux) session manager
* [x] System monitor
* [x] Media control
* [x] Notification system
* [x] Wi-Fi manager
* [x] Bluetooth manager
* [x] Audio mixer
* [x] [EasyEffects](https://github.com/wwmm/easyeffects) integration
* [x] Screen capture
* [x] Screen recording
* [x] Color picker
* [x] OCR
* [x] QR and barcode scanner
* [x] Webcam mirror
* [x] Game mode
* [x] Night mode
* [x] Power profile manager
* [x] AI Assistant
* [x] Weather
* [x] Calendar
* [x] Power menu
* [x] Workspace management
* [x] Support for different layouts (dwindle, master, scrolling, etc.)
* [x] Multi-monitor support
* [x] Customizable keybindings
* [ ] Plugin and extension system
* [ ] Polkit
* [ ] Compatibility with other Wayland compositors

---

## What about the *docs*?

I want to release this before the end of the year, so you'll have to wait a bit for the full documentation. u_u

For now, the most important things to know are:

* The main configuration is located at `~/.config/Ambxst`
* Removing Ambxst is as simple as:

  ```bash
  nix profile remove Ambxst
  ```
* You can ask anything on the:

  * [Axenide Discord server](https://discord.com/invite/gHG9WHyNvH)
  * [GitHub discussions](https://github.com/Axenide/Ambxst/discussions)

> [!CAUTION]
> Packages installed via Nix will take priority over system ones.
> Keep this in mind if you run into version conflicts.

## Credits
- [end-4](https://github.com/end-4) for his awesome projects. I learned a lot from them! (And *yoinked* a lot of code, too. 😅)
- [soramane](https://github.com/soramanew) for helping me when I started with Quickshell. (You probably don't remember, but still, heh.)
- [outfoxxed](https://outfoxxed.me/) for creating Quickshell and great documentation!
- [tr1x_em](https://github.com/tr1x_em) for being a great friend and helping me find great tools. You rock!
- [Darsh](https://github.com/its-darsh) for not killing me when I left Fabric. u_u (Also for being a great friend and creating Fabric! Without Fabric, Ax-Shell wouldn't exist, so Ambxst wouldn't either. Thank you!)
- [Mario](https://github.com/mariokhz) for being a great friend and showing me Quickshell!
- [Samouly](https://github.com/N1xev) for being Samouly. :3
- [Zen](https://github.com/wer-zen) for being a great friend and helping me when I started with Quickshell too!
- [kh](https://www.youtube.com/watch?v=dQw4w9WgXcQ) for being an awesome human being and listening to my delusions about Ambxst. :D
- And you, the user, for trying out Ambxst! You're awesome! 💖

(If I forgot someone, please let me know. 🙏)
