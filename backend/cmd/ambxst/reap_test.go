package main

import (
	"os/exec"
	"testing"
	"time"
)

func TestStartReapedReapsChild(t *testing.T) {
	cmd := exec.Command("true")
	done, err := startReaped(cmd)
	if err != nil {
		t.Fatal(err)
	}
	select {
	case <-done:
	case <-time.After(5 * time.Second):
		t.Fatal("child was not reaped")
	}
	if cmd.ProcessState == nil || !cmd.ProcessState.Exited() {
		t.Fatal("expected Wait to have collected the exit status")
	}
}

func TestStartReapedStartFailure(t *testing.T) {
	if _, err := startReaped(exec.Command("/nonexistent/ambxst-test-binary")); err == nil {
		t.Fatal("expected start error")
	}
}
