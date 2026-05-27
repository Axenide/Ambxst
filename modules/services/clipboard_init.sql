-- Ambxst Clipboard Database Schema
-- Simplified version based on Vicinae's clipboard system

CREATE TABLE IF NOT EXISTS clipboard_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    content_hash TEXT NOT NULL UNIQUE,
    mime_type TEXT NOT NULL DEFAULT 'text/plain',
    preview TEXT NOT NULL,
    full_content TEXT,
    is_image INTEGER NOT NULL DEFAULT 0,
    binary_path TEXT,
    size INTEGER NOT NULL DEFAULT 0,
    pinned INTEGER NOT NULL DEFAULT 0,
    alias TEXT,
    display_index INTEGER,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_content_hash ON clipboard_items(content_hash);
CREATE INDEX IF NOT EXISTS idx_created_at ON clipboard_items(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_is_image ON clipboard_items(is_image);
CREATE INDEX IF NOT EXISTS idx_pinned ON clipboard_items(pinned DESC);
CREATE INDEX IF NOT EXISTS idx_display_index ON clipboard_items(pinned DESC, display_index ASC);

-- Virtual table for full-text search
CREATE VIRTUAL TABLE IF NOT EXISTS clipboard_fts USING fts5(
    preview,
    full_content,
    content=clipboard_items,
    content_rowid=id
);

-- Triggers to keep FTS table in sync
CREATE TRIGGER IF NOT EXISTS clipboard_items_ai AFTER INSERT ON clipboard_items BEGIN
    INSERT INTO clipboard_fts(rowid, preview, full_content)
    VALUES (new.id, new.preview, new.full_content);
END;

CREATE TRIGGER IF NOT EXISTS clipboard_items_ad AFTER DELETE ON clipboard_items BEGIN
    DELETE FROM clipboard_fts WHERE rowid = old.id;
END;

CREATE TRIGGER IF NOT EXISTS clipboard_items_au AFTER UPDATE ON clipboard_items BEGIN
    DELETE FROM clipboard_fts WHERE rowid = old.id;
    INSERT INTO clipboard_fts(rowid, preview, full_content)
    VALUES (new.id, new.preview, new.full_content);
END;
