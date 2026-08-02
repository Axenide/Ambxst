# SCRIPTS KNOWLEDGE BASE

## OVERVIEW
Python and Bash backend utilities. Previously invoked by QML services via `Quickshell.Io.Process`; most system-level tasks (monitoring, clipboard watcher, sleep/lock, weather, config writes) now live in the Go backend (`backend/`). Remaining scripts handle image processing and external tool wrappers.

## WHERE TO LOOK
| Script | Language | Called By | Role |
|--------|----------|-----------|------|
| `clipboard_check.sh` | Bash | Go clipboard svc | Validates clipboard state and deduplication |
| `clipboard_insert.sh` | Bash | Go clipboard svc | Inserts items into clipboard via `wl-copy` |
| `colorpicker.py` | Python | Tools | `hyprpicker` wrapper with format output |
| `ocr.sh` | Bash | Tools | Screenshot → OCR text extraction |
| `qr_scan.sh` | Bash | Tools | QR/barcode scanning from screen capture |
| `google_lens.sh` | Bash | Tools | Google Lens image search |
| `thumbgen.py` | Python | `WallpapersTab` | Wallpaper thumbnail generation |
| `desktop_thumbgen.py` | Python | `DesktopService.qml` | Desktop icon thumbnail generation |
| `lockwall.py` | Python | `LockScreen.qml` | Lockscreen wallpaper blur preprocessing |
| `brightness_list.sh` | Bash | Go brightness cmd | Enumerates available brightness devices |
| `wf-record.sh` | Bash | Screen recording | `wf-recorder`/`gpu-screen-recorder` wrapper |
| `link_preview.py` | Python | Clipboard | URL metadata/preview extraction |

## CONVENTIONS
- **Communication**: Scripts output to stdout; QML reads via `Process` + `SplitParser` or `StdioCollector`.
- **Format**: Python scripts output JSON; Bash scripts output line-delimited text.
- **Dependencies**: Scripts assume tools are installed (`wl-paste`, `wl-copy`, `hyprpicker`, `grim`, `slurp`, `tesseract`, `brightnessctl`). Nix/install.sh handles dependencies.
- **Error handling**: Scripts should exit cleanly on missing tools; QML services provide fallback values.
