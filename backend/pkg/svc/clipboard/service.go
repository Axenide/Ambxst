package clipboard

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"

	"ambxst/backend/pkg/ipc"
	"ambxst/backend/pkg/paths"
)

// Service owns the clipboard history (two encrypted SQLite stores: pinned
// + unpinned, capped history, images as blobs) and watches the Wayland
// clipboard. All state lives behind the store; this type only adapts IPC.
type Service struct {
	paths      *paths.Paths
	watch      *watchProc
	initMu     sync.Mutex
	store      *store
	initErr    error
	cacheMu    sync.Mutex
	imageCache map[string]string
}

// NewService keeps daemon boot cheap: the encrypted stores (and the
// legacy migration) open lazily on first clipboard use.
func NewService(p *paths.Paths) *Service {
	// Stale materialized images from a previous session are junk.
	os.RemoveAll(p.ClipboardImageCacheDir())
	return &Service{
		paths:      p,
		imageCache: map[string]string{},
	}
}

// getStore lazily creates the store on first use.
func (s *Service) getStore() (*store, error) {
	s.initMu.Lock()
	defer s.initMu.Unlock()
	if s.store != nil {
		return s.store, nil
	}
	if s.initErr != nil {
		return nil, s.initErr
	}
	st, err := newStore(s.paths)
	if err != nil {
		s.initErr = err
		log.Printf("[clipboard] store init: %v", err)
		return nil, err
	}
	s.store = st
	return st, nil
}

func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "clipboard",
		Methods: map[string]ipc.HandlerFunc{
			"list":           s.list,
			"getContent":     s.getContent,
			"delete":         s.delete,
			"clear":          s.clear,
			"togglePin":      s.togglePin,
			"setAlias":       s.setAlias,
			"reorder":        s.reorder,
			"swap":           s.swap,
			"copy":           s.copy,
			"emojiType":      s.emojiType,
			"dataUrl":        s.dataURL,
			"imagePath":      s.imagePath,
			"clearClipboard": s.clearClipboard,
			"setTmpMode":     s.setTmpMode,
			"check":          s.check,
		},
		Subscribe: s.subscribe,
	})
}

func (s *Service) Close() {
	if s.watch != nil {
		s.watch.stop()
	}
	s.initMu.Lock()
	defer s.initMu.Unlock()
	if s.store != nil {
		s.store.close()
	}
}

func (s *Service) subscribe(sub *ipc.Subscriber) {
	// Start the watcher only for the first subscriber; the watcher
	// emits clipboard.refresh events on every change.
	s.ensureWatcher(sub)
}

// --- IPC handlers ---

func (s *Service) list(_ json.RawMessage) (any, error) {
	st, err := s.getStore()
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return st.listItems(), nil
}

func (s *Service) getContent(params json.RawMessage) (any, error) {
	var p struct {
		ID string `json:"id"`
	}
	json.Unmarshal(params, &p)
	id, ok := parseID(p.ID)
	if !ok {
		return map[string]any{"error": "invalid id"}, nil
	}
	st, err := s.getStore()
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	content, err := st.getContent(id)
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return map[string]any{"id": p.ID, "content": content}, nil
}

func (s *Service) delete(params json.RawMessage) (any, error) {
	var p struct {
		ID string `json:"id"`
	}
	json.Unmarshal(params, &p)
	id, ok := parseID(p.ID)
	if !ok {
		return map[string]any{"error": "invalid id"}, nil
	}
	st, err := s.getStore()
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	hash, err := st.deleteItem(id)
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return map[string]any{"hash": hash}, nil
}

func (s *Service) clear(_ json.RawMessage) (any, error) {
	st, err := s.getStore()
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	if err := st.clearUnpinned(); err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	exec.Command("wl-copy", "--clear").Run()
	return map[string]any{"ok": true}, nil
}

func (s *Service) togglePin(params json.RawMessage) (any, error) {
	var p struct {
		ID string `json:"id"`
	}
	json.Unmarshal(params, &p)
	id, ok := parseID(p.ID)
	if !ok {
		return map[string]any{"error": "invalid id"}, nil
	}
	st, err := s.getStore()
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	if err := st.togglePin(id); err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return map[string]any{"ok": true}, nil
}

func (s *Service) setAlias(params json.RawMessage) (any, error) {
	var p struct {
		ID    string `json:"id"`
		Alias string `json:"alias"`
	}
	json.Unmarshal(params, &p)
	id, ok := parseID(p.ID)
	if !ok {
		return map[string]any{"error": "invalid id"}, nil
	}
	st, err := s.getStore()
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	if err := st.setAlias(id, p.Alias); err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return map[string]any{"ok": true}, nil
}

func (s *Service) reorder(params json.RawMessage) (any, error) {
	var p struct {
		ID       string `json:"id"`
		NewIndex int    `json:"new_index"`
	}
	json.Unmarshal(params, &p)
	id, ok := parseID(p.ID)
	if !ok {
		return map[string]any{"error": "invalid id"}, nil
	}
	st, err := s.getStore()
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	if err := st.reorder(id, p.NewIndex); err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return map[string]any{"ok": true}, nil
}

func (s *Service) swap(params json.RawMessage) (any, error) {
	var p struct {
		ID1 string `json:"id1"`
		ID2 string `json:"id2"`
	}
	json.Unmarshal(params, &p)
	id1, ok1 := parseID(p.ID1)
	id2, ok2 := parseID(p.ID2)
	if !ok1 || !ok2 {
		return map[string]any{"error": "invalid id"}, nil
	}
	st, err := s.getStore()
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	if err := st.swap(id1, id2); err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return map[string]any{"ok": true}, nil
}

// copy puts an item's content back on the clipboard (text or image blob).
func (s *Service) copy(params json.RawMessage) (any, error) {
	var p struct {
		ID   string `json:"id"`
		Mime string `json:"mime"`
	}
	json.Unmarshal(params, &p)
	id, ok := parseID(p.ID)
	if !ok {
		return map[string]any{"error": "invalid id"}, nil
	}
	st, err := s.getStore()
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	mime, content, err := st.copyRow(id)
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	if p.Mime != "" {
		mime = p.Mime
	}
	cmd := exec.Command("wl-copy", "--type", mime)
	cmd.Stdin = bytes.NewReader(content)
	if err := cmd.Run(); err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return map[string]any{"ok": true}, nil
}

// emojiType copies an emoji and types it via wtype.
func (s *Service) emojiType(params json.RawMessage) (any, error) {
	var p struct {
		Emoji string `json:"emoji"`
	}
	json.Unmarshal(params, &p)
	emoji := p.Emoji
	if emoji == "" {
		return map[string]any{"error": "empty emoji"}, nil
	}
	cmd := exec.Command("wl-copy", "--type", "text/plain;charset=utf-8")
	cmd.Stdin = strings.NewReader(emoji)
	if err := cmd.Run(); err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	go func() {
		exec.Command("bash", "-c", "sleep 0.25; wtype -M ctrl -P v -p v -m ctrl").Run()
	}()
	return map[string]any{"ok": true}, nil
}

// dataURL returns a base64 data URL for an image item (cached).
func (s *Service) dataURL(params json.RawMessage) (any, error) {
	var p struct {
		ID   string `json:"id"`
		Mime string `json:"mime"`
	}
	json.Unmarshal(params, &p)
	s.cacheMu.Lock()
	defer s.cacheMu.Unlock()
	if v, ok := s.imageCache[p.ID]; ok {
		return map[string]any{"id": p.ID, "data_url": v}, nil
	}
	id, ok := parseID(p.ID)
	if !ok {
		return map[string]any{"error": "invalid id"}, nil
	}
	st, err := s.getStore()
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	blob, mime, err := st.imageBlob(id)
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	if p.Mime != "" {
		mime = p.Mime
	}
	if mime == "" {
		mime = "image/png"
	}
	url := "data:" + mime + ";base64," + base64.StdEncoding.EncodeToString(blob)
	s.imageCache[p.ID] = url
	return map[string]any{"id": p.ID, "data_url": url}, nil
}

// imagePath materializes an image blob to a tmpfs file so QML can use it
// as a file URI (drag-and-drop, external open).
func (s *Service) imagePath(params json.RawMessage) (any, error) {
	var p struct {
		ID string `json:"id"`
	}
	json.Unmarshal(params, &p)
	id, ok := parseID(p.ID)
	if !ok {
		return map[string]any{"error": "invalid id"}, nil
	}
	st, err := s.getStore()
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	blob, mime, err := st.imageBlob(id)
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	ext := "img"
	switch mime {
	case "image/png":
		ext = "png"
	case "image/jpeg":
		ext = "jpg"
	case "image/gif":
		ext = "gif"
	case "image/webp":
		ext = "webp"
	case "image/bmp":
		ext = "bmp"
	case "image/svg+xml":
		ext = "svg"
	}
	dir := s.paths.ClipboardImageCacheDir()
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	path := filepath.Join(dir, fmt.Sprintf("%s.%s", strings.ReplaceAll(p.ID, ":", ""), ext))
	if err := os.WriteFile(path, blob, 0o600); err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return map[string]any{"id": p.ID, "path": path}, nil
}

func (s *Service) clearClipboard(_ json.RawMessage) (any, error) {
	exec.Command("wl-copy", "--clear").Run()
	return map[string]any{"ok": true}, nil
}

// check runs a manual clipboard capture pass (the watcher normally does
// this on every change; QML calls it after programmatic copies).
func (s *Service) check(_ json.RawMessage) (any, error) {
	s.checkAndInsert()
	return map[string]any{"ok": true}, nil
}

// setTmpMode switches where the unpinned history lives (local share vs
// tmpfs). QML owns the persisted flag; the daemon re-reads it on boot.
func (s *Service) setTmpMode(params json.RawMessage) (any, error) {
	var p struct {
		Enabled bool `json:"enabled"`
	}
	json.Unmarshal(params, &p)
	st, err := s.getStore()
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	if err := st.setTmpMode(p.Enabled); err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	log.Printf("[clipboard] tmpfs mode: %v", p.Enabled)
	return map[string]any{"ok": true}, nil
}
