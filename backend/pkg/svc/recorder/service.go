package recorder

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"

	"ambxst/backend/pkg/ipc"
	"ambxst/backend/pkg/paths"
)

type Service struct {
	paths *paths.Paths

	mu       sync.Mutex
	cmd      *exec.Cmd
	done     chan struct{}
	started  time.Time
	mode     string
	outPath  string
	lastPath string
	stopping bool

	subsMu sync.Mutex
	subs   []*ipc.Subscriber
}

func NewService(p *paths.Paths) *Service {
	return &Service{paths: p}
}

func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "recorder",
		Methods: map[string]ipc.HandlerFunc{
			"start":  s.start,
			"stop":   s.stop,
			"status": s.status,
			"dir":    s.dir,
		},
		Subscribe: s.subscribe,
	})
}

type startParams struct {
	Mode    string `json:"mode"`
	Output  string `json:"output"`
	Region  string `json:"region"`
	AudioOut bool  `json:"audioOut"`
	AudioIn  bool  `json:"audioIn"`
	Framerate int  `json:"framerate"`
}

func (s *Service) start(params json.RawMessage) (any, error) {
	var p startParams
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}
	if p.Mode == "" {
		p.Mode = "screen"
	}
	if p.Framerate <= 0 {
		p.Framerate = 60
	}

	s.mu.Lock()
	if s.cmd != nil {
		s.mu.Unlock()
		return nil, fmt.Errorf("recording already in progress")
	}

	dir := filepath.Join(s.paths.VideosDir(), "Recordings")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		s.mu.Unlock()
		return nil, err
	}
	name := strings.ReplaceAll(time.Now().Format(time.RFC3339), ":", "-")
	name = strings.ReplaceAll(name, ".", "-")
	outPath := filepath.Join(dir, name+".mp4")

	args := []string{"-f", fmt.Sprintf("%d", p.Framerate), "-w", p.Mode}
	switch p.Mode {
	case "screen", "portal":
		if p.Output != "" {
			args = append(args, "-o", p.Output)
		}
	case "region":
		if p.Region == "" {
			s.mu.Unlock()
			return nil, fmt.Errorf("region is required for region mode")
		}
		args = append(args, "-region", p.Region)
		if p.Output != "" {
			args = append(args, "-o", p.Output)
		}
	case "window":
		if p.Output != "" {
			args = append(args, "-k", p.Output)
		}
	}

	if p.AudioOut && p.AudioIn {
		args = append(args, "-a", "default_output|default_input")
	} else if p.AudioOut {
		args = append(args, "-a", "default_output")
	} else if p.AudioIn {
		args = append(args, "-a", "default_input")
	}

	args = append(args, "-o", outPath)

	cmd := exec.Command("gpu-screen-recorder", args...)
	cmd.Stdout = os.Stderr
	cmd.Stderr = os.Stderr
	if err := cmd.Start(); err != nil {
		s.mu.Unlock()
		return nil, fmt.Errorf("spawn gpu-screen-recorder: %w", err)
	}

	s.cmd = cmd
	s.done = make(chan struct{})
	s.started = time.Now()
	s.mode = p.Mode
	s.outPath = outPath
	s.lastPath = ""
	s.stopping = false
	cmdRef := cmd
	doneCh := s.done
	s.mu.Unlock()

	go func() {
		s.wait(cmdRef)
		close(doneCh)
	}()

	s.broadcast()
	return map[string]any{"path": outPath}, nil
}

// wait reaps the recorder child and finalizes state. Exit codes 130 and 2
// are gpu-screen-recorder's graceful SIGINT stops.
func (s *Service) wait(cmd *exec.Cmd) {
	err := cmd.Wait()

	s.mu.Lock()
	wasStopping := s.stopping
	path := s.outPath
	s.cmd = nil
	s.lastPath = path
	s.outPath = ""
	elapsed := time.Since(s.started)
	s.stopping = false
	s.mu.Unlock()

	errMsg := ""
	if err != nil && !wasStopping {
		errMsg = fmt.Sprintf("gpu-screen-recorder exited: %v", err)
	}

	s.broadcastErr(errMsg, elapsed)
}

func (s *Service) stop(_ json.RawMessage) (any, error) {
	s.mu.Lock()
	if s.cmd == nil {
		s.mu.Unlock()
		return map[string]any{"stopped": false}, nil
	}
	s.stopping = true
	proc := s.cmd.Process
	s.mu.Unlock()

	if proc != nil {
		_ = proc.Signal(syscall.SIGINT)
	}
	return map[string]any{"stopped": true}, nil
}

func (s *Service) status(_ json.RawMessage) (any, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	state := map[string]any{
		"recording": s.cmd != nil,
		"mode":      s.mode,
	}
	if s.cmd != nil {
		state["elapsedMs"] = time.Since(s.started).Milliseconds()
		state["path"] = s.outPath
	}
	if s.lastPath != "" {
		state["lastPath"] = s.lastPath
	}
	return state, nil
}

func (s *Service) dir(_ json.RawMessage) (any, error) {
	return map[string]any{"dir": filepath.Join(s.paths.VideosDir(), "Recordings")}, nil
}

func (s *Service) state() map[string]any {
	s.mu.Lock()
	defer s.mu.Unlock()
	state := map[string]any{
		"recording": s.cmd != nil,
		"mode":      s.mode,
	}
	if s.cmd != nil {
		state["elapsedMs"] = time.Since(s.started).Milliseconds()
		state["path"] = s.outPath
	}
	if s.lastPath != "" {
		state["lastPath"] = s.lastPath
	}
	return state
}

func (s *Service) broadcast() {
	s.send("recorder.state", s.state())
}

func (s *Service) broadcastErr(errMsg string, _ time.Duration) {
	state := s.state()
	if errMsg != "" {
		state["error"] = errMsg
	}
	s.send("recorder.state", state)
}

func (s *Service) send(event string, data map[string]any) {
	s.subsMu.Lock()
	subs := append([]*ipc.Subscriber(nil), s.subs...)
	s.subsMu.Unlock()
	for _, sub := range subs {
		sub.Send(event, data)
	}
}

func (s *Service) subscribe(sub *ipc.Subscriber) {
	s.subsMu.Lock()
	s.subs = append(s.subs, sub)
	s.subsMu.Unlock()

	sub.Send("recorder.state", s.state())

	go func() {
		<-sub.StopCh()
		s.subsMu.Lock()
		defer s.subsMu.Unlock()
		for i, x := range s.subs {
			if x == sub {
				s.subs = append(s.subs[:i], s.subs[i+1:]...)
				return
			}
		}
	}()
}

// Close terminates a running recording during daemon shutdown.
func (s *Service) Close() {
	s.mu.Lock()
	if s.cmd == nil || s.cmd.Process == nil {
		s.mu.Unlock()
		return
	}
	proc := s.cmd.Process
	done := s.done
	s.mu.Unlock()

	if proc == nil || done == nil {
		return
	}
	_ = proc.Signal(syscall.SIGINT)
	select {
	case <-done:
	case <-time.After(3 * time.Second):
		_ = proc.Kill()
		<-done
	}
}
