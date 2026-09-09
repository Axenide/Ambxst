package clipboard

import (
	"bufio"
	"bytes"
	"log"
	"os"
	"os/exec"
	"strings"
	"syscall"
)

// watchProc runs `wl-paste --watch` and handles every clipboard change
// natively in Go (mime detection, hashing, blob storage) — the previous
// shell pipeline (scripts/clipboard_check.sh + clipboard_insert.sh +
// sqlite3 CLI) is gone. Each change that yields content triggers an
// upsert in the unpinned store and a clipboard.refresh event.
type watchProc struct {
	svc    *Service
	stopCh chan struct{}
}

type eventSender interface {
	Send(service string, data any)
}

// ensureWatcher starts the watcher once.
func (s *Service) ensureWatcher(sub eventSender) {
	if s.watch != nil {
		return
	}
	w := &watchProc{svc: s, stopCh: make(chan struct{})}
	s.watch = w
	go w.run(sub)
}

func (w *watchProc) stop() {
	select {
	case <-w.stopCh:
	default:
		close(w.stopCh)
	}
}

func (w *watchProc) run(sub eventSender) {
	if _, err := exec.LookPath("wl-paste"); err != nil {
		return
	}
	for {
		select {
		case <-w.stopCh:
			return
		default:
		}
		cmd := exec.Command("wl-paste", "--watch", "sh", "-c", "cat >/dev/null; echo REFRESH_LIST")
		// Put the watcher in its own process group so we can kill the
		// entire group (sh + wl-paste + descendants) on stop. Without
		// this, killing only `sh` leaves wl-paste as a zombie/orphan
		// consuming clipboard subscriptions and memory on every daemon
		// restart.
		cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
		stdout, err := cmd.StdoutPipe()
		if err != nil {
			return
		}
		if err := cmd.Start(); err != nil {
			return
		}
		done := make(chan struct{})
		go func() {
			defer close(done)
			sc := bufio.NewScanner(stdout)
			for sc.Scan() {
				if strings.TrimSpace(sc.Text()) != "REFRESH_LIST" {
					continue
				}
				if w.svc.checkAndInsert() {
					sub.Send("clipboard.refresh", map[string]any{"ok": true})
				}
			}
		}()
		select {
		case <-w.stopCh:
			// Kill the whole process group (negative PID = pgid).
			if cmd.Process != nil {
				_ = syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL)
			}
			cmd.Wait()
			return
		case <-done:
		}
		cmd.Wait()
	}
}

// checkAndInsert captures the current clipboard content (uri-list, image
// or plain text — in that priority order) and upserts it into the
// unpinned store. Returns whether content was captured.
func (s *Service) checkAndInsert() bool {
	// Files first (text/uri-list).
	if out, err := exec.Command("wl-paste", "--type", "text/uri-list").Output(); err == nil {
		content := bytes.ReplaceAll(out, []byte("\r"), nil)
		size := int64(0)
		if p := strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(string(content)), "file://")); p != "" {
			if fi, err := os.Stat(p); err == nil {
				size = fi.Size()
			}
		}
		return s.insertUnpinned("text/uri-list", content, false, size)
	}

	// Images.
	if types, err := exec.Command("wl-paste", "--list-types").Output(); err == nil {
		for _, line := range strings.Split(string(types), "\n") {
			mime := strings.TrimSpace(line)
			if !strings.HasPrefix(mime, "image/") {
				continue
			}
			data, err := exec.Command("wl-paste", "--type", mime).Output()
			if err == nil && len(data) > 0 {
				return s.insertUnpinned(mime, data, true, int64(len(data)))
			}
		}
	}

	// Plain text — prefer UTF-8 charset to preserve unicode characters.
	for _, mime := range []string{"text/plain;charset=utf-8", "text/plain"} {
		if out, err := exec.Command("wl-paste", "--type", mime).Output(); err == nil {
			content := bytes.ReplaceAll(out, []byte("\r"), nil)
			return s.insertUnpinned(mime, content, false, int64(len(content)))
		}
	}
	return false
}

func (s *Service) insertUnpinned(mime string, content []byte, isImage bool, size int64) bool {
	st, err := s.getStore()
	if err != nil {
		log.Printf("[clipboard] insert: %v", err)
		return false
	}
	inserted, err := st.insertUnpinned(mime, content, isImage, size)
	if err != nil {
		log.Printf("[clipboard] insert: %v", err)
	}
	return inserted
}
