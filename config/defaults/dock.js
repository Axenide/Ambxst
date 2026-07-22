.pragma library

var data = {
    /** Enable the dock. @type {boolean} @default true */
    "enabled": true,
    /** Dock theme: "default" or "integrated" (into bar). @type {string} @enum ["default","integrated"] @default "default" */
    "theme": "default",
    /** Position of the dock. @type {string} @enum ["top","bottom","left","right"] @default "bottom" */
    "position": "bottom",
    /** Height of the dock in pixels. @type {number} @min 0 @max 200 @default 48 */
    "height": 48,
    /** Size of dock icons in pixels. @type {number} @min 0 @max 128 @default 24 */
    "iconSize": 24,
    /** Spacing between dock items in pixels. @type {number} @min 0 @max 100 @default 4 */
    "spacing": 4,
    /** Margin around the dock in pixels. @type {number} @min 0 @max 100 @default 4 */
    "margin": 4,
    /** Height of the hover region in pixels. @type {number} @min 0 @max 200 @default 16 */
    "hoverRegionHeight": 16,
    /** Whether the dock is pinned on startup. @type {boolean} @default false */
    "pinnedOnStartup": false,
    /** Enable hover-to-reveal. @type {boolean} @default true */
    "hoverToReveal": true,
    /** Visible during fullscreen windows. @type {boolean} @default false */
    "availableOnFullscreen": false,
    /** Show running window indicators. @type {boolean} @default true */
    "showRunningIndicators": true,
    /** Show the pin button. @type {boolean} @default true */
    "showPinButton": true,
    /** Show the overview button. @type {boolean} @default true */
    "showOverviewButton": true,
    /** Regex patterns for apps to ignore in the dock. @type {string[]} @default */
    "ignoredAppRegexes": [
        "quickshell.*",
        "xdg-desktop-portal.*"
    ],
    /** List of monitor names (empty = all). @type {string[]} @default [] */
    "screenList": [],
    /** Keep the dock hidden. @type {boolean} @default false */
    "keepHidden": false
}
