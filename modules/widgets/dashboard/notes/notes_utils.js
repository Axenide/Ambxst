// notes_utils.js - Utility functions for notes management

/**
 * Generate a UUID v4
 * @returns {string} UUID string
 */
function generateUUID() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        var r = Math.random() * 16 | 0;
        var v = c === 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
}

/**
 * Get current timestamp in ISO format
 * @returns {string} ISO timestamp
 */
function getCurrentTimestamp() {
    return new Date().toISOString();
}

/**
 * Format a timestamp for display
 * @param {string} isoTimestamp - ISO timestamp string
 * @returns {string} Formatted date string
 */
function formatTimestamp(isoTimestamp) {
    if (!isoTimestamp) return "";
    try {
        var date = new Date(isoTimestamp);
        var now = new Date();
        var diffMs = now - date;
        var diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
        
        if (diffDays === 0) {
            // Today - show time
            return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        } else if (diffDays === 1) {
            return "Yesterday";
        } else if (diffDays < 7) {
            return diffDays + " days ago";
        } else {
            return date.toLocaleDateString([], { month: 'short', day: 'numeric' });
        }
    } catch (e) {
        return "";
    }
}

/**
 * Sanitize title for use as filename (not used currently, we use UUIDs)
 * @param {string} title - Note title
 * @returns {string} Sanitized filename
 */
function sanitizeFilename(title) {
    return title
        .toLowerCase()
        .replace(/[^a-z0-9\s-]/g, '')
        .replace(/\s+/g, '-')
        .substring(0, 50);
}

/**
 * Extract first line or preview from markdown content
 * @param {string} content - Markdown content
 * @param {int} maxLength - Maximum length for preview
 * @returns {string} Preview text
 */
function getPreview(content, maxLength) {
    if (!content) return "";
    maxLength = maxLength || 100;
    
    // Remove markdown headers and get first meaningful line
    var lines = content.split('\n');
    var preview = "";
    
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        // Skip empty lines and headers for preview
        if (line && !line.startsWith('#')) {
            preview = line;
            break;
        }
        // If it's a header, use it as fallback
        if (line.startsWith('#') && !preview) {
            preview = line.replace(/^#+\s*/, '');
        }
    }
    
    if (preview.length > maxLength) {
        return preview.substring(0, maxLength) + "...";
    }
    return preview;
}

/**
 * Parse index.json structure
 * @param {string} jsonString - JSON content
 * @returns {object} Parsed index object with order and notes
 */
function parseIndex(jsonString) {
    try {
        var data = JSON.parse(jsonString);
        return {
            order: data.order || [],
            notes: data.notes || {}
        };
    } catch (e) {
        return {
            order: [],
            notes: {}
        };
    }
}

/**
 * Serialize index object to JSON string
 * @param {object} indexData - Index object
 * @returns {string} JSON string
 */
function serializeIndex(indexData) {
    return JSON.stringify(indexData, null, 2);
}

/**
 * Create a new note entry
 * @param {string} title - Note title
 * @returns {object} Note metadata object
 */
function createNoteEntry(title) {
    var now = getCurrentTimestamp();
    return {
        title: title || "Untitled Note",
        created: now,
        modified: now
    };
}

/**
 * Filter notes by search text
 * @param {array} notes - Array of note objects with title and content
 * @param {string} searchText - Search query
 * @returns {array} Filtered notes
 */
function filterNotes(notes, searchText) {
    if (!searchText || searchText.length === 0) {
        return notes;
    }
    
    var query = searchText.toLowerCase();
    return notes.filter(function(note) {
        var title = (note.title || "").toLowerCase();
        var content = (note.content || "").toLowerCase();
        return title.indexOf(query) !== -1 || content.indexOf(query) !== -1;
    });
}

/**
 * Move item in array from one index to another
 * @param {array} arr - Array to modify
 * @param {int} fromIndex - Source index
 * @param {int} toIndex - Destination index
 * @returns {array} Modified array
 */
function moveArrayItem(arr, fromIndex, toIndex) {
    if (fromIndex < 0 || fromIndex >= arr.length) return arr;
    if (toIndex < 0 || toIndex >= arr.length) return arr;
    if (fromIndex === toIndex) return arr;
    
    var newArr = arr.slice();
    var item = newArr.splice(fromIndex, 1)[0];
    newArr.splice(toIndex, 0, item);
    return newArr;
}
