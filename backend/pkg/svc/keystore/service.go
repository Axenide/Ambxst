package keystore

import (
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"ambxst/backend/pkg/ipc"
	"ambxst/backend/pkg/paths"
)

// Service stores encrypted API keys in an sqlite DB (XOR with the machine-id
// salt, byte-compatible with the legacy scripts/keystore.py flow).
type Service struct {
	paths *paths.Paths
	db    string
	lock  chan struct{}
}

func NewService(p *paths.Paths) *Service {
	return &Service{
		paths: p,
		db:    p.KeysDB(),
		lock:  make(chan struct{}, 1),
	}
}

func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "keystore",
		Methods: map[string]ipc.HandlerFunc{
			"get":    s.get,
			"set":    s.set,
			"delete": s.delete,
			"list":   s.list,
			"has":    s.has,
		},
	})
}

type entry struct {
	Provider   string `json:"provider"`
	APIKey     string `json:"api_key"`
	Endpoint   string `json:"endpoint"`
	CustomCurl string `json:"custom_curl"`
}

func machineKey() []byte {
	data, err := os.ReadFile("/etc/machine-id")
	if err == nil && len(strings.TrimSpace(string(data))) > 0 {
		return []byte(strings.TrimSpace(string(data)))
	}
	return []byte("ambxst-fallback-salt-82741")
}

func xorCrypt(data, key []byte) []byte {
	out := make([]byte, len(data))
	for i, b := range data {
		out[i] = b ^ key[i%len(key)]
	}
	return out
}

func encrypt(text string, key []byte) string {
	return hex.EncodeToString(xorCrypt([]byte(text), key))
}

func decrypt(hexStr string, key []byte) string {
	enc, err := hex.DecodeString(hexStr)
	if err != nil {
		return ""
	}
	return string(xorCrypt(enc, key))
}

func (s *Service) ensureDB() error {
	if err := os.MkdirAll(filepath.Dir(s.db), 0o755); err != nil {
		return err
	}
	if err := os.Chmod(s.db, 0o600); err != nil {
		return err
	}
	_, err := exec.Command("sqlite3", s.db,
		`CREATE TABLE IF NOT EXISTS api_keys (
			 provider TEXT PRIMARY KEY,
			 api_key TEXT NOT NULL,
			 endpoint TEXT DEFAULT '',
			 custom_curl TEXT DEFAULT ''
		 )`).Output()
	return err
}

func (s *Service) query(args ...string) (string, error) {
	s.lock <- struct{}{}
	defer func() { <-s.lock }()
	cmd := exec.Command("sqlite3", s.db, args[0])
	cmd.Args = append(cmd.Args, args[1:]...)
	out, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return string(out), nil
}

func (s *Service) get(params json.RawMessage) (any, error) {
	var p struct {
		Provider string `json:"provider"`
	}
	json.Unmarshal(params, &p)
	if p.Provider == "" {
		return map[string]any{"error": "get requires provider"}, nil
	}
	out, err := s.query(`SELECT * FROM api_keys WHERE provider = `+qsql(p.Provider))
	if err != nil || strings.TrimSpace(out) == "" {
		return map[string]any{"error": fmt.Sprintf("Provider '%s' not found", p.Provider)}, nil
	}
	return entryFromRow(out), nil
}

func (s *Service) set(params json.RawMessage) (any, error) {
	var p struct {
		Provider   string `json:"provider"`
		APIKey     string `json:"api_key"`
		Endpoint   string `json:"endpoint"`
		CustomCurl string `json:"custom_curl"`
	}
	json.Unmarshal(params, &p)
	if p.Provider == "" || p.APIKey == "" {
		return map[string]any{"error": "set requires provider and api_key"}, nil
	}
	key := machineKey()
	enc := encrypt(p.APIKey, key)
	_, err := s.query(`INSERT OR REPLACE INTO api_keys VALUES (` +
		qsql(p.Provider) + `,` + qsql(enc) + `,` + qsql(p.Endpoint) + `,` + qsql(p.CustomCurl) + `)`)
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return map[string]any{"status": "ok"}, nil
}

func (s *Service) delete(params json.RawMessage) (any, error) {
	var p struct {
		Provider string `json:"provider"`
	}
	json.Unmarshal(params, &p)
	if p.Provider == "" {
		return map[string]any{"error": "delete requires provider"}, nil
	}
	_, err := s.query(`DELETE FROM api_keys WHERE provider = ` + qsql(p.Provider))
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return map[string]any{"status": "ok"}, nil
}

func (s *Service) list(params json.RawMessage) (any, error) {
	// sqlite3 CLI has no CSV loop; use a JSON mode? -json not available in all
	// versions. Fallback: SELECT with separator and parse rows manually.
	if err := s.ensureDB(); err != nil {
		return []any{}, nil
	}
	s.lock <- struct{}{}
	defer func() { <-s.lock }()
	out, err := exec.Command("sqlite3", "-separator", "\x1f", s.db,
		`SELECT provider, api_key, endpoint, custom_curl FROM api_keys`).Output()
	if err != nil {
		return []any{}, nil
	}
	rows := strings.Split(strings.TrimSpace(string(out)), "\n")
	key := machineKey()
	result := []entry{}
	for _, row := range rows {
		if row == "" {
			continue
		}
		fields := strings.Split(row, "\x1f")
		if len(fields) < 1 {
			continue
		}
		e := entry{Provider: fields[0]}
		if len(fields) > 1 {
			e.APIKey = decrypt(fields[1], key)
		}
		if len(fields) > 2 {
			e.Endpoint = fields[2]
		}
		if len(fields) > 3 {
			e.CustomCurl = fields[3]
		}
		result = append(result, e)
	}
	return result, nil
}

func (s *Service) has(params json.RawMessage) (any, error) {
	var p struct {
		Provider string `json:"provider"`
	}
	json.Unmarshal(params, &p)
	if p.Provider == "" {
		return false, nil
	}
	out, err := s.query(`SELECT 1 FROM api_keys WHERE provider = ` + qsql(p.Provider))
	if err != nil || strings.TrimSpace(out) == "" {
		return false, nil
	}
	return true, nil
}

func qsql(s string) string {
	return "'" + strings.ReplaceAll(s, "'", "''") + "'"
}

func entryFromRow(row string) map[string]any {
	fields := strings.Split(row, "|")
	e := map[string]any{"provider": fields[0]}
	if len(fields) > 1 {
		e["api_key"] = decrypt(fields[1], machineKey())
	}
	if len(fields) > 2 {
		e["endpoint"] = fields[2]
	}
	if len(fields) > 3 {
		e["custom_curl"] = fields[3]
	}
	return e
}
