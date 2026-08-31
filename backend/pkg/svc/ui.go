package svc

import "ambxst/backend/pkg/ipc"

// UIService bridges `ambxst run <cmd>` to the QML shell via a subscription stream.
// QML subscribes to the "ui" service; commands pushed as ServiceEvent{Service:"ui.command", Data: cmd}.
type UIService struct {
	subs map[string]*ipc.Subscriber
}

func NewUIService() *UIService {
	return &UIService{subs: make(map[string]*ipc.Subscriber)}
}

// Register wires the service into the server.
func (u *UIService) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "ui",
		Methods: map[string]ipc.HandlerFunc{
			"run": u.run,
		},
		Subscribe: u.subscribe,
	})
}

func (u *UIService) run(params RawParams) (any, error) {
	cmd := paramsGet(params, "command")
	if cmd == "" {
		return nil, errorsNew("ui.run: missing command")
	}
	for _, sub := range u.subs {
		sub.Send("ui.command", cmd)
	}
	return "ok", nil
}

func (u *UIService) subscribe(sub *ipc.Subscriber) {
	u.subs[subID(sub)] = sub
}