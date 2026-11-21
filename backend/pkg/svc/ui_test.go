package svc

import (
	"bufio"
	"encoding/json"
	"net"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"ambxst/backend/pkg/ipc"
)

// startUIServer boots an ipc.Server with the ui service registered and
// returns the service (for direct handler calls and subscriber inspection)
// plus the socket path.
func startUIServer(t *testing.T) (*UIService, string) {
	t.Helper()
	sockPath := filepath.Join(t.TempDir(), "ui.sock")
	srv := ipc.NewServer(sockPath)
	ui := NewUIService()
	ui.Register(srv)
	if err := srv.Listen(); err != nil {
		t.Fatalf("Listen: %v", err)
	}
	t.Cleanup(func() { srv.Close() })
	go func() { _ = srv.Serve() }()
	return ui, sockPath
}

// dialUISubscriber connects, subscribes to the ui service, and forwards
// ui.command / ui.toggle events on the returned channel.
func dialUISubscriber(t *testing.T, sockPath string) <-chan string {
	t.Helper()
	events := make(chan string, 16)
	conn, err := net.Dial("unix", sockPath)
	if err != nil {
		t.Fatalf("subscriber dial: %v", err)
	}
	req := ipc.Request{
		ID:     json.RawMessage(`1`),
		Method: "subscribe",
		Params: json.RawMessage(`{"services":["ui"]}`),
	}
	data, _ := json.Marshal(req)
	if _, err := conn.Write(append(data, '\n')); err != nil {
		t.Fatalf("subscriber write: %v", err)
	}
	go func() {
		defer close(events)
		scanner := bufio.NewScanner(conn)
		for scanner.Scan() {
			var resp ipc.Response
			if json.Unmarshal(scanner.Bytes(), &resp) != nil || len(resp.Result) == 0 {
				continue
			}
			var ev ipc.ServiceEvent
			if json.Unmarshal(resp.Result, &ev) != nil {
				continue
			}
			if ev.Service == "ui.command" || ev.Service == "ui.toggle" {
				if s, ok := ev.Data.(string); ok {
					select {
					case events <- s:
					default:
					}
				}
			}
		}
	}()
	t.Cleanup(func() { _ = conn.Close() })
	return events
}

func uiSubscriberCount(ui *UIService) int {
	ui.mu.RLock()
	defer ui.mu.RUnlock()
	return len(ui.subs)
}

func uiWaitFor(t *testing.T, cond func() bool, timeout time.Duration, what string) {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if cond() {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatalf("timeout waiting for %s", what)
}

// A still-connected subscriber must receive ui.command events.
func TestUIRunDeliversEventToSubscriber(t *testing.T) {
	ui, sockPath := startUIServer(t)
	events := dialUISubscriber(t, sockPath)

	uiWaitFor(t, func() bool { return uiSubscriberCount(ui) == 1 },
		2*time.Second, "subscriber registration")

	if _, err := ui.run(json.RawMessage(`{"command":"dashboard"}`)); err != nil {
		t.Fatalf("run: %v", err)
	}
	select {
	case cmd := <-events:
		if cmd != "dashboard" {
			t.Fatalf("unexpected command: %q", cmd)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("subscriber did not receive ui.command within 2s")
	}
}

// Every live subscriber must receive the command. With the old string keys
// derived from a parameter address, a second subscriber could silently
// overwrite the first one in the map.
func TestUIRunReachesAllSubscribers(t *testing.T) {
	ui, sockPath := startUIServer(t)
	ev1 := dialUISubscriber(t, sockPath)
	ev2 := dialUISubscriber(t, sockPath)

	uiWaitFor(t, func() bool { return uiSubscriberCount(ui) == 2 },
		2*time.Second, "two subscriber registrations")

	if _, err := ui.run(json.RawMessage(`{"command":"dashboard"}`)); err != nil {
		t.Fatalf("run: %v", err)
	}
	for name, ev := range map[string]<-chan string{"first": ev1, "second": ev2} {
		select {
		case <-ev:
		case <-time.After(2 * time.Second):
			t.Fatalf("%s subscriber did not receive ui.command", name)
		}
	}
}

// A disconnected subscriber must be removed once its stop signal fires;
// otherwise every shell reload leaks the subscriber and its 256-slot
// event channel for the daemon's lifetime.
func TestUISubscriberRemovedAfterDisconnect(t *testing.T) {
	ui, sockPath := startUIServer(t)
	_ = dialUISubscriber(t, sockPath)

	uiWaitFor(t, func() bool { return uiSubscriberCount(ui) == 1 },
		2*time.Second, "subscriber registration")

	// Stop the subscriber the way the server does when its stream dies.
	ui.mu.RLock()
	var sub *ipc.Subscriber
	for s := range ui.subs {
		sub = s
	}
	ui.mu.RUnlock()
	if sub == nil {
		t.Fatal("no subscriber registered")
	}
	sub.Stop()

	uiWaitFor(t, func() bool { return uiSubscriberCount(ui) == 0 },
		2*time.Second, "subscriber removal after disconnect")
}

// ui.run reads the subscriber map from IPC handler goroutines while
// subscribe writes it from per-connection goroutines. Run under -race,
// the map access must stay clean.
func TestUIRunConcurrentWithSubscribe(t *testing.T) {
	ui, sockPath := startUIServer(t)

	stop := make(chan struct{})
	var writers sync.WaitGroup
	for i := 0; i < 3; i++ {
		writers.Add(1)
		go func() {
			defer writers.Done()
			for {
				select {
				case <-stop:
					return
				default:
				}
				conn, err := net.Dial("unix", sockPath)
				if err != nil {
					return
				}
				req := ipc.Request{
					ID:     json.RawMessage(`1`),
					Method: "subscribe",
					Params: json.RawMessage(`{"services":["ui"]}`),
				}
				data, _ := json.Marshal(req)
				if _, err := conn.Write(append(data, '\n')); err != nil {
					_ = conn.Close()
					return
				}
				time.Sleep(2 * time.Millisecond)
				_ = conn.Close()
			}
		}()
	}

	deadline := time.Now().Add(300 * time.Millisecond)
	for time.Now().Before(deadline) {
		if _, err := ui.run(json.RawMessage(`{"command":"x"}`)); err != nil {
			t.Fatalf("run: %v", err)
		}
	}
	close(stop)
	writers.Wait()
}
