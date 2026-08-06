# SCRIPTS KNOWLEDGE BASE

## OVERVIEW
Remaining Bash utilities. All Python and most Bash logic has moved into the Go backend (`backend/`): services (`systemmonitor`, `sleep`, `weather`, `clipboard`, `network`, `brightness`, `config`, `keystore`, `linkpreview`) and CLI subcommands (`colorpicker`, `lockwall`, `thumbs`, `dthumbs`, `chatlist`, `writeshader`). The scripts below are thin external-tool wrappers kept for compositor/tooling edge cases.

## WHERE TO LOOK
| Script | Language | Called By | Role |
|--------|----------|-----------|------|
| `clipboard_check.sh` | Bash | Go clipboard svc | Validates clipboard state and deduplication |
| `clipboard_insert.sh` | Bash | Go clipboard svc | Inserts items into clipboard via `wl-copy` |
| `ocr.sh` | Bash | Tools | Screenshot → OCR text extraction |
| `qr_scan.sh` | Bash | Tools | QR/barcode scanning from screen capture |
| `google_lens.sh` | Bash | Tools | Google Lens image search |
| `brightness_list.sh` | Bash | Go brightness cmd | Enumerates available brightness devices |
| `wf-record.sh` | Bash | Screen recording | `wf-recorder`/`gpu-screen-recorder` wrapper |

## MIGRATED (removed from scripts/)
| Former script | Go equivalent |
|---------------|---------------|
| `system_monitor.py` | `svc/systemmonitor` (IPC) |
| `weather.sh` | `svc/weather` (IPC) |
| `clipboard_watch.sh` | `svc/clipboard` watch (IPC) |
| `sleep_monitor.sh`, `loginlock.sh` | `svc/sleep` (IPC) |
| `daemon_priority.sh` | CLI `runShell()` |
| `keystore.py` | `svc/keystore` (IPC) |
| `link_preview.py` | `svc/linkpreview` (IPC) |
| `colorpicker.py` | CLI `ambxst colorpicker` |
| `lockwall.py` | CLI `ambxst lockwall` |
| `thumbgen.py` | CLI `ambxst thumbs` |
| `desktop_thumbgen.py` | CLI `ambxst dthumbs` |

## CONVENTIONS
- **Communication**: Scripts output to stdout; QML reads via `Process` + `SplitParser` or `StdioCollector`.
- **Format**: Bash scripts output line-delimited text.
- **Dependencies**: Scripts assume tools are installed (`wl-paste`, `wl-copy`, `hyprpicker`, `grim`, `slurp`, `tesseract`, `brightnessctl`). Nix/install.sh handles dependencies.
- **Error handling**: Scripts should exit cleanly on missing tools; QML services provide fallback values.
