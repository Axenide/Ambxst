package main

import (
	"path/filepath"
	"testing"
)

func TestCandidateBasePathResolvesRelativeToCommand(t *testing.T) {
	directory := t.TempDir()
	t.Chdir(directory)
	if got := candidateBasePath("candidate"); got != filepath.Join(directory, "candidate") {
		t.Fatalf("relative path resolved to %q", got)
	}
	for _, path := range []string{"", "~", "~/candidate", "/srv/candidate"} {
		if got := candidateBasePath(path); got != path {
			t.Fatalf("candidateBasePath(%q) = %q", path, got)
		}
	}
}
