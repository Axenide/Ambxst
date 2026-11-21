package clipboard

import (
	"encoding/json"
	"strings"
	"testing"
)

// The image data-URL cache is keyed by item id and must never outlive the
// item: delete and clear remove rows from the store, and pinning moves a
// row to a new id, so stale entries would pin the full base64 blob in
// daemon memory forever.

// insertImage seeds one unpinned image item and returns its "u:N" id.
func insertImage(t *testing.T, s *Service, content []byte) string {
	t.Helper()
	st, err := s.getStore()
	if err != nil {
		t.Fatalf("getStore: %v", err)
	}
	if _, err := st.insertUnpinned("image/png", []string{"image/png"}, content, true, int64(len(content))); err != nil {
		t.Fatalf("insertUnpinned: %v", err)
	}
	for _, item := range st.listItems() {
		if id, _ := item["id"].(string); strings.HasPrefix(id, "u:") {
			return id
		}
	}
	t.Fatal("no unpinned item found after insert")
	return ""
}

// cached reports whether the cache currently holds an entry for the id.
func cached(t *testing.T, s *Service, id string) bool {
	t.Helper()
	s.cacheMu.Lock()
	defer s.cacheMu.Unlock()
	_, ok := s.imageCache[id]
	return ok
}

func callDataURL(t *testing.T, s *Service, id string) string {
	t.Helper()
	out, err := s.dataURL(json.RawMessage(`{"id":"` + id + `"}`))
	if err != nil {
		t.Fatalf("dataURL: %v", err)
	}
	m, ok := out.(map[string]any)
	if !ok {
		t.Fatalf("unexpected dataURL result: %v", out)
	}
	if e, hasErr := m["error"]; hasErr {
		t.Fatalf("dataURL error: %v", e)
	}
	url, _ := m["data_url"].(string)
	if !strings.HasPrefix(url, "data:image/png;base64,") {
		t.Fatalf("unexpected data url: %q", url)
	}
	return url
}

func TestDeleteInvalidatesImageCacheEntry(t *testing.T) {
	s := NewService(testPaths(t))
	id := insertImage(t, s, []byte{0x89, 'P', 'N', 'G', 1})
	callDataURL(t, s, id)
	if !cached(t, s, id) {
		t.Fatal("expected the data url to be cached")
	}

	out, err := s.delete(json.RawMessage(`{"id":"` + id + `"}`))
	if err != nil {
		t.Fatalf("delete: %v", err)
	}
	if m, ok := out.(map[string]any); ok {
		if e, hasErr := m["error"]; hasErr {
			t.Fatalf("delete error: %v", e)
		}
	}
	if cached(t, s, id) {
		t.Fatal("delete did not drop the image cache entry for the removed item")
	}
}

func TestClearDropsUnpinnedImageCacheEntries(t *testing.T) {
	s := NewService(testPaths(t))
	id1 := insertImage(t, s, []byte{0x89, 'P', 'N', 'G', 1})
	id2 := insertImage(t, s, []byte{0x89, 'P', 'N', 'G', 2})
	callDataURL(t, s, id1)
	callDataURL(t, s, id2)

	if _, err := s.clear(nil); err != nil {
		t.Fatalf("clear: %v", err)
	}
	if cached(t, s, id1) || cached(t, s, id2) {
		t.Fatal("clear did not drop image cache entries for removed unpinned items")
	}
}

func TestPinMovesDropOldImageCacheEntry(t *testing.T) {
	s := NewService(testPaths(t))
	oldID := insertImage(t, s, []byte{0x89, 'P', 'N', 'G', 3})
	callDataURL(t, s, oldID)

	if _, err := s.togglePin(json.RawMessage(`{"id":"` + oldID + `"}`)); err != nil {
		t.Fatalf("togglePin: %v", err)
	}
	if cached(t, s, oldID) {
		t.Fatal("togglePin did not drop the cache entry for the old id")
	}

	// The pinned item keeps working under its new id, and survives clear.
	st, err := s.getStore()
	if err != nil {
		t.Fatalf("getStore: %v", err)
	}
	var pinnedID string
	for _, item := range st.listItems() {
		if id, _ := item["id"].(string); strings.HasPrefix(id, "p:") {
			pinnedID = id
		}
	}
	if pinnedID == "" {
		t.Fatal("no pinned item after togglePin")
	}
	callDataURL(t, s, pinnedID)
	if _, err := s.clear(nil); err != nil {
		t.Fatalf("clear: %v", err)
	}
	if !cached(t, s, pinnedID) {
		t.Fatal("clear dropped the cache entry for a pinned item that still exists")
	}
}
