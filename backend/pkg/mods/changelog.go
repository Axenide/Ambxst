package mods

import (
	"io"
	"os"
	"path/filepath"
	"strings"
	"unicode/utf8"
)

// Read author notes from the reviewed package, without fetching external pages.
// Display the file as plain text so package content cannot load remote resources.
func readChangelog(root, declared string) (string, string) {
	names := []string{"CHANGELOG.md", "CHANGELOG.txt", "changelog.md", "changelog.txt"}
	if declared != "" {
		names = []string{declared}
	}
	for _, name := range names {
		path, err := safeJoin(root, name)
		if err != nil {
			continue
		}
		resolved, err := filepath.EvalSymlinks(path)
		base, baseErr := filepath.EvalSymlinks(root)
		relative, relErr := filepath.Rel(base, resolved)
		if err != nil || baseErr != nil || relErr != nil || !isSafeRelative(relative) || strings.HasPrefix(relative, ".git"+string(filepath.Separator)) {
			continue
		}
		file, err := os.Open(path)
		if err != nil {
			continue
		}
		info, err := file.Stat()
		if err != nil || !info.Mode().IsRegular() {
			file.Close()
			continue
		}
		data, err := io.ReadAll(io.LimitReader(file, 64*1024+1))
		file.Close()
		if err != nil || len(data) > 64*1024 || !utf8.Valid(data) || strings.ContainsRune(string(data), 0) {
			continue
		}
		if notes := strings.TrimSpace(string(data)); notes != "" {
			return notes, name
		}
	}
	return "", ""
}
