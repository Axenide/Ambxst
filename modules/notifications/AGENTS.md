# AGENTS.md - modules/notifications/

## OVERVIEW
D-Bus notification server with persistence, grouping, and inline reply support.
Implements the org.freedesktop.Notifications specification.

## STRUCTURE
| File | Role |
|------|------|
| `Notifications.qml` | Root service; D-Bus server, notification storage, grouping logic |
| `NotificationDelegate.qml` | Individual notification rendering; actions, inline reply, timeout |
| `NotificationGroup.qml` | Grouped notification stack; expandable/collapsible |
| `NotificationPopup.qml` | Transient popup for non-persistent notifications |

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| D-Bus server | `Notifications.qml` | `NotificationServer` component; handles `Notify`, `Close`, `GetServerInformation` |
| Storage | `Notifications.qml` | SQLite via `Process` calling `sqlite3`; persists notifications |
| Grouping | `NotificationGroup.qml` | Groups by app name; collapsible stack |
| Actions | `NotificationDelegate.qml` | Action buttons, inline reply text field |
| Config | `Config.notifications.*` | Urgency, timeout, position, history settings |

## CONVENTIONS
- Uses `Quickshell.Services.Notifications` for the D-Bus server layer.
- Notification icons resolved via `Qt.labs.platform` or `QIcon`.
- Inline reply uses `TextField` with `Keys.onEnterPressed` to send reply.
- Actions are rendered as buttons with `StyledRect` styling.
- Uses `Styling.animEasing` for popup enter/exit animations.

## ANTI-PATTERNS
- Don't block the D-Bus thread — use `Qt.callLater()` for heavy operations.
- Don't store notification content in memory only — persist to SQLite.
- Don't forget to emit `NotificationRemoved` signal when closing.
- Don't use `Timer` for notification timeouts without respecting `expireTimeout` from the sender.
