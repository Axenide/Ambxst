.pragma library

var data = {
    /** Whether the overview popup is enabled at all. @type {boolean} @default true */
    "enabled": true,
    /** Number of rows in the workspace grid. @type {number} @min 1 @max 20 @default 2 */
    "rows": 2,
    /** Number of columns in the workspace grid. @type {number} @min 1 @max 20 @default 5 */
    "columns": 5,
    /** Scale factor for workspace thumbnails. @type {number} @min 0 @max 1 @default 0.15 */
    "scale": 0.15,
    /** Spacing between workspace thumbnails in pixels. @type {number} @min 0 @max 200 @default 8 */
    "workspaceSpacing": 8
}
