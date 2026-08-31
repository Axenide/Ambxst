package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// chatlist lists AI chat JSONs by mtime desc, printing "id|title" lines.
func runChatList(args []string) int {
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "Usage: ambxst chatlist <chat_dir>")
		return 1
	}
	chatDir := args[0]
	os.MkdirAll(chatDir, 0o755)
	entries, err := os.ReadDir(chatDir)
	if err != nil {
		return 1
	}
	type chatFile struct {
		name  string
		mtime int64
	}
	files := []chatFile{}
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".json") {
			info, err := e.Info()
			if err == nil {
				files = append(files, chatFile{e.Name(), info.ModTime().UnixMilli()})
			}
		}
	}
	sort.Slice(files, func(i, j int) bool { return files[i].mtime > files[j].mtime })

	for _, f := range files {
		id := strings.TrimSuffix(f.name, ".json")
		title := "New Chat"
		if data, err := os.ReadFile(filepath.Join(chatDir, f.name)); err == nil {
			var msgs []struct {
				Role    string `json:"role"`
				Content string `json:"content"`
			}
			if json.Unmarshal(data, &msgs) == nil {
				for _, m := range msgs {
					if m.Role == "user" {
						t := strings.ReplaceAll(m.Content, "\n", " ")
						t = strings.TrimSpace(t)
						title = t
						if len(t) > 40 {
							title = t[:40] + "..."
						}
						break
					}
				}
			}
		}
		fmt.Printf("%s|%s\n", id, title)
	}
	return 0
}

// writeshader writes a GLSL shader file, cleaning the shader dir and legacy
// tint files first (replaces the inline python in Wallpaper.qml).
// Usage: ambxst writeshader <shader_dir> <shader_file> <content>
func runWriteShader(args []string) int {
	if len(args) < 3 {
		fmt.Fprintln(os.Stderr, "Usage: ambxst writeshader <shader_dir> <shader_file> <content>")
		return 1
	}
	shaderDir, shaderFile := args[0], args[1]
	content := args[2]

	os.MkdirAll(shaderDir, 0o755)
	entries, _ := os.ReadDir(shaderDir)
	for _, e := range entries {
		if !e.IsDir() {
			os.Remove(filepath.Join(shaderDir, e.Name()))
		}
	}
	if err := os.WriteFile(shaderFile, []byte(content), 0o644); err != nil {
		fmt.Fprintf(os.Stderr, "Failed to write shader: %v\n", err)
		return 1
	}
	// Remove legacy tint files in parent dir.
	legacyDir := filepath.Dir(shaderDir)
	for _, legacy := range []string{"mpv_tint_0.glsl", "mpv_tint_1.glsl", "mpv_tint.glsl"} {
		os.Remove(filepath.Join(legacyDir, legacy))
	}
	fmt.Printf("Wrote shader to %s\n", shaderFile)
	return 0
}
