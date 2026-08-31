package clipboard

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"ambxst/backend/pkg/ipc"
	"ambxst/backend/pkg/paths"
)

// Service owns the clipboard history DB (sqlite3 CLI, byte-compatible with
// the previous QML/script flow) and watches the Wayland clipboard.
type Service struct {
	paths  *paths.Paths
	watch  *watchProc
	dbLock chan struct{}
	imageCache map[string]string
}

func NewService(p *paths.Paths) *Service {
	return &Service{
		paths:      p,
		dbLock:     make(chan struct{}, 1),
		imageCache: map[string]string{},
	}
}

func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "clipboard",
		Methods: map[string]ipc.HandlerFunc{
			"list":         s.list,
			"getContent":   s.getContent,
			"delete":       s.delete,
			"clear":        s.clear,
			"togglePin":    s.togglePin,
			"setAlias":     s.setAlias,
			"reorder":      s.reorder,
			"swap":         s.swap,
			"copy":         s.copy,
			"emojiType":    s.emojiType,
			"dataUrl":      s.dataURL,
			"clearClipboard": s.clearClipboard,
		},
		Subscribe: s.subscribe,
	})
}

func (s *Service) Close() {
	if s.watch != nil {
		s.watch.stop()
	}
}

func (s *Service) subscribe(sub *ipc.Subscriber) {
	// Start the watcher only for the first subscriber; the watcher
	// emits clipboard.refresh events on every change.
	s.ensureWatcher(sub)
}

// sqlite runs the sqlite3 CLI with the given SQL, returning its stdout.
func (s *Service) sqlite(sql string) (string, error) {
	args := []string{"-cmd", ".timeout 5000", "-cmd", ".mode json"}
	cmd := exec.Command("sqlite3", append(args, s.paths.ClipboardDB(), sql)...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("sqlite: %v: %s", err, out)
	}
	return string(out), nil
}

func (s *Service) lock() {
	s.dbLock <- struct{}{}
}

func (s *Service) unlock() {
	<-s.dbLock
}

// --- methods ---

// list returns the last 100 items (newest first), preserving the SQL shape.
func (s *Service) list(params json.RawMessage) (any, error) {
	out, err := s.sqlite("SELECT id, mime_type, preview, is_image, binary_path, content_hash, size, created_at, pinned, alias, display_index FROM clipboard_items ORDER BY pinned DESC, display_index ASC, updated_at DESC, id DESC LIMIT 100;")
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	out = strings.TrimSpace(out)
	if out == "" {
		return []any{}, nil
	}
	var rows []map[string]any
	if err := json.Unmarshal([]byte(out), &rows); err != nil {
		rows = nil
	}
	items := make([]any, 0, len(rows))
	for _, r := range rows {
		items = append(items, map[string]any{
			"id":            r["id"],
			"mime_type":     r["mime_type"],
			"preview":       r["preview"],
			"is_image":      r["is_image"],
			"binary_path":   r["binary_path"],
			"content_hash":  r["content_hash"],
			"size":          r["size"],
			"created_at":    r["created_at"],
			"pinned":        r["pinned"],
			"alias":         r["alias"],
			"display_index": r["display_index"],
		})
	}
	return items, nil
}

func (s *Service) getContent(params json.RawMessage) (any, error) {
	var p struct {
		ID int64 `json:"id"`
	}
	json.Unmarshal(params, &p)
	out, err := s.sqlite(fmt.Sprintf("SELECT full_content FROM clipboard_items WHERE id = %d;", p.ID))
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return map[string]any{"id": p.ID, "content": strings.TrimSpace(strings.Trim(out, "\n"))}, nil
}

func (s *Service) delete(params json.RawMessage) (any, error) {
	var p struct {
		ID int64 `json:"id"`
	}
	json.Unmarshal(params, &p)
	s.lock()
	defer s.unlock()

	out, err := s.sqlite(fmt.Sprintf("SELECT content_hash FROM clipboard_items WHERE id = %d;", p.ID))
	hash := strings.TrimSpace(out)
	if _, err := s.sqlite(fmt.Sprintf("DELETE FROM clipboard_items WHERE id = %d;", p.ID)); err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	if hash == "" && err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	_ = hash
	return map[string]any{"hash": hash}, nil
}

func (s *Service) clear(params json.RawMessage) (any, error) {
	s.lock()
	defer s.unlock()
	if out, err := s.sqlite("DELETE FROM clipboard_items WHERE pinned = 0;"); err != nil {
		return map[string]any{"error": err.Error()}, nil
	} else {
		_ = out
	}
	// clear the live clipboard
	exec.Command("wl-copy", "--clear").Run()
	// remove orphaned binary files
	dataDir := s.paths.ClipboardDataDir()
	entries, err := os.ReadDir(dataDir)
	if err == nil {
		for _, e := range entries {
			p := filepath.Join(dataDir, e.Name())
			cnt, _ := s.sqlite(fmt.Sprintf("SELECT COUNT(*) FROM clipboard_items WHERE binary_path = '%s';", p))
			if strings.TrimSpace(cnt) == "0" {
				os.Remove(p)
			}
		}
	}
	return map[string]any{"ok": true}, nil
}

func (s *Service) togglePin(params json.RawMessage) (any, error) {
	var p struct {
		ID int64 `json:"id"`
	}
	json.Unmarshal(params, &p)
	sql := fmt.Sprintf(`
BEGIN;
UPDATE clipboard_items SET pinned = 1 - pinned WHERE id = %d;
UPDATE clipboard_items SET display_index = CASE WHEN id = %d THEN 0 ELSE display_index + 1 END WHERE pinned = (SELECT pinned FROM clipboard_items WHERE id = %d);
WITH reindexed_pinned AS (SELECT id, ROW_NUMBER() OVER (ORDER BY display_index ASC, updated_at DESC, id DESC) - 1 AS new_idx FROM clipboard_items WHERE pinned = 1)
UPDATE clipboard_items SET display_index = (SELECT new_idx FROM reindexed_pinned WHERE reindexed_pinned.id = clipboard_items.id) WHERE pinned = 1;
WITH reindexed_unpinned AS (SELECT id, ROW_NUMBER() OVER (ORDER BY display_index ASC, updated_at DESC, id DESC) - 1 AS new_idx FROM clipboard_items WHERE pinned = 0)
UPDATE clipboard_items SET display_index = (SELECT new_idx FROM reindexed_unpinned WHERE reindexed_unpinned.id = clipboard_items.id) WHERE pinned = 0;
COMMIT;`, p.ID, p.ID, p.ID)
	_, err := s.sqlite(sql)
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return map[string]any{"ok": true}, nil
}

func (s *Service) setAlias(params json.RawMessage) (any, error) {
	var p struct {
		ID    int64  `json:"id"`
		Alias string `json:"alias"`
	}
	json.Unmarshal(params, &p)
	p.Alias = strings.ReplaceAll(p.Alias, "'", "''")
	val := "NULL"
	if p.Alias != "" {
		val = "'" + p.Alias + "'"
	}
	_, err := s.sqlite(fmt.Sprintf("UPDATE clipboard_items SET alias = %s WHERE id = %d;", val, p.ID))
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return map[string]any{"ok": true}, nil
}

func (s *Service) reorder(params json.RawMessage) (any, error) {
	var p struct {
		ID       int64 `json:"id"`
		NewIndex int   `json:"new_index"`
	}
	json.Unmarshal(params, &p)
	// determine pin group of item
	out, err := s.sqlite(fmt.Sprintf("SELECT pinned FROM clipboard_items WHERE id = %d;", p.ID))
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	pinned := strings.TrimSpace(out)
	sql := fmt.Sprintf(`
BEGIN;
UPDATE clipboard_items SET display_index = display_index + 1 WHERE pinned = %s AND display_index >= %d AND id != %d;
UPDATE clipboard_items SET display_index = %d WHERE id = %d;
WITH reindexed AS (SELECT id, ROW_NUMBER() OVER (ORDER BY display_index ASC, updated_at DESC, id DESC) - 1 AS new_idx FROM clipboard_items WHERE pinned = %s)
UPDATE clipboard_items SET display_index = (SELECT new_idx FROM reindexed WHERE reindexed.id = clipboard_items.id) WHERE pinned = %s;
COMMIT;`, pinned, p.NewIndex, p.ID, p.NewIndex, p.ID, pinned, pinned)
	_, err = s.sqlite(sql)
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return map[string]any{"ok": true}, nil
}

func (s *Service) swap(params json.RawMessage) (any, error) {
	var p struct {
		ID1 int64 `json:"id1"`
		ID2 int64 `json:"id2"`
	}
	json.Unmarshal(params, &p)
	sql := fmt.Sprintf(`
BEGIN;
WITH reindexed AS (SELECT id, ROW_NUMBER() OVER (ORDER BY display_index ASC, updated_at DESC, id DESC) - 1 AS new_idx FROM clipboard_items WHERE pinned = (SELECT pinned FROM clipboard_items WHERE id = %d))
UPDATE clipboard_items SET display_index = (SELECT new_idx FROM reindexed WHERE reindexed.id = clipboard_items.id) WHERE pinned = (SELECT pinned FROM clipboard_items WHERE id = %d);
CREATE TEMP TABLE tmp_swap (idx INTEGER);
INSERT INTO tmp_swap SELECT display_index FROM clipboard_items WHERE id = %d;
UPDATE clipboard_items SET display_index = (SELECT display_index FROM clipboard_items WHERE id = %d) WHERE id = %d;
UPDATE clipboard_items SET display_index = (SELECT idx FROM tmp_swap) WHERE id = %d;
DROP TABLE tmp_swap;
COMMIT;`, p.ID1, p.ID1, p.ID1, p.ID2, p.ID1, p.ID2)
	_, err := s.sqlite(sql)
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return map[string]any{"ok": true}, nil
}

// copy copies item content (text or image) back to the clipboard.
func (s *Service) copy(params json.RawMessage) (any, error) {
	var p struct {
		ID   int64  `json:"id"`
		Mime string `json:"mime"`
	}
	json.Unmarshal(params, &p)
	out, err := s.sqlite(fmt.Sprintf("SELECT mime_type, binary_path, full_content FROM clipboard_items WHERE id = %d;", p.ID))
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	rows := parseRows(out)
	if len(rows) == 0 {
		return map[string]any{"error": "item not found"}, nil
	}
	mime := rows[0].MimeType
	binPath := rows[0].BinaryPath
	fullContent := rows[0].FullContent
	if p.Mime != "" {
		mime = p.Mime
	}
	if binPath != "" {
		exec.Command("sh", "-c", "cat '"+binPath+"' | wl-copy --type '"+mime+"'").Run()
	} else {
		exec.Command("wl-copy", "--type", mime, fullContent).Run()
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
	// wl-copy with echo -n; then wtype ctrl+v
	exec.Command("sh", "-c", `printf '%s' `+shellQuote(emoji)+` | wl-copy`).Run()
	go func() {
		exec.Command("bash", "-c", "sleep 0.25; wtype -M ctrl -P v -p v -m ctrl").Run()
	}()
	return map[string]any{"ok": true}, nil
}

// dataURL returns a base64 data URL for an image item (cached).
func (s *Service) dataURL(params json.RawMessage) (any, error) {
	var p struct {
		ID   int64  `json:"id"`
		Mime string `json:"mime"`
	}
	json.Unmarshal(params, &p)
	if v, ok := s.imageCache[fmt.Sprint(p.ID)]; ok {
		return map[string]any{"id": p.ID, "data_url": v}, nil
	}
	out, err := s.sqlite(fmt.Sprintf("SELECT binary_path FROM clipboard_items WHERE id = %d;", p.ID))
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	path := strings.TrimSpace(out)
	if path == "" {
		return map[string]any{"error": "no binary for item"}, nil
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	if p.Mime == "" {
		p.Mime = "image/png"
	}
	url := "data:" + p.Mime + ";base64," + base64.StdEncoding.EncodeToString(data)
	s.imageCache[fmt.Sprint(p.ID)] = url
	return map[string]any{"id": p.ID, "data_url": url}, nil
}

// clearClipboard empties the live clipboard (used after delete matching).
func (s *Service) clearClipboard(params json.RawMessage) (any, error) {
	exec.Command("wl-copy", "--clear").Run()
	return map[string]any{"ok": true}, nil
}

// rowFull is used only internally by copy.
type rowFull struct {
	MimeType    string
	BinaryPath  string
	FullContent string
}

func parseRows(out string) []rowFull {
	// sqlite JSON mode with unknown columns yields objects; parse generically.
	trimmed := strings.TrimSpace(out)
	if trimmed == "" || !strings.HasPrefix(trimmed, "[") {
		return nil
	}
	var raw []map[string]any
	if err := json.Unmarshal([]byte(trimmed), &raw); err != nil {
		return nil
	}
	rows := make([]rowFull, 0, len(raw))
	for _, r := range raw {
		rows = append(rows, rowFull{
			MimeType:    fmt.Sprint(r["mime_type"]),
			BinaryPath:  fmt.Sprint(r["binary_path"]),
			FullContent: fmt.Sprint(r["full_content"]),
		})
	}
	return rows
}

func shellQuote(s string) string {
	return "'" + strings.ReplaceAll(s, "'", "'\\''") + "'"
}
