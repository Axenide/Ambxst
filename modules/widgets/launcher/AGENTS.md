# AGENTS.md: modules/widgets/launcher/

## OVERVIEW
Multi-tab launcher with unified search. Combines app search, clipboard, emoji, tmux, and notes into single interface with prefix-based tab switching.

## STRUCTURE
```
launcher/
├── LauncherView.qml    # 1243 lines. Root component, tab orchestration, unified search
└── qmldir
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **Unified search logic** | LauncherView.qml lines 84-118 | `detectPrefix()` - maps prefix to tab |
| **App search** | LauncherView.qml lines 120-1079 | AppLauncher component with fuzzy filtering |
| **App execution** | LauncherView.qml lines 228-235 | `executeApp()` via `AppSearch.execute` |
| **Incremental loading** | LauncherView.qml lines 145-171 | Batch loading for smooth UI |
| **Expandable options** | LauncherView.qml lines 815-1004 | Right-click menu: Launch, Pin, Shortcut |
| **Tab orchestration** | LauncherView.qml lines 1082-1192 | StackLayout + Loader for lazy tabs |
| **Clipboard tab** | dashboard/clipboard/ClipboardTab.qml | Loaded on demand |
| **Emoji tab** | dashboard/emoji/EmojiTab.qml | Loaded on demand |
| **Tmux tab** | dashboard/tmux/TmuxTab.qml | Loaded on demand |
| **Notes tab** | dashboard/notes/NotesTab.qml | Loaded on demand |

## KEY SERVICES
| Service | Role |
|---------|------|
| `AppSearch` | Fuzzy query `fuzzyQuery()`, `getAllApps()`, app indexing |
| `UsageTracker` | `recordUsage(appId)` for sorting priority |
| `TaskbarApps` | `isPinned()`, `togglePin()` for dock integration |
| `GlobalStates.launcherSearchText` | Shared search state across tabs |
| `GlobalStates.launcherSelectedIndex` | Selection state sync |
| `Config.prefix.*` | Prefix mappings (clipboard, emoji, tmux, notes) |

## CONVENTIONS
- Uses lazy Loader pattern for non-default tabs to reduce startup cost
- Incremental loading with 10-app batches for smooth scrolling
- Prefix detection triggers tab switch and extracts remaining search text
- `Qt.callLater()` ensures proper focus after tab switches
- StyledRect variants: `"pane"` for expanded state, `"primary"` for selection

## ANTI-PATTERNS
- Direct app execution without recording usage via `UsageTracker.recordUsage()`
- Synchronous loading of all apps instead of incremental batches
- Missing `prefixDisabled` flag during backspace navigation causes re-detection loops