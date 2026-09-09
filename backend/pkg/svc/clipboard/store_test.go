package clipboard

import (
	"database/sql"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"ambxst/backend/pkg/paths"
)

func testPaths(t *testing.T) *paths.Paths {
	t.Helper()
	base := t.TempDir()
	p := &paths.Paths{
		ConfigDir: filepath.Join(base, "config"),
		DataDir:   filepath.Join(base, "data"),
		StateDir:  filepath.Join(base, "state"),
		CacheDir:  filepath.Join(base, "cache"),
	}
	if err := os.MkdirAll(filepath.Join(p.ConfigDir, "config"), 0o700); err != nil {
		t.Fatal(err)
	}
	for _, dir := range []string{p.DataDir, p.StateDir} {
		if err := os.MkdirAll(dir, 0o700); err != nil {
			t.Fatal(err)
		}
	}
	return p
}

// seedLegacyDB creates a plaintext legacy clipboard.db with two text items
// (one pinned), one image item referencing a file, using the old schema.
func seedLegacyDB(t *testing.T, p *paths.Paths) {
	t.Helper()
	legacy, err := sql.Open("sqlite3", "file:"+p.ClipboardDB())
	if err != nil {
		t.Fatal(err)
	}
	defer legacy.Close()
	ddl := `
CREATE TABLE clipboard_items (
	id INTEGER PRIMARY KEY,
	content_hash TEXT NOT NULL UNIQUE,
	mime_type TEXT NOT NULL,
	preview BLOB,
	full_content BLOB,
	is_image INTEGER DEFAULT 0,
	binary_path TEXT,
	size INTEGER DEFAULT 0,
	pinned INTEGER DEFAULT 0,
	display_index INTEGER DEFAULT 0,
	alias TEXT,
	created_at INTEGER,
	updated_at INTEGER
);`
	if _, err := legacy.Exec(ddl); err != nil {
		t.Fatal(err)
	}
	imgPath := filepath.Join(p.DataDir, "clipboard-data", "img.png")
	if err := os.MkdirAll(filepath.Dir(imgPath), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(imgPath, []byte("PNGDATA"), 0o600); err != nil {
		t.Fatal(err)
	}
	stmts := []string{
		`INSERT INTO clipboard_items (content_hash, mime_type, preview, full_content, is_image, binary_path, size, pinned, display_index, created_at, updated_at) VALUES ('h1', 'text/plain', 'hello', 'hello', 0, '', 5, 1, 0, 1, 1);`,
		`INSERT INTO clipboard_items (content_hash, mime_type, preview, full_content, is_image, binary_path, size, pinned, display_index, created_at, updated_at) VALUES ('h2', 'image/png', '[Image]', NULL, 1, '` + imgPath + `', 7, 1, 1, 2, 2);`,
		`INSERT INTO clipboard_items (content_hash, mime_type, preview, full_content, is_image, binary_path, size, pinned, display_index, created_at, updated_at) VALUES ('h3', 'text/plain', 'world', 'world', 0, '', 5, 0, 0, 3, 3);`,
	}
	for _, q := range stmts {
		if _, err := legacy.Exec(q); err != nil {
			t.Fatal(err)
		}
	}
}

func TestMigrationAndRetention(t *testing.T) {
	p := testPaths(t)
	seedLegacyDB(t, p)

	st, err := newStore(p)
	if err != nil {
		t.Fatal(err)
	}
	defer st.close()

	// Legacy artifacts removed; only pinned items migrated.
	if _, err := os.Stat(p.ClipboardDB()); !os.IsNotExist(err) {
		t.Fatal("legacy db not removed")
	}
	if _, err := os.Stat(p.ClipboardDataDir()); !os.IsNotExist(err) {
		t.Fatal("legacy data dir not removed")
	}

	items := st.listItems()
	if len(items) != 2 {
		t.Fatalf("expected 2 items (pinned only), got %d", len(items))
	}
	// Pinned first; image content folded in as blob.
	if items[0]["id"] != "p:1" {
		t.Fatalf("expected pinned item first, got %v", items[0]["id"])
	}
	blob, _, err := st.imageBlob(itemID{pinned: true, id: 2})
	if err != nil || string(blob) != "PNGDATA" {
		t.Fatalf("pinned image blob not migrated: %v %q", err, blob)
	}

	// Retention: cap unpinned history at maxUnpinnedItems.
	for i := 0; i < 60; i++ {
		content := []byte("item-" + strings.Repeat("x", i))
		if ok, err := st.insertUnpinned("text/plain", content, false, int64(len(content))); err != nil || !ok {
			t.Fatalf("insert %d: ok=%v err=%v", i, ok, err)
		}
	}
	items = st.listItems()
	unpinnedCount := 0
	for _, it := range items {
		if it["id"].(string)[0] == 'u' {
			unpinnedCount++
		}
	}
	if unpinnedCount != maxUnpinnedItems {
		t.Fatalf("expected %d unpinned, got %d", maxUnpinnedItems, unpinnedCount)
	}
}

func TestTogglePinAndTmpMode(t *testing.T) {
	p := testPaths(t)
	st, err := newStore(p)
	if err != nil {
		t.Fatal(err)
	}
	defer st.close()

	if ok, _ := st.insertUnpinned("text/plain", []byte("item1"), false, 5); !ok {
		t.Fatal("insert failed")
	}
	items := st.listItems()
	if len(items) != 1 || items[0]["id"] != "u:1" {
		t.Fatalf("unexpected list: %v", items)
	}

	// Pin it: crosses to the pinned store.
	if err := st.togglePin(itemID{id: 1}); err != nil {
		t.Fatal(err)
	}
	items = st.listItems()
	if len(items) != 1 || items[0]["id"] != "p:1" || items[0]["pinned"] != 1 {
		t.Fatalf("pin failed: %v", items)
	}

	// Copying the same content again recreates it as unpinned; unpinning
	// must not collide with the UNIQUE(content_hash) of the unpinned store.
	if ok, _ := st.insertUnpinned("text/plain", []byte("item1"), false, 5); !ok {
		t.Fatal("re-insert failed")
	}
	if err := st.togglePin(itemID{pinned: true, id: 1}); err != nil {
		t.Fatal(err)
	}
	items = st.listItems()
	if len(items) != 1 || items[0]["id"].(string)[0] != 'u' {
		t.Fatalf("unpin dedup failed: %v", items)
	}

	// Re-pin it so the tmpfs assertions below have a pinned survivor.
	rePinned, _ := parseID(items[0]["id"].(string))
	if err := st.togglePin(rePinned); err != nil {
		t.Fatal(err)
	}

	// tmpfs mode moves unpinned history to the runtime dir.
	if ok, _ := st.insertUnpinned("text/plain", []byte("item2"), false, 5); !ok {
		t.Fatal("insert failed")
	}
	if err := st.setTmpMode(true); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(p.ClipboardTmpDB()); err != nil {
		t.Fatalf("tmp db missing: %v", err)
	}
	items = st.listItems()
	if len(items) != 2 {
		t.Fatalf("expected 2 items after tmp switch, got %d", len(items))
	}

	// Deactivating discards the tmp store; pinned survives.
	if err := st.setTmpMode(false); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(p.ClipboardTmpDB()); !os.IsNotExist(err) {
		t.Fatal("tmp db not removed on deactivate")
	}
	items = st.listItems()
	if len(items) != 1 || items[0]["id"].(string)[0] != 'p' {
		t.Fatalf("expected only pinned after deactivate, got %v", items)
	}
}
