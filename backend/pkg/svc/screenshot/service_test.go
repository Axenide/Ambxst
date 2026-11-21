package screenshot

import (
	"os"
	"path/filepath"
	"testing"

	"ambxst/backend/internal/screenshot"
	"ambxst/backend/pkg/paths"
)

func newFrameResult(t *testing.T) *screenshot.CaptureResult {
	t.Helper()
	buf, err := screenshot.CreateShmBuffer(1, 1, 4)
	if err != nil {
		t.Fatalf("create shm buffer: %v", err)
	}
	t.Cleanup(func() { _ = buf.Close() })
	return &screenshot.CaptureResult{Buffer: buf, Format: uint32(screenshot.FormatXBGR8888)}
}

// Freeze frames are full screen captures, so their directory must be the
// private per-user runtime directory, owner-only, and tightened again when
// it already exists with looser permissions.
func TestFrameDirIsOwnerOnlyPerUserDir(t *testing.T) {
	runtime := t.TempDir()
	t.Setenv("XDG_RUNTIME_DIR", runtime)

	s := NewService(paths.New())
	dir, err := s.frameDir()
	if err != nil {
		t.Fatalf("frameDir: %v", err)
	}
	if want := filepath.Join(runtime, "ambxst"); dir != want {
		t.Fatalf("frameDir = %q, want %q", dir, want)
	}
	fi, err := os.Stat(dir)
	if err != nil {
		t.Fatal(err)
	}
	if fi.Mode().Perm() != 0o700 {
		t.Fatalf("frame dir mode = %o, want 700", fi.Mode().Perm())
	}

	if err := os.Chmod(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	if _, err := s.frameDir(); err != nil {
		t.Fatalf("frameDir after chmod: %v", err)
	}
	fi, err = os.Stat(dir)
	if err != nil {
		t.Fatal(err)
	}
	if fi.Mode().Perm() != 0o700 {
		t.Fatalf("pre-existing frame dir was not tightened: mode %o", fi.Mode().Perm())
	}
}

func TestFrameDirFallsBackToCacheDir(t *testing.T) {
	home := t.TempDir()
	t.Setenv("XDG_RUNTIME_DIR", "")
	t.Setenv("HOME", home)
	t.Setenv("XDG_CACHE_HOME", "")

	s := NewService(paths.New())
	dir, err := s.frameDir()
	if err != nil {
		t.Fatalf("frameDir: %v", err)
	}
	if want := filepath.Join(home, ".cache", "ambxst", "runtime"); dir != want {
		t.Fatalf("frameDir = %q, want %q", dir, want)
	}
}

// The frame file itself must be owner-only.
func TestWriteFramePNGIsOwnerOnly(t *testing.T) {
	path := filepath.Join(t.TempDir(), "ambxst_frame_test.png")
	if err := writeFramePNG(newFrameResult(t), path); err != nil {
		t.Fatalf("writeFramePNG: %v", err)
	}
	fi, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if fi.Mode().Perm() != 0o600 {
		t.Fatalf("frame file mode = %o, want 600", fi.Mode().Perm())
	}
}

// A pre-planted symlink at the destination must not be followed.
func TestWriteFramePNGRefusesSymlink(t *testing.T) {
	dir := t.TempDir()
	victim := filepath.Join(dir, "victim")
	if err := os.WriteFile(victim, []byte("original content"), 0o644); err != nil {
		t.Fatal(err)
	}
	link := filepath.Join(dir, "ambxst_frame_link.png")
	if err := os.Symlink(victim, link); err != nil {
		t.Fatal(err)
	}
	if err := writeFramePNG(newFrameResult(t), link); err == nil {
		t.Fatal("writeFramePNG followed a symlink, expected refusal")
	}
	data, err := os.ReadFile(victim)
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != "original content" {
		t.Fatalf("victim file was modified through the symlink (%d bytes)", len(data))
	}
}
