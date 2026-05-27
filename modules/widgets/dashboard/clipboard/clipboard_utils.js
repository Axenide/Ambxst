// Clipboard utility functions for icon handling

// Get icon for mimetype
function getIconForMime(mimeType, content) {
    if (!mimeType) return "";
    
    // Check if it's a URL (for favicon support)
    if (mimeType === "text/plain" && content) {
        var urlMatch = content.match(/^https?:\/\/[^\s]+/);
        if (urlMatch) {
            // Extract domain for favicon
            try {
                var url = new URL(content.trim());
                return url.origin + "/favicon.ico";
            } catch (e) {
                // Invalid URL, fall through to default handling
            }
        }
    }
    
    // Image types
    if (mimeType.startsWith("image/")) {
        return "image";
    }
    
    // Text types
    if (mimeType.startsWith("text/") || mimeType === "application/json" || 
        mimeType === "application/xml" || mimeType === "application/javascript") {
        return "text";
    }
    
    // File/URI list
    if (mimeType === "text/uri-list") {
        return "file";
    }
    
    // Video types
    if (mimeType.startsWith("video/")) {
        return "video";
    }
    
    // Audio types
    if (mimeType.startsWith("audio/")) {
        return "audio";
    }
    
    // Archive types
    if (mimeType.match(/zip|tar|gz|bz2|xz|7z|rar/)) {
        return "archive";
    }
    
    // PDF
    if (mimeType === "application/pdf") {
        return "pdf";
    }
    
    // Default
    return "file";
}

// Check if content is a URL
function isUrl(text) {
    if (!text) return false;
    var trimmed = text.trim();
    return /^https?:\/\/[^\s]+/.test(trimmed);
}

// Get Google Favicon service URL (fallback for when direct favicon fails)
function getGoogleFaviconUrl(domain) {
    if (!domain) return "";
    return "https://www.google.com/s2/favicons?domain=" + encodeURIComponent(domain) + "&sz=64";
}

// Extract basic favicon URL from content (tries /favicon.ico first)
function getFaviconUrl(text) {
    if (!text) return "";
    try {
        var trimmed = text.trim();
        var url = new URL(trimmed);
        return url.origin + "/favicon.ico";
    } catch (e) {
        return "";
    }
}

// Get fallback favicon URL using Google service
function getFaviconFallbackUrl(text) {
    if (!text) return "";
    try {
        var trimmed = text.trim();
        var url = new URL(trimmed);
        return getGoogleFaviconUrl(url.hostname);
    } catch (e) {
        return "";
    }
}

// Get Nerd Font icon for file extension
function getNerdFontIconForExtension(filePath) {
    if (!filePath) return "";
    
    var ext = filePath.split('.').pop().toLowerCase();
    
    // Programming languages
    if (ext === "js" || ext === "mjs") return "󰌞"; // JavaScript
    if (ext === "ts") return "󰛦"; // TypeScript
    if (ext === "py") return "󰌠"; // Python
    if (ext === "java") return "󰬷"; // Java
    if (ext === "cpp" || ext === "cc" || ext === "cxx") return "󰙲"; // C++
    if (ext === "c") return "󰙱"; // C
    if (ext === "rs") return "󱘗"; // Rust
    if (ext === "go") return "󰟓"; // Go
    if (ext === "php") return "󰌟"; // PHP
    if (ext === "rb") return "󰴭"; // Ruby
    
    // Web
    if (ext === "html" || ext === "htm") return "󰌝"; // HTML
    if (ext === "css") return "󰌜"; // CSS
    if (ext === "json") return "󰘦"; // JSON
    if (ext === "xml") return "󰗀"; // XML
    
    // Documents
    if (ext === "pdf") return "󰈦"; // PDF
    if (ext === "doc" || ext === "docx") return "󰈬"; // Word
    if (ext === "xls" || ext === "xlsx") return "󰈛"; // Excel
    if (ext === "ppt" || ext === "pptx") return "󰈧"; // PowerPoint
    if (ext === "txt") return "󰈙"; // Text
    if (ext === "md") return "󰍔"; // Markdown
    
    // Images
    if (ext === "png" || ext === "jpg" || ext === "jpeg" || ext === "gif" || 
        ext === "bmp" || ext === "webp" || ext === "svg" || ext === "ico") return "󰈟"; // Image
    
    // Video
    if (ext === "mp4" || ext === "mkv" || ext === "avi" || ext === "mov" || 
        ext === "wmv" || ext === "flv" || ext === "webm") return "󰈫"; // Video
    
    // Audio
    if (ext === "mp3" || ext === "wav" || ext === "flac" || ext === "ogg" || 
        ext === "m4a" || ext === "wma") return "󰈣"; // Audio
    
    // Archives
    if (ext === "zip" || ext === "tar" || ext === "gz" || ext === "bz2" || 
        ext === "xz" || ext === "7z" || ext === "rar") return "󰛫"; // Archive
    
    // Default file icon
    return "󰈔";
}

function escapeShellArg(arg) {
    if (arg === null || arg === undefined) return "''";
    return "'" + arg.toString().replace(/'/g, "'\\''") + "'";
}
