# AGENTS.md: modules/lockscreen/

## OVERVIEW
Lock screen UI with PAM authentication via WlSessionLockSurface.

## STRUCTURE
```
modules/lockscreen/
├── LockScreen.qml       # Main component (750 lines)
├── ambxst-auth          # Helper script (if any)
└── config/pam/          # PAM configuration
    └── password.conf    # Custom PAM rules for lockscreen
```
Related: `modules/widgets/dashboard/widgets/LockPlayer.qml` (music player on lock screen).

## WHERE TO LOOK
| Symbol | Location | Role |
|--------|----------|------|
| `WlSessionLockSurface` | `LockScreen.qml:18` | Root; handles Wayland session lock protocol |
| `PamContext` | `LockScreen.qml:666` | PAM authentication via Quickshell.Services.Pam |
| `ScreencopyView` | `LockScreen.qml:84` | Captures frozen screen background on lock |
| `TintedWallpaper` | `LockScreen.qml:30` | Wallpaper with blur effect layer |
| `failLockSecondsLeft` | `LockScreen.qml:24` | Tracks account lockout after failed attempts |
| `authPasswordHolder` | `LockScreen.qml:620` | Temp holder for password during PAM auth |
| `wrongPasswordAnim` | `LockScreen.qml:541` | Shake animation on auth failure |
| `unlockTimer` | `LockScreen.qml:588` | Triggers GlobalStates.lockscreenVisible = false after exit animation |

Key behaviors:
- On lock: capture screen (`screencopyBackground.captureFrame()`), start entry animations, force focus to password field
- On auth: store password in temp holder, `pamAuth.start()`, respond to PAM messages via `onPamMessage`
- On success: trigger exit animation (zoom + fade), start unlockTimer, set lockscreenVisible=false
- On failure: shake animation, clear password, update failLock countdown

## CONVENTIONS
Same as root AGENTS.md with additions:
- Use `Quickshell.Services.Pam` module for authentication
- Use `WlSessionLockSurface` as root component for lock surfaces
- Store sensitive data (password) in temporary QtObject, clear immediately after auth
- Use Process for system commands (`whoami`, `hostname`, `faillock`)
- Handle PAM message responses in `onPamMessage` signal

## ANTI-PATTERNS
- Never log passwords or send them to debug output
- Don't modify authPasswordHolder after PAM completion (should be cleared)
- Don't call pamAuth.start() while already authenticating (check authenticating flag)
- Don't forget to clear password on both success and failure paths