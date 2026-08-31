package notify

import (
	"bufio"
	"encoding/json"
	"net"
	"path/filepath"
	"testing"
	"time"

	"ambxst/backend/pkg/ipc"
)

// e2e spins up a real ipc.Server with the notify service registered,
// dials it as a subscriber, dials it again as a caller, and verifies the
// request flows end-to-end. This catches wiring bugs (socket path,
// subscribe handshake, JSON framing) that the unit tests above can't.
func TestE2E_SendTriggersSubscriberEvent(t *testing.T) {
	sockPath := filepath.Join(t.TempDir(), "notify.sock")

	srv := ipc.NewServer(sockPath)
	svc := NewService()
	svc.Register(srv)
	if err := srv.Listen(); err != nil {
		t.Fatalf("Listen: %v", err)
	}
	defer srv.Close()

	go func() { _ = srv.Serve() }()

	// Subscriber dials, sends subscribe, reads events.
	subEvents := make(chan ipc.ServiceEvent, 4)
	subErr := make(chan error, 1)
	go func() {
		conn, err := net.Dial("unix", sockPath)
		if err != nil {
			subErr <- err
			return
		}
		defer conn.Close()
		w := bufio.NewWriter(conn)
		req := ipc.Request{
			ID:     json.RawMessage(`1`),
			Method: "subscribe",
			Params: json.RawMessage(`{"services":["notify"]}`),
		}
		data, _ := json.Marshal(req)
		if _, err := w.Write(append(data, '\n')); err != nil {
			subErr <- err
			return
		}
		if err := w.Flush(); err != nil {
			subErr <- err
			return
		}
		scanner := bufio.NewScanner(conn)
		for scanner.Scan() {
			var resp ipc.Response
			if err := json.Unmarshal(scanner.Bytes(), &resp); err != nil {
				continue
			}
			// Subscription events come back as Result carrying the
			// ServiceEvent directly (server.go marshals it for us).
			if len(resp.Result) == 0 {
				continue
			}
			var ev ipc.ServiceEvent
			if err := json.Unmarshal(resp.Result, &ev); err != nil {
				continue
			}
			if ev.Service == "notify.request" {
				subEvents <- ev
				return
			}
		}
	}()

	// Wait for the subscriber to register before firing the request.
	waitFor(t, func() bool { return len(svc.subs) == 1 }, 2*time.Second, "subscriber registration")

	// Caller dials and invokes notify.send.
	conn, err := net.Dial("unix", sockPath)
	if err != nil {
		t.Fatalf("caller dial: %v", err)
	}
	defer conn.Close()
	w := bufio.NewWriter(conn)
	payload := map[string]any{
		"summary": "Color Picked",
		"body":    "#ff0000",
		"appName": "ColorPicker",
		"actions": []map[string]string{
			{"identifier": "hex", "text": "Copy HEX", "clipboard": "#ff0000"},
		},
	}
	req := struct {
		ID     int            `json:"id"`
		Method string         `json:"method"`
		Params map[string]any `json:"params"`
	}{ID: 1, Method: "notify.send", Params: payload}
	data, _ := json.Marshal(req)
	if _, err := w.Write(append(data, '\n')); err != nil {
		t.Fatalf("write: %v", err)
	}
	if err := w.Flush(); err != nil {
		t.Fatalf("flush: %v", err)
	}
	scanner := bufio.NewScanner(conn)
	if !scanner.Scan() {
		t.Fatalf("no response: %v", scanner.Err())
	}
	var resp ipc.Response
	if err := json.Unmarshal(scanner.Bytes(), &resp); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if resp.Error != "" {
		t.Fatalf("server error: %s", resp.Error)
	}
	var result map[string]any
	if err := json.Unmarshal(resp.Result, &result); err != nil {
		t.Fatalf("decode result: %v", err)
	}
	if _, ok := result["requestId"]; !ok {
		t.Fatalf("missing requestId: %v", result)
	}

	// Subscriber should now see the notify.request event.
	select {
	case ev := <-subEvents:
		if ev.Service != "notify.request" {
			t.Fatalf("unexpected event service: %s", ev.Service)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("subscriber did not receive event within 2s")
	}
}

func waitFor(t *testing.T, cond func() bool, timeout time.Duration, what string) {
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

// Sanity check that SendFallback doesn't crash even if notify-send is
// absent on the test host. It uses Start() so we never block.
func TestSendFallback_NeverBlocks(t *testing.T) {
	done := make(chan struct{})
	go func() {
		_ = SendFallback("ambxst", "test", "low")
		close(done)
	}()
	select {
	case <-done:
	case <-time.After(500 * time.Millisecond):
		t.Fatal("SendFallback blocked")
	}
}
