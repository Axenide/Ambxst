// Shared helpers for dashboard tab lists (clipboard, notes, tmux).
.pragma library

// Base (collapsed) height of a list row across dashboard tabs.
var ROW_HEIGHT = 48;

// Compute the height of an expanded row given the number of option buttons.
// Layout: base row + 4px gap + (36px per option, capped at 3) + 8px padding.
function expandedRowHeight(optionsCount) {
    var listHeight = 36 * Math.min(3, optionsCount);
    return ROW_HEIGHT + 4 + listHeight + 8;
}

// Scroll a ListView so that the row starting at `itemY` with height
// `rowHeight` is fully visible. No-op if it already is.
function scrollToReveal(listView, itemY, rowHeight) {
    var maxContentY = Math.max(0, listView.contentHeight - listView.height);
    var viewportTop = listView.contentY;
    var viewportBottom = viewportTop + listView.height;
    var itemBottom = itemY + rowHeight;

    if (itemY < viewportTop) {
        listView.contentY = itemY;
    } else if (itemBottom > viewportBottom) {
        listView.contentY = Math.min(itemBottom - listView.height, maxContentY);
    }
}
