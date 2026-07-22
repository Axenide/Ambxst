.pragma library

var data = {
    /** Position of the bar on screen. @type {string} @default "top" */
    "position": "top",
    /** Custom launcher icon (empty = use default). @type {string} @default "" */
    "launcherIcon": "",
    /** Tint the launcher icon with the theme color. @type {boolean} @default true */
    "launcherIconTint": true,
    /** Tint the launcher icon fully (not just the glyph). @type {boolean} @default true */
    "launcherIconFullTint": true,
    /** Size of the launcher icon in pixels. @type {number} @min 0 @max 128 @default 24 */
    "launcherIconSize": 24,
    /** Style of the bar corners. @type {string} @enum ["default","squished"] @default "default" */
    "pillStyle": "default",
    /** List of monitor names to show the bar on (empty = all). @type {string[]} @default [] */
    "screenList": [],
    /** Enable Firefox media player integration. @type {boolean} @default false */
    "enableFirefoxPlayer": false,
    /** Bar background gradient definition. @type {array} @default [["surface", 0.0]] */
    "barColor": [["surface", 0.0]],
    /** Enable a frame around the bar. @type {boolean} @default false */
    "frameEnabled": false,
    /** Thickness of the bar frame in pixels. @type {number} @min 0 @max 100 @default 6 */
    "frameThickness": 6,
    /** Whether the bar is pinned (always visible) on startup. @type {boolean} @default true */
    "pinnedOnStartup": true,
    /** Enable hover-to-reveal for auto-hidden bar. @type {boolean} @default true */
    "hoverToReveal": true,
    /** Height of the hover region in pixels. @type {number} @min 0 @max 200 @default 8 */
    "hoverRegionHeight": 8,
    /** Show the pin button on the bar. @type {boolean} @default true */
    "showPinButton": true,
    /** Whether the bar is visible during fullscreen windows. @type {boolean} @default false */
    "availableOnFullscreen": false,
    /** Use 12-hour format for the clock. @type {boolean} @default false */
    "use12hFormat": false,
    /** Contain the bar within the frame (if frameEnabled). @type {boolean} @default false */
    "containBar": false,
    /** Keep the bar shadow when contained. @type {boolean} @default false */
    "keepBarShadow": false,
    /** Keep the bar border when contained. @type {boolean} @default false */
    "keepBarBorder": false
}
