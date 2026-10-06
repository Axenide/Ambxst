package systemmonitor

import (
	"encoding/json"
	"time"

	"ambxst/backend/pkg/ipc"
)

// Service provides hardware monitoring state and a delta stream.
type Service struct {
	monitor *Monitor
}

func NewService(intervalMS int, disks []string) *Service {
	return &Service{monitor: NewMonitor(disks, intervalMS)}
}

func (s *Service) Register(srv *ipc.Server) {
	m := s.monitor
	srv.Register(&ipc.Service{
		Name: "systemmonitor",
		Methods: map[string]ipc.HandlerFunc{
			"getStatic": func(_ json.RawMessage) (any, error) { return m.Static(), nil },
			"getState":  func(_ json.RawMessage) (any, error) { return m.Sample(), nil },
			"configure": func(params json.RawMessage) (any, error) {
				var p struct {
					IntervalMS *int     `json:"interval_ms"`
					Disks      []string `json:"disks"`
				}
				if err := json.Unmarshal(params, &p); err != nil {
					return nil, err
				}
				if p.IntervalMS != nil && *p.IntervalMS > 0 {
					m.SetUpdateMS(*p.IntervalMS)
				}
				if len(p.Disks) > 0 {
					m.SetDisks(p.Disks)
				}
				return "ok", nil
			},
		},
		Subscribe: s.subscribe,
	})
}

// subscribe pushes static info once, then deltas every interval.
func (s *Service) subscribe(sub *ipc.Subscriber) {
	m := s.monitor
	interval := time.Duration(m.UpdateMS()) * time.Millisecond
	if interval <= 0 {
		interval = 2 * time.Second
	}

	sub.Send("systemmonitor.static", m.Static())
	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	for {
		select {
		case <-ticker.C:
			sub.Send("systemmonitor", m.Sample())
		case <-sub.StopCh():
			return
		}
	}
}