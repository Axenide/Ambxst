# SCRIPTS KNOWLEDGE BASE

## OVERVIEW
Python and Bash backend utilities invoked by QML services via `Quickshell.Io.Process`. Handle system-level tasks that are impractical in pure QML/JS: hardware monitoring, clipboard persistence, image processing, and external tool wrappers.

## WHERE TO LOOK
| Script | Language | Called By | Role |
|--------|----------|-----------|------|
| `system_monitor.py` | Python | `SystemResources.qml` | CPU, RAM, GPU, disk, temperature polling. Outputs JSON to stdout |
| `clipboard_watch.sh` | Bash | `ClipboardService.qml` | Watches clipboard changes via `wl-paste --watch` |
| `clipboard_check.sh` | Bash | `ClipboardService.qml` | Validates clipboard state and deduplication |
| `clipboard_insert.sh` | Bash | `ClipboardService.qml` | Inserts items into clipboard via `wl-copy` |
| `colorpicker.py` | Python | Tools | `hyprpicker` wrapper with format output |
| `ocr.sh` | Bash | Tools | Screenshot → OCR text extraction |
| `qr_scan.sh` | Bash | Tools | QR/barcode scanning from screen capture |
| `google_lens.sh` | Bash | Tools | Google Lens image search |
| `thumbgen.py` | Python | `WallpapersTab` | Wallpaper thumbnail generation |
| `desktop_thumbgen.py` | Python | `DesktopService.qml` | Desktop icon thumbnail generation |
| `lockwall.py` | Python | `LockScreen.qml` | Lockscreen wallpaper blur preprocessing |
| `brightness_list.sh` | Bash | `Brightness.qml` | Enumerates available brightness devices |
| `weather.sh` | Bash | `WeatherService.qml` | Weather data fetching |
| `wf-record.sh` | Bash | Screen recording | `wf-recorder`/`gpu-screen-recorder` wrapper |
| `link_preview.py` | Python | Clipboard | URL metadata/preview extraction |
| `sleep_monitor.sh` | Bash | `SuspendManager` | Monitors system sleep/wake events |
| `loginlock.sh` | Bash | `LockScreen` | Login lock coordination |
| `daemon_priority.sh` | Bash | Shell init | Process priority adjustment |

## CONVENTIONS
- **Communication**: Scripts output to stdout; QML reads via `Process` + `SplitParser` or `StdioCollector`.
- **Format**: Python scripts output JSON; Bash scripts output line-delimited text.
- **Dependencies**: Scripts assume tools are installed (`wl-paste`, `wl-copy`, `hyprpicker`, `grim`, `slurp`, `tesseract`, `brightnessctl`). Nix/install.sh handles dependencies.
- **Error handling**: Scripts should exit cleanly on missing tools; QML services provide fallback values.
