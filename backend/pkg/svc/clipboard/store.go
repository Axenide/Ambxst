package clipboard

import (
	"crypto/md5"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	sqlite3 "github.com/ncruces/go-sqlite3"
	"github.com/ncruces/go-sqlite3/driver"
	"github.com/ncruces/go-sqlite3/ext/fts5"
	_ "github.com/ncruces/go-sqlite3/vfs/adiantum"

	"ambxst/backend/pkg/paths"
)

// maxUnpinnedItems caps the unpinned history (pinned items are exempt).
const maxUnpinnedItems = 50

// schemaSQL creates the item table + FTS5 index + sync triggers. Both
// stores share it; the pinned column is kept for parity (always 1 in the
// pinned store, 0 in the unpinned one) so reindex SQL stays uniform.
const schemaSQL = `
CREATE TABLE IF NOT EXISTS clipboard_items (
	id INTEGER PRIMARY KEY,
	content_hash TEXT NOT NULL UNIQUE,
	mime_type TEXT NOT NULL,
	preview BLOB,
	full_content BLOB,
	is_image INTEGER DEFAULT 0,
	size INTEGER DEFAULT 0,
	pinned INTEGER DEFAULT 0,
	display_index INTEGER DEFAULT 0,
	alias TEXT,
	created_at INTEGER,
	updated_at INTEGER
);
CREATE INDEX IF NOT EXISTS idx_content_hash ON clipboard_items(content_hash);
CREATE INDEX IF NOT EXISTS idx_created_at ON clipboard_items(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_is_image ON clipboard_items(is_image);
CREATE INDEX IF NOT EXISTS idx_display_index ON clipboard_items(pinned DESC, display_index ASC);
CREATE VIRTUAL TABLE IF NOT EXISTS clipboard_fts USING fts5(
	preview,
	full_content,
	content='clipboard_items',
	content_rowid='id'
);
CREATE TRIGGER IF NOT EXISTS clipboard_items_ai AFTER INSERT ON clipboard_items BEGIN
	INSERT INTO clipboard_fts(rowid, preview, full_content)
	VALUES (new.id, new.preview, new.full_content);
END;
CREATE TRIGGER IF NOT EXISTS clipboard_items_ad AFTER DELETE ON clipboard_items BEGIN
	INSERT INTO clipboard_fts(clipboard_fts, rowid, preview, full_content)
	VALUES ('delete', old.id, old.preview, old.full_content);
END;
CREATE TRIGGER IF NOT EXISTS clipboard_items_au AFTER UPDATE ON clipboard_items BEGIN
	INSERT INTO clipboard_fts(clipboard_fts, rowid, preview, full_content)
	VALUES ('delete', old.id, old.preview, old.full_content);
	INSERT INTO clipboard_fts(rowid, preview, full_content)
	VALUES (new.id, new.preview, new.full_content);
END;
`

// itemID identifies an item across both stores: "p:12" (pinned) or "u:7".
type itemID struct {
	pinned bool
	id     int64
}

func (i itemID) String() string {
	if i.pinned {
		return fmt.Sprintf("p:%d", i.id)
	}
	return fmt.Sprintf("u:%d", i.id)
}

func parseID(raw string) (itemID, bool) {
	if len(raw) < 3 || raw[1] != ':' {
		return itemID{}, false
	}
	var num int64
	switch raw[0] {
	case 'p':
		if !scanInt(raw[2:], &num) {
			return itemID{}, false
		}
		return itemID{pinned: true, id: num}, true
	case 'u':
		if !scanInt(raw[2:], &num) {
			return itemID{}, false
		}
		return itemID{id: num}, true
	}
	return itemID{}, false
}

func scanInt(s string, out *int64) bool {
	var n int64
	if s == "" {
		return false
	}
	for _, c := range s {
		if c < '0' || c > '9' {
			return false
		}
		n = n*10 + int64(c-'0')
	}
	*out = n
	return true
}

// itemRow is a full clipboard row, used when moving rows between stores.
type itemRow struct {
	hash, mime, alias string
	preview, content  []byte
	isImage, size     int
	createdAt         int64
	updatedAt         int64
}

// store owns the two encrypted SQLite databases (pinned + unpinned) and
// serializes every access through one mutex. Encrypted stores use the
// adiantum VFS (pure Go, no cgo) with a per-installation key.
type store struct {
	paths    *paths.Paths
	hexKey   string
	mu       sync.Mutex
	pinned   *sql.DB
	unpinned *sql.DB
	tmpMode  bool
}

func newStore(p *paths.Paths) (*store, error) {
	hexKey, err := loadOrCreateKey(p.ClipboardKeyFile())
	if err != nil {
		return nil, err
	}
	s := &store{paths: p, hexKey: hexKey}
	if err := s.openDatabases(readTmpfsFlag(p)); err != nil {
		return nil, err
	}
	if err := s.migrateLegacy(); err != nil {
		// The daemon must not stall or die over a bad legacy DB.
		log.Printf("[clipboard] legacy migration: %v", err)
	}
	return s, nil
}

// loadOrCreateKey reads the hex key file, creating a random 32-byte key
// (0600) on first use.
func loadOrCreateKey(path string) (string, error) {
	if data, err := os.ReadFile(path); err == nil {
		key := strings.TrimSpace(string(data))
		if len(key) == 64 {
			return key, nil
		}
	}
	raw := make([]byte, 32)
	if _, err := rand.Read(raw); err != nil {
		return "", err
	}
	key := hex.EncodeToString(raw)
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return "", err
	}
	if err := os.WriteFile(path, []byte(key+"\n"), 0o600); err != nil {
		return "", err
	}
	return key, nil
}

// openDB opens an encrypted database, registering FTS5 on every connection.
func openDB(path, hexKey string) (*sql.DB, error) {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return nil, err
	}
	u := url.URL{
		Scheme: "file",
		Path:   path,
		RawQuery: url.Values{
			"vfs":    []string{"adiantum"},
			"hexkey": []string{hexKey},
		}.Encode(),
	}
	db, err := driver.Open(u.String(), func(conn *sqlite3.Conn) error {
		return fts5.Register(conn)
	})
	if err != nil {
		return nil, err
	}
	if _, err := db.Exec(schemaSQL); err != nil {
		db.Close()
		return nil, err
	}
	return db, nil
}

// openDatabases opens (or reopens) both stores. The unpinned store lives
// in tmpfs when tmpMode is on.
func (s *store) openDatabases(tmpMode bool) error {
	pinned, err := openDB(s.paths.ClipboardPinnedDB(), s.hexKey)
	if err != nil {
		return fmt.Errorf("pinned db: %w", err)
	}
	unpinnedPath := s.paths.ClipboardUnpinnedDB()
	if tmpMode {
		unpinnedPath = s.paths.ClipboardTmpDB()
	}
	unpinned, err := openDB(unpinnedPath, s.hexKey)
	if err != nil {
		pinned.Close()
		return fmt.Errorf("unpinned db: %w", err)
	}
	if s.pinned != nil {
		s.pinned.Close()
	}
	if s.unpinned != nil {
		s.unpinned.Close()
	}
	s.pinned = pinned
	s.unpinned = unpinned
	s.tmpMode = tmpMode
	return nil
}

func (s *store) close() {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.pinned != nil {
		s.pinned.Close()
		s.pinned = nil
	}
	if s.unpinned != nil {
		s.unpinned.Close()
		s.unpinned = nil
	}
}

func (s *store) dbFor(id itemID) *sql.DB {
	if id.pinned {
		return s.pinned
	}
	return s.unpinned
}

// setTmpMode switches the unpinned store location. Activating moves the
// local unpinned history into tmpfs; deactivating discards the tmpfs
// store (it dies on reboot anyway) and unpinned history starts fresh.
func (s *store) setTmpMode(enabled bool) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.tmpMode == enabled || s.unpinned == nil {
		return nil
	}
	if enabled {
		if err := s.moveRowsTo(s.unpinned, s.paths.ClipboardTmpDB()); err != nil {
			return err
		}
	} else {
		os.Remove(s.paths.ClipboardTmpDB())
	}
	return s.openDatabases(enabled)
}

// moveRowsTo copies every row of src into the store at dstPath (existing
// rows win) and empties src.
func (s *store) moveRowsTo(src *sql.DB, dstPath string) error {
	dst, err := openDB(dstPath, s.hexKey)
	if err != nil {
		return err
	}
	defer dst.Close()
	rows, err := src.Query(`SELECT content_hash, mime_type, preview, full_content, is_image, size, pinned, display_index, alias, created_at, updated_at FROM clipboard_items;`)
	if err != nil {
		return err
	}
	defer rows.Close()
	for rows.Next() {
		var r itemRow
		var alias sql.NullString
		var pinnedFlag, displayIndex int
		if err := rows.Scan(&r.hash, &r.mime, &r.preview, &r.content, &r.isImage, &r.size, &pinnedFlag, &displayIndex, &alias, &r.createdAt, &r.updatedAt); err != nil {
			return err
		}
		r.alias = alias.String
		if err := s.upsert(dst, r, pinnedFlag, displayIndex); err != nil {
			return err
		}
	}
	if err := rows.Err(); err != nil {
		return err
	}
	rows.Close()
	_, err = src.Exec(`DELETE FROM clipboard_items;`)
	return err
}

// readTmpfsFlag reads the clipboard.tmpfs key from the QML system config.
func readTmpfsFlag(p *paths.Paths) bool {
	data, err := os.ReadFile(p.Config("system"))
	if err != nil {
		return false
	}
	var doc struct {
		Clipboard struct {
			Tmpfs bool `json:"tmpfs"`
		} `json:"clipboard"`
	}
	if err := json.Unmarshal(data, &doc); err != nil {
		return false
	}
	return doc.Clipboard.Tmpfs
}

// migrateLegacy imports the plaintext clipboard.db (text inline, images as
// files under clipboard-data/) into the encrypted stores, then removes the
// legacy artifacts.
// migrateLegacy imports ONLY pinned items from the plaintext clipboard.db
// (images folded in as blobs) into the encrypted pinned store, then
// removes the legacy artifacts. Unpinned history is discarded by design:
// importing the full history (with its image files) stalled daemon boot.
func (s *store) migrateLegacy() error {
	legacyPath := s.paths.ClipboardDB()
	if _, err := os.Stat(legacyPath); err != nil {
		return nil
	}
	legacy, err := driver.Open(fileURI(legacyPath), func(conn *sqlite3.Conn) error {
		return fts5.Register(conn)
	})
	if err != nil {
		return err
	}
	defer legacy.Close()

	rows, err := legacy.Query(`SELECT mime_type, preview, full_content, is_image, binary_path, content_hash, size, display_index, alias, created_at, updated_at FROM clipboard_items WHERE pinned = 1 ORDER BY id ASC;`)
	if err != nil {
		return err
	}
	defer rows.Close()

	migrated := 0
	for rows.Next() {
		var mime, hash string
		var preview, content []byte
		var isImage, size, displayIndex int
		var binaryPath, alias sql.NullString
		var createdAt, updatedAt sql.NullInt64
		if err := rows.Scan(&mime, &preview, &content, &isImage, &binaryPath, &hash, &size, &displayIndex, &alias, &createdAt, &updatedAt); err != nil {
			return err
		}
		// Images lived as plain files; fold them into the row as a blob.
		if isImage == 1 && binaryPath.String != "" {
			if data, err := os.ReadFile(binaryPath.String); err == nil {
				content = data
				size = len(data)
			}
		}
		if isImage == 1 {
			preview = []byte("[Image]")
		}
		if _, err := s.pinned.Exec(`INSERT INTO clipboard_items (content_hash, mime_type, preview, full_content, is_image, size, pinned, display_index, alias, created_at, updated_at)
VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, ?, ?)
ON CONFLICT(content_hash) DO NOTHING;`,
			hash, mime, preview, content, isImage, size, displayIndex, nullableString(alias.String), createdAt.Int64, updatedAt.Int64); err != nil {
			return err
		}
		migrated++
	}
	if err := rows.Err(); err != nil {
		return err
	}

	legacy.Close()
	os.Remove(legacyPath)
	os.RemoveAll(s.paths.ClipboardDataDir())
	log.Printf("[clipboard] migrated %d pinned legacy items into the encrypted store", migrated)
	return nil
}

// fileURI builds a plain file: URI (no VFS override) for the legacy DB.
func fileURI(path string) string {
	u := url.URL{Scheme: "file", Path: path}
	return u.String()
}

func nullableString(s string) any {
	if s == "" {
		return nil
	}
	return s
}

// --- item operations (all take the store mutex) ---

// listItems returns the merged history: pinned first (by display_index),
// then unpinned. IDs are namespaced by store.
func (s *store) listItems() []map[string]any {
	s.mu.Lock()
	defer s.mu.Unlock()
	items := []map[string]any{}
	collect := func(db *sql.DB, prefix string) {
		if db == nil {
			return
		}
		rows, err := db.Query(`SELECT id, mime_type, preview, is_image, content_hash, size, pinned, display_index, alias, created_at, updated_at FROM clipboard_items ORDER BY display_index ASC, updated_at DESC, id DESC;`)
		if err != nil {
			log.Printf("[clipboard] list: %v", err)
			return
		}
		defer rows.Close()
		for rows.Next() {
			var id int64
			var mime, hash string
			var preview []byte
			var isImage, size, pinnedFlag, displayIndex int
			var alias sql.NullString
			var createdAt, updatedAt sql.NullInt64
			if err := rows.Scan(&id, &mime, &preview, &isImage, &hash, &size, &pinnedFlag, &displayIndex, &alias, &createdAt, &updatedAt); err != nil {
				continue
			}
			var aliasVal any
			if alias.Valid && alias.String != "" {
				aliasVal = alias.String
			}
			items = append(items, map[string]any{
				"id":            fmt.Sprintf("%s:%d", prefix, id),
				"mime_type":     mime,
				"preview":       string(preview),
				"is_image":      isImage,
				"content_hash":  hash,
				"size":          size,
				"pinned":        pinnedFlag,
				"display_index": displayIndex,
				"alias":         aliasVal,
				"created_at":    createdAt.Int64,
				"updated_at":    updatedAt.Int64,
			})
		}
	}
	collect(s.pinned, "p")
	collect(s.unpinned, "u")
	return items
}

// getContent returns the full text content of an item.
func (s *store) getContent(id itemID) (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	db := s.dbFor(id)
	if db == nil {
		return "", errors.New("store closed")
	}
	var content []byte
	err := db.QueryRow(`SELECT full_content FROM clipboard_items WHERE id = ?;`, id.id).Scan(&content)
	if errors.Is(err, sql.ErrNoRows) {
		return "", nil
	}
	return string(content), err
}

// deleteItem removes an item and returns its hash (so the caller can
// clear the live clipboard if it matches).
func (s *store) deleteItem(id itemID) (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	db := s.dbFor(id)
	if db == nil {
		return "", errors.New("store closed")
	}
	var hash string
	_ = db.QueryRow(`SELECT content_hash FROM clipboard_items WHERE id = ?;`, id.id).Scan(&hash)
	if _, err := db.Exec(`DELETE FROM clipboard_items WHERE id = ?;`, id.id); err != nil {
		return "", err
	}
	return hash, nil
}

// clearUnpinned drops the whole unpinned history (pinned items survive).
func (s *store) clearUnpinned() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.unpinned == nil {
		return errors.New("store closed")
	}
	_, err := s.unpinned.Exec(`DELETE FROM clipboard_items;`)
	return err
}

// togglePin moves an item between the stores, placing it at the top of
// its new group (mirrors the legacy display_index behaviour).
func (s *store) togglePin(id itemID) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	src, dst := s.unpinned, s.pinned
	if id.pinned {
		src, dst = s.pinned, s.unpinned
	}
	if src == nil || dst == nil {
		return errors.New("store closed")
	}
	row, err := readRow(src, id.id)
	if err != nil || row == nil {
		return err
	}
	if _, err := src.Exec(`DELETE FROM clipboard_items WHERE id = ?;`, id.id); err != nil {
		return err
	}
	// The same content may already exist in the destination store (it is
	// now two independent DBs); the moved row replaces it.
	if _, err := dst.Exec(`DELETE FROM clipboard_items WHERE content_hash = ?;`, row.hash); err != nil {
		return err
	}
	if err := insertTop(dst, *row, !id.pinned); err != nil {
		return err
	}
	return compact(dst)
}

func readRow(db *sql.DB, id int64) (*itemRow, error) {
	var r itemRow
	var alias sql.NullString
	err := db.QueryRow(`SELECT content_hash, mime_type, preview, full_content, is_image, size, alias, created_at, updated_at FROM clipboard_items WHERE id = ?;`, id).
		Scan(&r.hash, &r.mime, &r.preview, &r.content, &r.isImage, &r.size, &alias, &r.createdAt, &r.updatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	r.alias = alias.String
	return &r, nil
}

func (s *store) upsert(db *sql.DB, r itemRow, pinnedFlag, displayIndex int) error {
	_, err := db.Exec(`INSERT INTO clipboard_items (content_hash, mime_type, preview, full_content, is_image, size, pinned, display_index, alias, created_at, updated_at)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(content_hash) DO NOTHING;`,
		r.hash, r.mime, r.preview, r.content, r.isImage, r.size, pinnedFlag, displayIndex, nullableString(r.alias), r.createdAt, r.updatedAt)
	return err
}

// insertTop places a row at display_index 0 and shifts the group down.
func insertTop(db *sql.DB, r itemRow, pinnedFlag bool) error {
	if _, err := db.Exec(`UPDATE clipboard_items SET display_index = display_index + 1;`); err != nil {
		return err
	}
	flag := 0
	if pinnedFlag {
		flag = 1
	}
	_, err := db.Exec(`INSERT INTO clipboard_items (content_hash, mime_type, preview, full_content, is_image, size, pinned, display_index, alias, created_at, updated_at)
VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?);`,
		r.hash, r.mime, r.preview, r.content, r.isImage, r.size, flag, nullableString(r.alias), r.createdAt, r.updatedAt)
	return err
}

// compact reindexes display_index 0..n-1 keeping the canonical order.
func compact(db *sql.DB) error {
	_, err := db.Exec(`WITH ranked AS (
	SELECT id, ROW_NUMBER() OVER (ORDER BY display_index ASC, updated_at DESC, id DESC) - 1 AS new_idx
	FROM clipboard_items
)
UPDATE clipboard_items SET display_index = (SELECT new_idx FROM ranked WHERE ranked.id = clipboard_items.id);`)
	return err
}

// setAlias updates (or clears) an item alias.
func (s *store) setAlias(id itemID, alias string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	db := s.dbFor(id)
	if db == nil {
		return errors.New("store closed")
	}
	var val any
	if alias != "" {
		val = alias
	}
	_, err := db.Exec(`UPDATE clipboard_items SET alias = ? WHERE id = ?;`, val, id.id)
	return err
}

// reorder moves an item to newIndex within its own group.
func (s *store) reorder(id itemID, newIndex int) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	db := s.dbFor(id)
	if db == nil {
		return errors.New("store closed")
	}
	if newIndex < 0 {
		newIndex = 0
	}
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err := tx.Exec(`UPDATE clipboard_items SET display_index = display_index + 1 WHERE display_index >= ? AND id != ?;`, newIndex, id.id); err != nil {
		return err
	}
	if _, err := tx.Exec(`UPDATE clipboard_items SET display_index = ? WHERE id = ?;`, newIndex, id.id); err != nil {
		return err
	}
	if err := compactTx(tx); err != nil {
		return err
	}
	return tx.Commit()
}

// swap exchanges the display_index of two items (must share a store).
func (s *store) swap(id1, id2 itemID) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if id1.pinned != id2.pinned {
		return errors.New("cannot swap across stores")
	}
	db := s.dbFor(id1)
	if db == nil {
		return errors.New("store closed")
	}
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var i1, i2 sql.NullInt64
	if err := tx.QueryRow(`SELECT display_index FROM clipboard_items WHERE id = ?;`, id1.id).Scan(&i1); err != nil {
		return err
	}
	if err := tx.QueryRow(`SELECT display_index FROM clipboard_items WHERE id = ?;`, id2.id).Scan(&i2); err != nil {
		return err
	}
	if _, err := tx.Exec(`UPDATE clipboard_items SET display_index = ? WHERE id = ?;`, i2.Int64, id1.id); err != nil {
		return err
	}
	if _, err := tx.Exec(`UPDATE clipboard_items SET display_index = ? WHERE id = ?;`, i1.Int64, id2.id); err != nil {
		return err
	}
	if err := compactTx(tx); err != nil {
		return err
	}
	return tx.Commit()
}

func compactTx(tx *sql.Tx) error {
	_, err := tx.Exec(`WITH ranked AS (
	SELECT id, ROW_NUMBER() OVER (ORDER BY display_index ASC, updated_at DESC, id DESC) - 1 AS new_idx
	FROM clipboard_items
)
UPDATE clipboard_items SET display_index = (SELECT new_idx FROM ranked WHERE ranked.id = clipboard_items.id);`)
	return err
}

// insertUnpinned stores new clipboard content in the unpinned history
// (deduplicating by hash, bumping repeats to the top) and prunes the
// history beyond maxUnpinnedItems. Returns whether content was present.
func (s *store) insertUnpinned(mime string, content []byte, isImage bool, size int64) (bool, error) {
	if !isImage && len(content) == 0 {
		return false, nil
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.unpinned == nil {
		return false, errors.New("store closed")
	}
	sum := md5.Sum(content)
	hash := hex.EncodeToString(sum[:])
	preview := makePreview(string(content), isImage)
	now := time.Now().UnixMilli()
	if _, err := s.unpinned.Exec(`INSERT INTO clipboard_items (content_hash, mime_type, preview, full_content, is_image, size, pinned, display_index, created_at, updated_at)
VALUES (?, ?, ?, ?, ?, ?, 0, 0, ?, ?)
ON CONFLICT(content_hash) DO UPDATE SET updated_at = excluded.updated_at, display_index = 0;`,
		hash, mime, preview, content, boolInt(isImage), size, now, now); err != nil {
		return false, err
	}
	if err := compact(s.unpinned); err != nil {
		return true, err
	}
	if _, err := s.unpinned.Exec(`DELETE FROM clipboard_items WHERE id NOT IN (
	SELECT id FROM clipboard_items ORDER BY updated_at DESC, id DESC LIMIT ?
);`, maxUnpinnedItems); err != nil {
		return true, err
	}
	return true, nil
}

func makePreview(content string, isImage bool) string {
	if isImage {
		return "[Image]"
	}
	if len(content) > 100 {
		return content[:97] + "..."
	}
	return content
}

func boolInt(b bool) int {
	if b {
		return 1
	}
	return 0
}

// copyRow returns the mime + raw content of any item (text or image).
func (s *store) copyRow(id itemID) (string, []byte, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	db := s.dbFor(id)
	if db == nil {
		return "", nil, errors.New("store closed")
	}
	var mime string
	var content []byte
	err := db.QueryRow(`SELECT mime_type, full_content FROM clipboard_items WHERE id = ?;`, id.id).Scan(&mime, &content)
	if errors.Is(err, sql.ErrNoRows) {
		return "", nil, fmt.Errorf("item %s not found", id)
	}
	return mime, content, err
}

// imageBlob returns the raw bytes + mime of an image item.
func (s *store) imageBlob(id itemID) ([]byte, string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	db := s.dbFor(id)
	if db == nil {
		return nil, "", errors.New("store closed")
	}
	var blob []byte
	var mime string
	err := db.QueryRow(`SELECT full_content, mime_type FROM clipboard_items WHERE id = ? AND is_image = 1;`, id.id).Scan(&blob, &mime)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, "", fmt.Errorf("no image for item %s", id)
	}
	return blob, mime, err
}
