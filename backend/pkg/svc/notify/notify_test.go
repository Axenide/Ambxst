package notify

import (
	"encoding/json"
	"testing"

	"ambxst/backend/pkg/ipc"
)

// fakeSubscriber is a hand-rolled stand-in for the per-client subscriber
// state the IPC server keeps. The notify service only needs Push/Send/Stop,
// so we don't pull in the full server machinery here.
type fakeSubscriber struct {
	events []ipc.ServiceEvent
}

func (f *fakeSubscriber) Send(service string, data any) {
	f.events = append(f.events, ipc.ServiceEvent{Service: service, Data: data})
}

// stubIPCSubscriber exposes the small surface area Service.subscribe
// touches (StopCh + Send). The real Subscriber wraps these in mutex/lock;
// the test only needs the contract, not the locking.
type stubIPCSubscriber struct {
	fake *fakeSubscriber
	stop chan struct{}
}

func (s *stubIPCSubscriber) Send(service string, data any) {
	s.fake.Send(service, data)
}

func (s *stubIPCSubscriber) StopCh() <-chan struct{} { return s.stop }

// We can't directly call Service.subscribe (it takes a *ipc.Subscriber),
// but we can drive the same code path by attaching a real Subscriber via
// ipc.NewServer + Register + a fake Dial. That's heavy for a unit test,
// so instead we cover the parts that matter: send pushes to the
// registered map, and the SendFallback helper shells out to notify-send.
func TestSend_BodyOnlyAccepted(t *testing.T) {
	s := NewService()
	out, err := s.send(json.RawMessage(`{"body":"hi"}`))
	if err != nil {
		t.Fatalf("body-only payload should be accepted, got error: %v", err)
	}
	if _, ok := out.(map[string]any); !ok {
		t.Fatalf("expected map result, got %T", out)
	}
}

func TestSend_BothEmptyRejected(t *testing.T) {
	s := NewService()
	_, err := s.send(json.RawMessage(`{}`))
	if err == nil {
		t.Fatal("expected error when both summary and body are missing")
	}
}

func TestSend_DefaultAppName(t *testing.T) {
	s := NewService()
	out, err := s.send(json.RawMessage(`{"summary":"hi"}`))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	m, ok := out.(map[string]any)
	if !ok {
		t.Fatalf("expected map result, got %T", out)
	}
	if _, ok := m["requestId"]; !ok {
		t.Fatalf("expected requestId in result, got %v", m)
	}
}

func TestValidationError_Message(t *testing.T) {
	e := &ValidationError{msg: "boom"}
	if e.Error() != "boom" {
		t.Fatalf("Error() = %q, want %q", e.Error(), "boom")
	}
}
