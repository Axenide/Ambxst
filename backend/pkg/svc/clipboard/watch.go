package clipboard

import (
	"bufio"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
)

// watchProc runs `wl-paste --watch` (clipboard_watch.sh behaviour) and emits
// clipboard.refresh events. The heavy lift (mime detection, hashing, file
// storage) stays in scripts/clipboard_check.sh — the same dependency set the
// shell used (wl-paste, sqlite3 CLI). Go owns the process lifecycle and the
// event stream; QML no longer spawns watcher processes.
type watchProc struct {
	svc     *Service
	stopCh  chan struct{}
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
		// Mirror clipboard_watch.sh: pipe stdin, run check, print REFRESH_LIST.
		// checkScript() reuses scripts/clipboard_check.sh + clipboard_insert.sh.
		cmd := exec.Command("sh", "-c", "wl-paste --watch bash -c 'cat >/dev/null; "+w.svc.checkScript()+" "+w.checkArgs()+" && echo REFRESH_LIST || echo check-failed >&2'")
		// Put the watcher in its own process group so we can kill the entire
		// group (sh + wl-paste + descendants) on stop. Without this, killing
		// only `sh` leaves wl-paste as a zombie/orphan consuming clipboard
		// subscriptions and memory on every daemon restart.
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
				if strings.TrimSpace(sc.Text()) == "REFRESH_LIST" {
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

// checkScript returns the path of scripts/clipboard_check.sh.
func (s *Service) checkScript() string {
	return s.scriptsDir() + "/clipboard_check.sh"
}

// checkArgs renders the three args the check script needs.
func (w *watchProc) checkArgs() string {
	db := w.svc.paths.ClipboardDB()
	dataDir := w.svc.paths.ClipboardDataDir()
	return shellQuote(db) + " " + shellQuote(w.svc.scriptsDir()+"/clipboard_insert.sh") + " " + shellQuote(dataDir)
}

// scriptsDir finds the repo scripts dir: AMBXST_SHELL (Nix) or the dev
// layout relative to the binary (repo/backend → repo/scripts).
func (s *Service) scriptsDir() string {
	if dir := os.Getenv("AMBXST_SHELL"); dir != "" {
		return dir + "/scripts"
	}
	if exe, err := os.Executable(); err == nil {
		parent := filepath.Dir(exe)
		if filepath.Base(parent) == "backend" {
			return filepath.Join(filepath.Dir(parent), "scripts")
		}
	}
	if cwd, err := os.Getwd(); err == nil {
		if _, statErr := os.Stat(filepath.Join(cwd, "scripts", "clipboard_check.sh")); statErr == nil {
			return filepath.Join(cwd, "scripts")
		}
	}
	return filepath.Join(os.Getenv("HOME"), ".local/src/ambxst", "scripts")
}
