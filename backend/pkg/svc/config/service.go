package config

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"

	"ambxst/backend/pkg/ipc"
	"ambxst/backend/pkg/paths"
)

// Service becomes the single owner of config/state file writes.
// QML keeps FileView for reads; every write goes through here so the
// daemon can serialize access, merge against defaults and write atomically.
type Service struct {
	paths *paths.Paths
	mu    sync.Mutex
}

func NewService(p *paths.Paths) *Service {
	return &Service{paths: p}
}

func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "config",
		Methods: map[string]ipc.HandlerFunc{
			"write":    s.write,
			"patch":    s.patch,
			"read":     s.read,
			"stateGet": s.stateGet,
			"stateSet": s.stateSet,
			"statesGet": s.statesGet,
			"statesSet": s.statesSet,
		},
	})
}

// MigrateStates normalizes states.json: renames legacy keys and prunes
// obsolete ones. Idempotent: safe to call on every boot.
//
//	nightLight (legacy bool) → nightlight.active (only if nightlight missing)
//	animStyleSpeeds         → removed (no longer read)
func (s *Service) MigrateStates() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	path := s.paths.StatesFile()
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	doc := map[string]any{}
	if err := json.Unmarshal(data, &doc); err != nil {
		return err
	}
	changed := false

	// nightLight → nightlight (only when new key is missing).
	if _, hasNew := doc["nightlight"]; !hasNew {
		if v, ok := doc["nightLight"].(bool); ok {
			doc["nightlight"] = map[string]any{"active": v, "temp": 4500}
			changed = true
		}
	}
	if _, ok := doc["nightLight"]; ok {
		delete(doc, "nightLight")
		changed = true
	}

	// Prune keys nobody reads anymore.
	for _, k := range []string{"animStyleSpeeds"} {
		if _, ok := doc[k]; ok {
			delete(doc, k)
			changed = true
		}
	}

	if !changed {
		return nil
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

// domains lists every config domain Config.qml manages.
var domains = []string{
	"theme", "bar", "workspaces", "overview", "notch", "compositor",
	"performance", "weather", "desktop", "lockscreen", "prefix", "system",
	"dock", "ai", "general", "pinnedapps", "binds",
}

func isDomain(d string) bool {
	for _, v := range domains {
		if v == d {
			return true
		}
	}
	return false
}

func (s *Service) fileFor(domain string) string {
	switch domain {
	case "binds":
		return s.paths.KeybindsFile()
	case "pinnedapps":
		return s.paths.PinnedAppsFile()
	default:
		return s.paths.Config(domain)
	}
}

// write replaces a config domain file atomically (temp + rename).
func (s *Service) write(params json.RawMessage) (any, error) {
	var p struct {
		Domain string          `json:"domain"`
		Data   json.RawMessage `json:"data"`
	}
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}
	if !isDomain(p.Domain) {
		return nil, fmt.Errorf("unknown config domain: %s", p.Domain)
	}
	if len(p.Data) == 0 {
		return nil, fmt.Errorf("empty data for %s", p.Domain)
	}
	// Keep the payload structurally valid.
	if !json.Valid(p.Data) {
		return nil, fmt.Errorf("invalid json for %s", p.Domain)
	}
	path := s.fileFor(p.Domain)
	s.mu.Lock()
	defer s.mu.Unlock()
	if err := atomicWrite(path, p.Data); err != nil {
		return nil, err
	}
	return map[string]any{"ok": true, "domain": p.Domain}, nil
}

// read returns the current file content of a domain.
func (s *Service) read(params json.RawMessage) (any, error) {
	var p struct {
		Domain string `json:"domain"`
	}
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}
	if !isDomain(p.Domain) {
		return nil, fmt.Errorf("unknown config domain: %s", p.Domain)
	}
	data, err := os.ReadFile(s.fileFor(p.Domain))
	if err != nil {
		return nil, err
	}
	var v any
	if err := json.Unmarshal(data, &v); err != nil {
		return nil, err
	}
	return v, nil
}

// patch deep-merges a single key path into a domain file (read-modify-write
// under the daemon lock — fixes the state.json clobbering problem too).
func (s *Service) patch(params json.RawMessage) (any, error) {
	var p struct {
		Domain  string         `json:"domain"`
		KeyPath []string       `json:"key_path"`
		Value   json.RawMessage `json:"value"`
	}
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}
	if !isDomain(p.Domain) || len(p.KeyPath) == 0 {
		return nil, fmt.Errorf("invalid patch target")
	}
	path := s.fileFor(p.Domain)
	s.mu.Lock()
	defer s.mu.Unlock()

	doc := map[string]any{}
	if data, err := os.ReadFile(path); err == nil {
		json.Unmarshal(data, &doc)
	}
	var val any
	if err := json.Unmarshal(p.Value, &val); err != nil {
		return nil, err
	}
	setPath(doc, p.KeyPath, val)
	out, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		return nil, err
	}
	if err := atomicWrite(path, out); err != nil {
		return nil, err
	}
	return map[string]any{"ok": true}, nil
}

// stateGet returns a single state key (states.json).
func (s *Service) stateGet(params json.RawMessage) (any, error) {
	var p struct {
		Key string `json:"key"`
	}
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	doc := loadJSON(s.paths.StatesFile())
	return map[string]any{"key": p.Key, "value": doc[p.Key]}, nil
}

// stateSet writes a single state key (locked RMW; fixes GameMode clobber).
func (s *Service) stateSet(params json.RawMessage) (any, error) {
	var p struct {
		Key   string          `json:"key"`
		Value json.RawMessage `json:"value"`
	}
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	doc := loadJSON(s.paths.StatesFile())
	var val any
	if err := json.Unmarshal(p.Value, &val); err != nil {
		val = nil
	}
	doc[p.Key] = val
	out, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		return nil, err
	}
	if err := atomicWrite(s.paths.StatesFile(), out); err != nil {
		return nil, err
	}
	return map[string]any{"ok": true}, nil
}

// statesGet returns the whole states document.
func (s *Service) statesGet(params json.RawMessage) (any, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return loadJSON(s.paths.StatesFile()), nil
}

// statesSet replaces the whole states document (merge-update safe).
func (s *Service) statesSet(params json.RawMessage) (any, error) {
	var p struct {
		Data json.RawMessage `json:"data"`
	}
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}
	if !json.Valid(p.Data) {
		return nil, fmt.Errorf("invalid states json")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	return nil, atomicWrite(s.paths.StatesFile(), p.Data)
}

// --- helpers ---

func loadJSON(path string) map[string]any {
	doc := map[string]any{}
	if data, err := os.ReadFile(path); err == nil {
		json.Unmarshal(data, &doc)
	}
	return doc
}

func setPath(doc map[string]any, keyPath []string, val any) {
	cur := doc
	for i, k := range keyPath {
		if i == len(keyPath)-1 {
			cur[k] = val
			return
		}
		next, ok := cur[k].(map[string]any)
		if !ok {
			next = map[string]any{}
			cur[k] = next
		}
		cur = next
	}
}

// atomicWrite writes data to path atomically (temp file + rename).
func atomicWrite(path string, data []byte) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}
