package main

import (
	"fmt"
	"io"
	"os"
	"sync"
	"time"
)

const modProgressInterval = 120 * time.Millisecond

type modProgress struct {
	label       string
	writer      io.Writer
	interactive bool
	started     time.Time
	stop        chan struct{}
	done        chan struct{}
	once        sync.Once
}

func startModProgress(label string) *modProgress {
	progress := newModProgress(os.Stderr, label, stderrIsTerminal())
	progress.start()
	return progress
}

func newModProgress(writer io.Writer, label string, interactive bool) *modProgress {
	return &modProgress{
		label:       label,
		writer:      writer,
		interactive: interactive,
		started:     time.Now(),
		stop:        make(chan struct{}),
		done:        make(chan struct{}),
	}
}

func (p *modProgress) start() {
	if p.label == "" {
		close(p.done)
		return
	}
	if !p.interactive {
		fmt.Fprintf(p.writer, "%s...\n", p.label)
		close(p.done)
		return
	}

	frames := []byte{'|', '/', '-', '\\'}
	fmt.Fprintf(p.writer, "\r%c %s... 0s", frames[0], p.label)
	go func() {
		defer close(p.done)
		ticker := time.NewTicker(modProgressInterval)
		defer ticker.Stop()
		frame := 1
		for {
			select {
			case <-ticker.C:
				fmt.Fprintf(p.writer, "\r%c %s... %s", frames[frame%len(frames)], p.label, progressElapsed(p.started))
				frame++
			case <-p.stop:
				return
			}
		}
	}()
}

func (p *modProgress) finish(err error) {
	p.once.Do(func() {
		if p.label == "" {
			return
		}
		if p.interactive {
			close(p.stop)
			<-p.done
		}
		result := "done"
		if err != nil {
			result = "failed"
		}
		if p.interactive {
			fmt.Fprint(p.writer, "\r\x1b[2K")
		}
		fmt.Fprintf(p.writer, "%s... %s (%s)\n", p.label, result, progressElapsed(p.started))
	})
}

func progressElapsed(started time.Time) string {
	elapsed := time.Since(started)
	if elapsed < time.Second {
		return "<1s"
	}
	return fmt.Sprintf("%ds", int(elapsed.Round(time.Second).Seconds()))
}

func stderrIsTerminal() bool {
	info, err := os.Stderr.Stat()
	return err == nil && info.Mode()&os.ModeCharDevice != 0 && os.Getenv("TERM") != "dumb"
}

func modCommandProgressLabel(command string) string {
	switch command {
	case "install":
		return "Installing mod"
	case "install-dependencies":
		return "Installing dependencies"
	case "enable":
		return "Enabling mod"
	case "disable":
		return "Disabling mod"
	case "remove":
		return "Removing mod"
	case "update":
		return "Updating mod"
	case "move":
		return "Changing mod order"
	case "rebuild":
		return "Rebuilding mods"
	case "rollback":
		return "Rolling back mods"
	case "bypass":
		return "Updating version check"
	default:
		return ""
	}
}

func modUpdateCommandProgressLabel(command string) string {
	switch command {
	case "check-updates":
		return "Checking for mod updates"
	case "apply-updates":
		return "Applying mod updates"
	case "check-interval":
		return "Updating check interval"
	case "auto-update":
		return "Updating automatic install policy"
	case "periodic-checks":
		return "Updating scheduled checks"
	case "diagnostics":
		return "Collecting mod diagnostics"
	case "check-compatibility":
		return "Checking mod compatibility"
	case "base":
		return "Switching to the base shell"
	default:
		return ""
	}
}
