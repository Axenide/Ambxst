package mods

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestChangelog(t *testing.T) {
	root := t.TempDir()
	writeTestFile(t, filepath.Join(root, "CHANGELOG.md"), "# 1.1.0\n\nFix volume controls.\n")
	if text, file := readChangelog(root, ""); !strings.Contains(text, "Fix volume") || file != "CHANGELOG.md" {
		t.Fatalf("missing notes: %q, %q", text, file)
	}
	writeTestFile(t, filepath.Join(root, "docs", "changes.txt"), "Custom notes")
	if text, _ := readChangelog(root, "docs/changes.txt"); text != "Custom notes" {
		t.Fatal("declared path was ignored")
	}
	for _, path := range []string{"../secret", "/etc/passwd", "missing.md"} {
		if text, _ := readChangelog(root, path); text != "" {
			t.Fatalf("read unsafe or missing path %q", path)
		}
	}
	outside := filepath.Join(t.TempDir(), "private.txt")
	writeTestFile(t, outside, "Private data")
	if err := os.Symlink(outside, filepath.Join(root, "linked.md")); err != nil {
		t.Fatal(err)
	}
	if text, _ := readChangelog(root, "linked.md"); text != "" {
		t.Fatal("read notes outside the package")
	}
	writeTestFile(t, filepath.Join(root, "large.md"), strings.Repeat("a", 64*1024+1))
	if text, _ := readChangelog(root, "large.md"); text != "" {
		t.Fatal("accepted oversized notes")
	}
}

func TestUpdateIgnoresUnchangedPackageAtNewRevision(t *testing.T) {
	m, source, _ := updateFixture(t, false)
	git := func(dir string, args ...string) {
		t.Helper()
		cmd := exec.Command("git", append([]string{"-c", "commit.gpgsign=false", "-c", "user.name=Test", "-c", "user.email=test@example.com", "-C", dir}, args...)...)
		if output, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("git %v: %v: %s", args, err, output)
		}
	}
	git(source, "init", "-b", "main")
	git(source, "add", ".")
	git(source, "commit", "-m", "Initial package")
	clone := filepath.Join(t.TempDir(), "clone")
	git(source, "clone", source, clone)
	installed := filepath.Join(m.paths.ModPackagesDir(), "example.update")
	if err := copyTree(clone, installed, nil); err != nil {
		t.Fatal(err)
	}
	state, err := m.loadState()
	if err != nil {
		t.Fatal(err)
	}
	state.Mods[0].Source, state.Mods[0].SourceType, state.Mods[0].Revision = source, "git", gitRevision(source)
	if err := m.saveState(state); err != nil {
		t.Fatal(err)
	}
	git(source, "commit", "--allow-empty", "-m", "Repository metadata change")
	preview, err := m.CheckUpdates(nil, false)
	if err != nil {
		t.Fatal(err)
	}
	if preview.Updates.CanApply || len(preview.Updates.Items) != 1 || preview.Updates.Items[0].State != "current" {
		t.Fatalf("offered unchanged package: %#v", preview.Updates)
	}
	writeTestFile(t, filepath.Join(source, "Feature.qml"), "Item { visible: false }\n")
	writeTestFile(t, filepath.Join(source, "CHANGELOG.md"), "Fix visibility without changing the version.\n")
	git(source, "add", ".")
	git(source, "commit", "-m", "Fix visibility")
	preview, err = m.CheckUpdates(nil, false)
	if err != nil {
		t.Fatal(err)
	}
	if !preview.Updates.CanApply || preview.Updates.Items[0].FromVersion != preview.Updates.Items[0].ToVersion || preview.Updates.Items[0].Changelog == "" {
		t.Fatalf("missing revision update or notes: %#v", preview.Updates)
	}
}
