// Package wallpaper implements the daemon-side "wallpaper" IPC service.
// The CLI (`ambxst wallpaper <file> ...`) calls the Set method, which
// pushes a one-shot ServiceEvent out to every QML subscriber. Subscribers
// (WallpaperCommandService.qml) translate that into the existing setWallpaper
// flow on the Wallpaper component. No filesystem or process state is held
// here — wallpaper state remains owned by the Quickshell side.
package wallpaper

import (
	"encoding/json"
	"sync"

	"ambxst/backend/pkg/ipc"
)

type Service struct {
	mu   sync.Mutex
	subs []*ipc.Subscriber
}

// SetParams mirrors what the CLI sends. Only fields the caller set are
// forwarded to subscribers; an empty/missing field means "leave unchanged".
type SetParams struct {
	Path    string `json:"path"`
	Scheme  string `json:"scheme"`
	OLED    *bool  `json:"oled,omitempty"`
	Tint    *bool  `json:"tint,omitempty"`
	Monitor string `json:"monitor"`
}

func NewService() *Service { return &Service{} }

func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "wallpaper",
		Methods: map[string]ipc.HandlerFunc{
			"set": s.set,
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

func (s *Service) set(params json.RawMessage) (any, error) {
	var p SetParams
	if len(params) > 0 {
		if err := json.Unmarshal(params, &p); err != nil {
			return nil, err
		}
	}
	if p.Path == "" {
		return map[string]any{"error": "missing path"}, nil
	}

	payload := map[string]any{
		"path":    p.Path,
		"scheme":  p.Scheme,
		"monitor": p.Monitor,
	}
	if p.OLED != nil {
		payload["oled"] = *p.OLED
	}
	if p.Tint != nil {
		payload["tint"] = *p.Tint
	}

	s.mu.Lock()
	subs := append([]*ipc.Subscriber(nil), s.subs...)
	s.mu.Unlock()
	for _, sub := range subs {
		sub.Send("wallpaper.set", payload)
	}

	return map[string]any{"ok": true}, nil
}
