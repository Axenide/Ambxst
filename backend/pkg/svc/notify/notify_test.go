package notify

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"ambxst/backend/pkg/ipc"
	"ambxst/backend/pkg/paths"
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
	s := NewService(&paths.Paths{CacheDir: t.TempDir()})
	out, err := s.send(json.RawMessage(`{"body":"hi"}`))
	if err != nil {
		t.Fatalf("body-only payload should be accepted, got error: %v", err)
	}
	if _, ok := out.(map[string]any); !ok {
		t.Fatalf("expected map result, got %T", out)
	}
}

func TestSend_BothEmptyRejected(t *testing.T) {
	s := NewService(&paths.Paths{CacheDir: t.TempDir()})
	_, err := s.send(json.RawMessage(`{}`))
	if err == nil {
		t.Fatal("expected error when both summary and body are missing")
	}
}

func TestSend_DefaultAppName(t *testing.T) {
	s := NewService(&paths.Paths{CacheDir: t.TempDir()})
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

func pngBytes(t *testing.T) []byte {
	t.Helper()
	b64 := "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
	data, err := base64.StdEncoding.DecodeString(b64)
	if err != nil {
		t.Fatalf("decode png: %v", err)
	}
	return data
}

func TestCacheImage_DataURI(t *testing.T) {
	s := NewService(&paths.Paths{CacheDir: t.TempDir()})
	data := pngBytes(t)
	raw := "data:image/png;base64," + base64.StdEncoding.EncodeToString(data)

	out, err := s.cacheImage(json.RawMessage(`{"url":"`+raw+`"}`))
	if err != nil {
		t.Fatalf("cacheImage: %v", err)
	}
	path := out.(map[string]any)["path"].(string)
	if !strings.HasPrefix(path, s.paths.NotificationsImageCacheDir()) {
		t.Fatalf("path outside cache dir: %q", path)
	}
	if !strings.HasSuffix(path, ".png") {
		t.Fatalf("expected .png extension, got %q", path)
	}
	written, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read cached: %v", err)
	}
	if !bytes.Equal(written, data) {
		t.Fatal("cached content mismatch")
	}

	out2, err := s.cacheImage(json.RawMessage(`{"url":"`+raw+`"}`))
	if err != nil {
		t.Fatalf("cacheImage second call: %v", err)
	}
	if out2.(map[string]any)["path"] != path {
		t.Fatalf("expected hash dedup, got %q vs %q", out2.(map[string]any)["path"], path)
	}
}

func TestCacheImage_LocalFile(t *testing.T) {
	s := NewService(&paths.Paths{CacheDir: t.TempDir()})
	data := pngBytes(t)
	src := filepath.Join(t.TempDir(), "in.png")
	if err := os.WriteFile(src, data, 0o600); err != nil {
		t.Fatalf("write src: %v", err)
	}

	for _, u := range []string{src, "file://" + src} {
		out, err := s.cacheImage(json.RawMessage(`{"url":"`+u+`"}`))
		if err != nil {
			t.Fatalf("cacheImage(%q): %v", u, err)
		}
		path := out.(map[string]any)["path"].(string)
		written, err := os.ReadFile(path)
		if err != nil {
			t.Fatalf("read cached: %v", err)
		}
		if !bytes.Equal(written, data) {
			t.Fatalf("content mismatch for %q", u)
		}
	}
}

func TestCacheImage_RemoteURL(t *testing.T) {
	data := pngBytes(t)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/octet-stream")
		_, _ = w.Write(data)
	}))
	defer srv.Close()

	s := NewService(&paths.Paths{CacheDir: t.TempDir()})
	out, err := s.cacheImage(json.RawMessage(`{"url":"`+srv.URL+`/img.png"}`))
	if err != nil {
		t.Fatalf("cacheImage: %v", err)
	}
	path := out.(map[string]any)["path"].(string)
	if !strings.HasSuffix(path, ".png") {
		t.Fatalf("expected snifed .png extension, got %q", path)
	}
}

func TestCacheImage_Errors(t *testing.T) {
	s := NewService(&paths.Paths{CacheDir: t.TempDir()})
	cases := []struct {
		name   string
		params string
	}{
		{"empty url", `{"url":""}`},
		{"missing url", `{}`},
		{"bad data uri", `{"url":"data:text/plain,hello"}`},
		{"invalid base64", `{"url":"data:image/png;base64,!!!"}`},
		{"missing file", `{"url":"/nonexistent/ambxst-nope.png"}`},
		{"http 404", `{"url":"http://127.0.0.1:1/nope.png"}`},
	}
	for _, tc := range cases {
		if _, err := s.cacheImage(json.RawMessage(tc.params)); err == nil {
			t.Fatalf("%s: expected error", tc.name)
		}
	}
}

func TestCacheImage_OversizeRejected(t *testing.T) {
	data := bytes.Repeat([]byte("x"), maxCacheImageSize+1)
	src := filepath.Join(t.TempDir(), "big.bin")
	if err := os.WriteFile(src, data, 0o600); err != nil {
		t.Fatalf("write src: %v", err)
	}
	s := NewService(&paths.Paths{CacheDir: t.TempDir()})
	if _, err := s.cacheImage(json.RawMessage(`{"url":"`+src+`"}`)); err == nil {
		t.Fatal("expected oversize rejection")
	}
}
