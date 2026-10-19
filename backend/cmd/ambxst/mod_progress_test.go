package main

import (
	"bytes"
	"errors"
	"strings"
	"testing"
)

func TestModProgressReportsStartAndCompletionWithoutTerminalControlCodes(t *testing.T) {
	var output bytes.Buffer
	progress := newModProgress(&output, "Installing mod", false)
	progress.start()
	progress.finish(nil)

	got := output.String()
	if !strings.HasPrefix(got, "Installing mod...\n") {
		t.Fatalf("progress output starts with %q", got)
	}
	if !strings.Contains(got, "Installing mod... done (") {
		t.Fatalf("progress output does not report completion: %q", got)
	}
	if strings.Contains(got, "\x1b") || strings.Contains(got, "\r") {
		t.Fatalf("non-interactive progress contains terminal control codes: %q", got)
	}
}

func TestModProgressReportsFailure(t *testing.T) {
	var output bytes.Buffer
	progress := newModProgress(&output, "Updating mod", false)
	progress.start()
	progress.finish(errors.New("test failure"))

	if got := output.String(); !strings.Contains(got, "Updating mod... failed (") {
		t.Fatalf("progress output does not report failure: %q", got)
	}
}

func TestModProgressIgnoresCommandsWithoutWork(t *testing.T) {
	var output bytes.Buffer
	progress := newModProgress(&output, modCommandProgressLabel("list"), false)
	progress.start()
	progress.finish(nil)

	if got := output.String(); got != "" {
		t.Fatalf("list command printed progress: %q", got)
	}
}

func TestModProgressLabelsCoverSlowCommands(t *testing.T) {
	commands := []string{
		"install",
		"install-dependencies",
		"enable",
		"disable",
		"remove",
		"update",
		"move",
		"rebuild",
		"rollback",
		"check-updates",
		"apply-updates",
		"check-compatibility",
	}
	for _, command := range commands {
		label := modCommandProgressLabel(command)
		if label == "" {
			label = modUpdateCommandProgressLabel(command)
		}
		if label == "" {
			t.Errorf("command %q has no progress label", command)
		}
	}
}
