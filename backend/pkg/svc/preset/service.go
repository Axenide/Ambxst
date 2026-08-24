// Package preset implements the daemon-side "preset" IPC service.
//
// `preset.list` scans both the user preset directory and the bundled
// assets/presets directory and returns the result. Resolution is
// server-side (cheap) so the CLI can pretty-print without talking to
// Quickshell first.
//
// `preset.load` is the CLI's "apply this preset now" hook. It broadcasts
// a `preset.load` ServiceEvent to QML subscribers, where
// PresetCommandService.qml calls into PresetsService.loadPreset().
package preset

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"

	"ambxst/backend/pkg/ipc"
	"ambxst/backend/pkg/paths"
)

type Service struct {
	paths *paths.Paths
	mu    sync.Mutex
	subs  []*ipc.Subscriber
}

func NewService(p *paths.Paths) *Service { return &Service{paths: p} }

func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "preset",
		Methods: map[string]ipc.HandlerFunc{
			"list": s.list,
			"load": s.load,
		},
		Subscribe: s.subscribe,
	})
}

func (s *Service) subscribe(sub *ipc.Subscriber) {
	s.mu.Lock()
	s.subs = append(s.subs, sub)
	s.mu.Unlock()

	go func() {
		<-sub.StopCh()
		s.mu.Lock()
		defer s.mu.Unlock()
		for i, x := range s.subs {
			if x == sub {
				s.subs = append(s.subs[:i], s.subs[i+1:]...)
				return
			}
		}
	}()
}

// Preset is the row shape returned by `preset.list` and serialized to
// the CLI for human display.
type Preset struct {
	Name        string   `json:"name"`
	Path        string   `json:"path"`
	Official    bool     `json:"official"`
	Author      string   `json:"author"`
	AuthorURL   string   `json:"authorUrl"`
	ConfigFiles []string `json:"configFiles"`
}

func (s *Service) userPresetsDir() string {
	if s.paths == nil {
		return ""
	}
	return filepath.Join(s.paths.ConfigDir, "presets")
}

func (s *Service) officialPresetsDir() string {
	if s.paths == nil {
		return ""
	}
	src := s.paths.ShellSourceDir()
	if src == "" {
		return ""
	}
	return filepath.Join(src, "assets", "presets")
}

func (s *Service) scan() []Preset {
	userDir := s.userPresetsDir()
	officialDir := s.officialPresetsDir()

	seen := map[string]*Preset{}

	for _, root := range []struct {
		dir     string
		official bool
	}{
		{userDir, false},
		{officialDir, true},
	} {
		if root.dir == "" {
			continue
		}
		entries, err := os.ReadDir(root.dir)
		if err != nil {
			continue
		}
		for _, e := range entries {
			if !e.IsDir() {
				continue
			}
			sub, err := os.ReadDir(filepath.Join(root.dir, e.Name()))
			if err != nil {
				continue
			}
			files := []string{}
			for _, f := range sub {
				if f.IsDir() {
					continue
				}
				name := f.Name()
				if !strings.HasSuffix(name, ".json") {
					continue
				}
				if name == "info.json" {
					continue
				}
				if isExcluded(name) {
					continue
				}
				files = append(files, strings.TrimSuffix(name, ".json")+".js")
			}
			if len(files) == 0 {
				continue
			}
			presetPath := filepath.Join(root.dir, e.Name())
			entry := Preset{
				Name:        e.Name(),
				Path:        presetPath,
				Official:    root.official,
				Author:      "Unknown",
				ConfigFiles: files,
			}
			if info, ok := readInfo(presetPath); ok {
				if info.Author != "" {
					entry.Author = info.Author
				}
				entry.AuthorURL = info.AuthorURL
			}
			key := presetPath
			seen[key] = &entry
		}
	}

	out := make([]Preset, 0, len(seen))
	for _, p := range seen {
		out = append(out, *p)
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].Official != out[j].Official {
			return out[i].Official
		}
		return strings.ToLower(out[i].Name) < strings.ToLower(out[j].Name)
	})
	return out
}

// excludedFiles mirrors PresetsService.excludedFiles on the QML side.
func isExcluded(name string) bool {
	switch name {
	case "system.json", "ai.json", "prefix.json", "weather.json":
		return true
	}
	return false
}

type infoFile struct {
	Author    string `json:"author"`
	AuthorURL string `json:"authorUrl"`
}

func readInfo(presetPath string) (infoFile, bool) {
	data, err := os.ReadFile(filepath.Join(presetPath, "info.json"))
	if err != nil {
		return infoFile{}, false
	}
	var info infoFile
	if err := json.Unmarshal(data, &info); err != nil {
		return infoFile{}, false
	}
	return info, true
}

func (s *Service) list(_ json.RawMessage) (any, error) {
	return s.scan(), nil
}

type LoadParams struct {
	Name string `json:"name"`
}

func (s *Service) load(params json.RawMessage) (any, error) {
	var p LoadParams
	if len(params) > 0 {
		if err := json.Unmarshal(params, &p); err != nil {
			return nil, err
		}
	}
	if p.Name == "" {
		return map[string]any{"error": "missing name"}, nil
	}

	matched := false
	for _, pst := range s.scan() {
		if strings.EqualFold(pst.Name, p.Name) {
			matched = true
			break
		}
	}

	s.mu.Lock()
	subs := append([]*ipc.Subscriber(nil), s.subs...)
	s.mu.Unlock()
	for _, sub := range subs {
		sub.Send("preset.load", map[string]any{
			"name":     p.Name,
			"resolved": matched,
		})
	}

	if !matched {
		return map[string]any{"ok": false, "error": "preset not found"}, nil
	}
	return map[string]any{"ok": true}, nil
}
