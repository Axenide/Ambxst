package svc

import (
	"sync"

	"ambxst/backend/pkg/ipc"
)

// UIService bridges `ambxst run <cmd>` to the QML shell via a subscription stream.
// QML subscribes to the "ui" service; commands pushed as ServiceEvent{Service:"ui.command", Data: cmd}.
type UIService struct {
	mu   sync.RWMutex
	subs map[*ipc.Subscriber]struct{}
}

func NewUIService() *UIService {
	return &UIService{subs: make(map[*ipc.Subscriber]struct{})}
}

// Register wires the service into the server.
func (u *UIService) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "ui",
		Methods: map[string]ipc.HandlerFunc{
			"run":    u.run,
			"toggle": u.toggle,
		},
		Subscribe: u.subscribe,
	})
}

func (u *UIService) run(params RawParams) (any, error) {
	cmd := paramsGet(params, "command")
	if cmd == "" {
		return nil, errorsNew("ui.run: missing command")
	}
	u.mu.RLock()
	defer u.mu.RUnlock()
	for sub := range u.subs {
		sub.Send("ui.command", cmd)
	}
	return "ok", nil
}

// toggle carries state-flipping commands (e.g. bar) as a distinct event
// kind, separate from the run actions.
func (u *UIService) toggle(params RawParams) (any, error) {
	cmd := paramsGet(params, "command")
	if cmd == "" {
		return nil, errorsNew("ui.toggle: missing command")
	}
	u.mu.RLock()
	defer u.mu.RUnlock()
	for sub := range u.subs {
		sub.Send("ui.toggle", cmd)
	}
	return "ok", nil
}

// subscribe registers the subscriber, blocks until it disconnects, then
// removes it. Blocking mirrors the notify service so the server's stream
// goroutine keeps pumping while the subscriber is live, and so every
// disconnect frees the subscriber instead of leaking it.
func (u *UIService) subscribe(sub *ipc.Subscriber) {
	u.mu.Lock()
	u.subs[sub] = struct{}{}
	u.mu.Unlock()

	<-sub.StopCh()

	u.mu.Lock()
	delete(u.subs, sub)
	u.mu.Unlock()
}
