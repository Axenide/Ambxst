// Package states serializes all read-modify-write access to states.json.
// Multiple services (config, caffeine, gamemode) touch the same document;
// without a shared lock their RMW cycles interleave and clobber each
// other's keys, which showed up as flaky caffeine/gamemode restore.
package states

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sync"
)

var mu sync.Mutex

// Read returns the whole states document.
func Read(path string) map[string]any {
	mu.Lock()
	defer mu.Unlock()
	return readLocked(path)
}

func readLocked(path string) map[string]any {
	doc := map[string]any{}
	if data, err := os.ReadFile(path); err == nil {
		_ = json.Unmarshal(data, &doc)
	}
	return doc
}

// SetKey performs a locked read-modify-write of a single key.
func SetKey(path, key string, val any) error {
	mu.Lock()
	defer mu.Unlock()
	doc := readLocked(path)
	doc[key] = val
	return writeLocked(path, doc)
}

// Merge merges the top-level keys of data into the document on disk.
func Merge(path string, data map[string]any) error {
	mu.Lock()
	defer mu.Unlock()
	doc := readLocked(path)
	for k, v := range data {
		doc[k] = v
	}
	return writeLocked(path, doc)
}

func writeLocked(path string, doc map[string]any) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	out, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, out, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}
