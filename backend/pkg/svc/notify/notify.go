package notify

import (
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"ambxst/backend/pkg/ipc"
	"ambxst/backend/pkg/paths"
)

const maxCacheImageSize = 8 << 20

var contentTypeExt = map[string]string{
	"image/png":     "png",
	"image/jpeg":    "jpg",
	"image/gif":     "gif",
	"image/webp":    "webp",
	"image/svg+xml": "svg",
	"image/x-icon":  "ico",
	"image/bmp":     "bmp",
	"image/avif":    "avif",
}

// Service exposes a notification-request IPC channel. CLIs that previously
// shelled out to `notify-send` (colorpicker, screen, …) route through this
// service instead so the running Ambxst shell can render the notification
// via its Notifications singleton. The end result: every notification is
// tracked, dismissable, and visible in the popup/notch/dashboard history
// instead of leaking into the system notification daemon.
//
// It also materializes notification images (remote URLs, local paths,
// data: URIs) into a hash-keyed disk cache so the shell can reference a
// stable file path across reloads instead of volatile URLs or inline
// base64 blobs.
type Service struct {
	mu        sync.RWMutex
	subs      map[*ipc.Subscriber]struct{}
	nextReqID atomic.Uint64
	paths     *paths.Paths
	client    *http.Client
}

func NewService(p *paths.Paths) *Service {
	return &Service{
		subs:   make(map[*ipc.Subscriber]struct{}),
		paths:  p,
		client: &http.Client{Timeout: 15 * time.Second},
	}
}

func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "notify",
		Methods: map[string]ipc.HandlerFunc{
			"send":       s.send,
			"cacheImage": s.cacheImage,
		},
		Subscribe: s.subscribe,
	})
}

// SendParams mirrors the shape Notifications.notifyInternal accepts on the
// QML side, plus an optional `actions` field whose entries can carry a
// `clipboard` value — when the user clicks the action, the QML side
// copies it through the daemon's clipboard service. This is how
// cross-process colorpicker actions
// stay in sync without requiring the CLI to keep its notification alive.
type SendParams struct {
	Summary      string         `json:"summary"`
	Body         string         `json:"body"`
	AppName      string         `json:"appName"`
	AppIcon      string         `json:"appIcon"`
	Image        string         `json:"image"`
	Urgency      string         `json:"urgency"`
	ExpireTimeout int           `json:"expireTimeout"`
	ReplaceKey   string         `json:"replaceKey"`
	Actions      []SendAction   `json:"actions"`
}

type SendAction struct {
	Identifier string `json:"identifier"`
	Text       string `json:"text"`
	Clipboard  string `json:"clipboard,omitempty"`
}

func (s *Service) send(params json.RawMessage) (any, error) {
	var p SendParams
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}
	if p.Summary == "" && p.Body == "" {
		return nil, &ValidationError{msg: "notify.send: summary or body required"}
	}
	if p.AppName == "" {
		p.AppName = "Ambxst"
	}

	id := s.nextReqID.Add(1)
	payload := map[string]any{
		"id":            int64(id),
		"summary":       p.Summary,
		"body":          p.Body,
		"appName":       p.AppName,
		"appIcon":       p.AppIcon,
		"image":         p.Image,
		"urgency":       p.Urgency,
		"expireTimeout": p.ExpireTimeout,
		"replaceKey":    p.ReplaceKey,
		"actions":       p.Actions,
	}

	s.mu.RLock()
	defer s.mu.RUnlock()
	for sub := range s.subs {
		sub.Send("notify.request", payload)
	}

	return map[string]any{"requestId": int64(id)}, nil
}

func (s *Service) subscribe(sub *ipc.Subscriber) {
	s.mu.Lock()
	s.subs[sub] = struct{}{}
	s.mu.Unlock()

	// Block until the subscriber disconnects; the IPC server drains our
	// sends on its own goroutine. Without this select the subscribe
	// callback returns immediately and the server's streamSubscribe
	// goroutine exits before the first event is pumped.
	<-sub.StopCh()

	s.mu.Lock()
	delete(s.subs, sub)
	s.mu.Unlock()
}

// CacheImageParams describes the image source to materialize. `URL` may
// be an http(s) URL, a file:// URL, an absolute local path, or a data:
// URI.
type CacheImageParams struct {
	URL string `json:"url"`
}

// cacheImage copies the referenced image into the notification image
// cache keyed by content hash and returns a stable file path the shell
// can persist across reloads.
func (s *Service) cacheImage(params json.RawMessage) (any, error) {
	var p CacheImageParams
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}
	if p.URL == "" {
		return nil, &ValidationError{msg: "notify.cacheImage: url required"}
	}
	if s.paths == nil {
		return nil, &ValidationError{msg: "notify.cacheImage: paths not configured"}
	}

	var (
		data []byte
		ext  string
		err  error
	)
	switch {
	case strings.HasPrefix(p.URL, "data:"):
		data, ext, err = decodeDataURI(p.URL)
	case strings.HasPrefix(p.URL, "http://"), strings.HasPrefix(p.URL, "https://"):
		data, ext, err = s.fetchRemote(p.URL)
	case strings.HasPrefix(p.URL, "file://"):
		var raw string
		raw, err = fileURIToPath(p.URL)
		if err == nil {
			data, ext, err = readLocalFile(raw)
		}
	default:
		data, ext, err = readLocalFile(p.URL)
	}
	if err != nil {
		return nil, &ValidationError{msg: fmt.Sprintf("notify.cacheImage: %v", err)}
	}

	cachePath, err := s.storeImage(data, ext)
	if err != nil {
		return nil, fmt.Errorf("notify.cacheImage: %w", err)
	}
	return map[string]any{"path": cachePath}, nil
}

func (s *Service) storeImage(data []byte, ext string) (string, error) {
	sum := sha256.Sum256(data)
	name := hex.EncodeToString(sum[:])
	if ext != "" {
		name += "." + ext
	}

	dir := s.paths.NotificationsImageCacheDir()
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return "", err
	}
	dest := filepath.Join(dir, name)
	if _, err := os.Stat(dest); err == nil {
		return dest, nil
	}

	tmp, err := os.CreateTemp(dir, ".tmp-*")
	if err != nil {
		return "", err
	}
	defer os.Remove(tmp.Name())

	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		return "", err
	}
	if err := tmp.Close(); err != nil {
		return "", err
	}
	if err := os.Chmod(tmp.Name(), 0o600); err != nil {
		return "", err
	}
	if err := os.Rename(tmp.Name(), dest); err != nil {
		return "", err
	}
	return dest, nil
}

func (s *Service) fetchRemote(rawURL string) ([]byte, string, error) {
	req, err := http.NewRequest(http.MethodGet, rawURL, nil)
	if err != nil {
		return nil, "", err
	}
	resp, err := s.client.Do(req)
	if err != nil {
		return nil, "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, "", fmt.Errorf("unexpected status %d", resp.StatusCode)
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, maxCacheImageSize+1))
	if err != nil {
		return nil, "", err
	}
	if len(data) > maxCacheImageSize {
		return nil, "", fmt.Errorf("image exceeds %d bytes", maxCacheImageSize)
	}
	ext := sniffExt(data, resp.Header.Get("Content-Type"))
	return data, ext, nil
}

func fileURIToPath(raw string) (string, error) {
	u, err := url.Parse(raw)
	if err != nil {
		return "", err
	}
	if u.Host != "" && u.Host != "localhost" {
		return "", fmt.Errorf("unsupported file host %q", u.Host)
	}
	return u.Path, nil
}

func readLocalFile(path string) ([]byte, string, error) {
	info, err := os.Stat(path)
	if err != nil {
		return nil, "", err
	}
	if info.Size() > maxCacheImageSize {
		return nil, "", fmt.Errorf("image exceeds %d bytes", maxCacheImageSize)
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, "", err
	}
	return data, sniffExt(data, ""), nil
}

func decodeDataURI(raw string) ([]byte, string, error) {
	rest := strings.TrimPrefix(raw, "data:")
	sep := strings.Index(rest, ",")
	if sep < 0 {
		return nil, "", fmt.Errorf("malformed data URI")
	}
	meta := rest[:sep]
	payload := rest[sep+1:]
	if !strings.Contains(meta, ";base64") {
		return nil, "", fmt.Errorf("only base64 data URIs are supported")
	}
	data, err := base64.StdEncoding.DecodeString(payload)
	if err != nil {
		return nil, "", err
	}
	mime := strings.TrimSuffix(meta, ";base64")
	return data, sniffExt(data, mime), nil
}

// sniffExt derives a file extension from the actual bytes, falling back
// to the declared MIME type only when sniffing is inconclusive.
func sniffExt(data []byte, declaredMime string) string {
	if len(data) == 0 {
		return ""
	}
	switch http.DetectContentType(data) {
	case "image/png":
		return "png"
	case "image/jpeg":
		return "jpg"
	case "image/gif":
		return "gif"
	case "image/webp":
		return "webp"
	case "image/bmp":
		return "bmp"
	case "image/x-icon":
		return "ico"
	case "text/xml; charset=utf-8":
		if strings.Contains(declaredMime, "svg") || looksLikeSVG(data) {
			return "svg"
		}
	case "text/plain; charset=utf-8":
		if looksLikeSVG(data) {
			return "svg"
		}
	}
	if strings.Contains(declaredMime, "svg") {
		return "svg"
	}
	return ""
}

func looksLikeSVG(data []byte) bool {
	head := string(data[:min(len(data), 512)])
	return strings.Contains(head, "<svg")
}

// ValidationError reports a malformed notify.send payload.
type ValidationError struct{ msg string }

func (e *ValidationError) Error() string { return e.msg }

// SendFallback writes a notification via notify-send. Used by CLI commands
// when the ambxst daemon is not running (e.g. during early boot or when
// the shell hasn't started yet) so users still see the message instead of
// failing silently.
func SendFallback(summary, body, urgency string) error {
	args := []string{summary, body}
	if urgency != "" {
		args = append(args, "-u", urgency)
	}
	return exec.Command("notify-send", args...).Start()
}
