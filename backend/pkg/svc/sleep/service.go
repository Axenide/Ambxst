package sleep

import (
	"encoding/json"
	"fmt"
	"os/exec"

	"github.com/godbus/dbus/v5"

	"ambxst/backend/pkg/ipc"
)

// Service monitors login1 PrepareForSleep and Session.Lock signals,
// pushing SUSPEND/WAKE/LOCK events and running configured commands.
// Replaces sleep_monitor.sh and loginlock.sh.
type Service struct {
	conn        *dbus.Conn
	beforeSleep string
	afterSleep  string
	lockCMD     string
}

func NewService() (*Service, error) {
	conn, err := dbus.SystemBus()
	if err != nil {
		return nil, fmt.Errorf("system bus: %w", err)
	}
	return &Service{conn: conn}, nil
}

func (s *Service) Close() {
	if s.conn != nil {
		s.conn.Close()
	}
}

// Register wires the service into the server.
func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "sleep",
		Methods: map[string]ipc.HandlerFunc{
			"setCommands": func(params json.RawMessage) (any, error) {
				var p struct {
					Before string `json:"before"`
					After  string `json:"after"`
					Lock   string `json:"lock"`
				}
				if err := json.Unmarshal(params, &p); err != nil {
					return nil, err
				}
				if p.Before != "" {
					s.beforeSleep = p.Before
				}
				if p.After != "" {
					s.afterSleep = p.After
				}
				if p.Lock != "" {
					s.lockCMD = p.Lock
				}
				return "ok", nil
			},
		},
		Subscribe: s.subscribe,
	})
}

func (s *Service) subscribe(sub *ipc.Subscriber) {
	if s.conn == nil {
		return
	}

	ch := make(chan *dbus.Signal, 16)
	s.conn.Signal(ch)
	defer s.conn.RemoveSignal(ch)

	if err := s.conn.AddMatchSignal(
		dbus.WithMatchObjectPath("/org/freedesktop/login1"),
		dbus.WithMatchInterface("org.freedesktop.login1.Manager"),
		dbus.WithMatchMember("PrepareForSleep"),
	); err != nil {
		return
	}
	if err := s.conn.AddMatchSignal(
		dbus.WithMatchInterface("org.freedesktop.login1.Session"),
		dbus.WithMatchMember("Lock"),
	); err != nil {
		return
	}

	for {
		select {
		case sig, ok := <-ch:
			if !ok {
				return
			}
			if sig == nil {
				continue
			}
			switch sig.Name {
			case "org.freedesktop.login1.Manager.PrepareForSleep":
				for _, body := range sig.Body {
					if v, ok := body.(bool); ok {
						if v {
							sub.Send("sleep", map[string]any{"event": "SUSPEND"})
							runDetached(s.beforeSleep)
						} else {
							sub.Send("sleep", map[string]any{"event": "WAKE"})
							runDetached(s.afterSleep)
						}
					}
				}
			case "org.freedesktop.login1.Session.Lock":
				sub.Send("sleep", map[string]any{"event": "LOCK"})
				runDetached(s.lockCMD)
			}
		case <-sub.StopCh():
			return
		}
	}
}

func runDetached(cmd string) {
	if cmd == "" {
		return
	}
	exec.Command("sh", "-c", cmd).Start()
}