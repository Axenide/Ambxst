# AGENTS.md: modules/notifications/

## OVERVIEW
Notification popup system built on Quickshell.Services.Notifications. Handles display, grouping, dismissal, and action invocation for notifications.

## STRUCTURE
```
modules/notifications/
├── notification_utils.js          # Time formatting, body processing
├── NotificationPopup.qml          # Scope container with PanelWindow
├── NotificationListView.qml       # ListView model binding
├── NotificationDelegate.qml       # Core component (471 lines)
├── NotificationAppIcon.qml        # Icon/image with fallback chain
├── NotificationAnimation.qml     # Dismiss animation (slide + fade)
├── NotificationDismissButton.qml # Dismiss action button
├── NotificationActionButtons.qml # Action button repeater
├── NotificationGroup.qml         # Grouping logic
└── NotificationGroupExpandButton.qml # Expand toggle
```

## WHERE TO LOOK

| Task | File | Notes |
|------|------|-------|
| Popup container | `NotificationPopup.qml` | PanelWindow with WlrLayer.Overlay |
| List rendering | `NotificationListView.qml` | Binds to `Notifications.popupList` or `Notifications.notifications` |
| Core display | `NotificationDelegate.qml` | Handles both grouped and single modes |
| Icon handling | `NotificationAppIcon.qml` | Image > appIcon > Icons fallback chain |
| Dismissing | `NotificationAnimation.qml` | Scale + opacity + slide animation |
| Time formatting | `notification_utils.js` | `getFriendlyNotifTimeString()`, `processNotificationBody()` |

## CONVENTIONS

- **Urgency levels**: Use `NotificationUrgency.Normal` / `NotificationUrgency.Critical` from `Quickshell.Services.Notifications`
- **Critical styling**: `Colors.criticalRed`, `Colors.criticalText`, `DiagonalStripePattern` component
- **StyledRect variants**: `"primary"`, `"error"`, `"focus"`, `"common"` for button backgrounds
- **Animation duration**: Read `Config.animDuration` (not hardcoded)
- **Icons singleton**: `Icons.cancel`, `Icons.bell`, `Icons.alert`, `Icons.timer`
- **Delegate modes**: `onlyNotification=true` for popup, `expanded` controls group expansion state

## ANTI-PATTERNS

- **Raw Rectangle for backgrounds**: Use `StyledRect` with appropriate variant
- **Hardcoded animation durations**: Use `Config.animDuration`
- **Missing urgency checks**: Always check `urgency === NotificationUrgency.Critical` for special styling
- **No fallback for missing icons**: Chain `image` -> `appIcon` -> `Icons.*` fallback
- **Direct notification removal**: Use `Notifications.discardNotification(id)` through animation callback
