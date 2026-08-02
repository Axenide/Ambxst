# AGENTS.md: modules/lockscreen/

## OVERVIEW
Lock screen UI with PAM authentication via WlSessionLockSurface.

## STRUCTURE
```
modules/lockscreen/
├── LockScreen.qml       # Main component (800+ lines)
├── FingerprintService.qml  # fprintd D-Bus communication service
├── FingerprintPopup.qml    # Reusable fingerprint scanning GUI
├── ambxst+-auth          # Helper script (if any)
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

### Fingerprint Authentication
| Symbol | Location | Role |
|--------|----------|------|
| `FingerprintService` | `FingerprintService.qml` | Singleton; fprintd D-Bus communication via Python script |
| `FingerprintPopup` | `FingerprintPopup.qml` | Floating PanelWindow scan indicator, instantiated/driven by `FprintdInterceptor` (polkit/sudo coverage) |
| `FingerprintEnrollWizard` | `FingerprintEnrollWizard.qml` | Guided enrollment flow with visual feedback |
| `DashboardAuthGate` | `DashboardAuthGate.qml` | Auth prompt for dashboard access (fingerprint/password) |
| `startFingerprintAuth()` | `LockScreen.qml` | Starts fingerprint verification, sets scanning state |
| `fingerprintActive` | `LockScreen.qml` | Tracks if fingerprint scan is in progress |
| `fingerprintAvailable` | `LockScreen.qml` | Whether fprintd device is available |
| `fingerprintEnrolled` | `LockScreen.qml` | Whether any fingers are enrolled |
| `fingerprintTimeoutTimer` | `LockScreen.qml` | Falls back to password after timeout |
| `fingerprintErrorTimer` | `LockScreen.qml` | Clears fingerprint error state after delay |
| `retryCount` | `FingerprintService.qml` | Current retry attempt for verification |
| `maxRetries` | `FingerprintService.qml` | Maximum retry attempts (default: 3) |
| `deviceMonitorTimer` | `FingerprintService.qml` | Periodic device availability check |
| `deviceLost()` | `FingerprintService.qml` | Signal emitted when fprintd device disconnects |
| `deviceRestored()` | `FingerprintService.qml` | Signal emitted when fprintd device reconnects |

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