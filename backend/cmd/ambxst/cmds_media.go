package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
)

var mediaVideoExts = map[string]bool{
	".mp4": true, ".webm": true, ".mov": true, ".avi": true, ".mkv": true, ".gif": true,
}

var mediaImageExts = map[string]bool{
	".jpg": true, ".jpeg": true, ".png": true, ".webp": true, ".tif": true, ".tiff": true, ".bmp": true,
}

func lookPathOr(name string) string {
	if p, err := exec.LookPath(name); err == nil {
		return p
	}
	return name
}

func runInput(cmd *exec.Cmd, input []byte) ([]byte, error) {
	if len(input) > 0 {
		cmd.Stdin = bytes.NewReader(input)
	}
	return cmd.CombinedOutput()
}

// --- lockwall: extract first frame from video/GIF wallpaper ---

func runLockWall(args []string) int {
	if len(args) < 2 {
		fmt.Fprintln(os.Stderr, "Usage: ambxst lockwall <wallpaper_path> <data_path>")
		return 1
	}
	wallpaperPath, dataPath := args[0], args[1]
	wallpaper, err := filepath.Abs(wallpaperPath)
	if err != nil {
		return 1
	}
	if _, err := os.Stat(wallpaper); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: Wallpaper not found: %s\n", wallpaper)
		return 1
	}
	ext := strings.ToLower(filepath.Ext(wallpaper))
	if !mediaVideoExts[ext] && !strings.EqualFold(ext, ".gif") {
		return 0
	}

	lockscreenDir := filepath.Join(dataPath, "lockscreen")
	os.MkdirAll(lockscreenDir, 0o755)
	entries, _ := os.ReadDir(lockscreenDir)
	for _, e := range entries {
		if !e.IsDir() {
			os.Remove(filepath.Join(lockscreenDir, e.Name()))
		}
	}

	output := filepath.Join(lockscreenDir, filepath.Base(wallpaper)+".jpg")
	out, err := exec.Command("ffmpeg", "-y", "-i", wallpaper,
		"-vframes", "1", "-q:v", "2", "-f", "image2", output).CombinedOutput()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to extract frame: %s\n%s\n", err, out)
		return 1
	}
	return 0
}

// --- thumbnail generation (shared by thumbs/dthumbs) ---

type thumbWorker struct {
	size       int
	thumbDir   string
	wallPath   string
	fallback   string
	workerNext []string // not used; kept simple
}

func needsThumbnail(filePath, thumbPath string) bool {
	if _, err := os.Stat(thumbPath); err != nil {
		return true
	}
	fi, err1 := os.Stat(filePath)
	ti, err2 := os.Stat(thumbPath)
	if err1 != nil || err2 != nil {
		return true
	}
	return fi.ModTime().After(ti.ModTime())
}

func generateThumb(filePath, thumbPath string, size int) error {
	if err := os.MkdirAll(filepath.Dir(thumbPath), 0o755); err != nil {
		return err
	}
	ext := strings.ToLower(filepath.Ext(filePath))
	scale := fmt.Sprintf("%d:%d:force_original_aspect_ratio=increase,crop=%d:%d", size, size, size, size)
	if mediaVideoExts[ext] {
		_, err := exec.Command("ffmpeg", "-y", "-i", filePath,
			"-ss", "00:00:01", "-vframes", "1", "-vf", scale, "-q:v", "2", "-f", "image2", thumbPath).Output()
		return err
	}
	_, err := exec.Command("convert", filePath,
		"-resize", fmt.Sprintf("%dx%d^", size, size),
		"-gravity", "center", "-extent", fmt.Sprintf("%dx%d", size, size),
		"-quality", "85", thumbPath).Output()
	return err
}

func runThumbs(args []string, size int, recursive bool) int {
	// args: <config_path> <cache_base_path> [fallback_wall_path]
	if len(args) < 2 {
		fmt.Fprintln(os.Stderr, "Usage: ambxst thumbs <config_path> <cache_base_path> [fallback_wall_path]")
		fmt.Fprintln(os.Stderr, "       ambxst dthumbs <desktop_path> <cache_dir>")
		return 1
	}
	configPath, cacheBase := args[0], args[1]
	var fallback string
	if len(args) > 2 {
		fallback = args[2]
	}

	var wallPath string
	mediaFiles := []string{}
	if recursive {
		data, err := os.ReadFile(configPath)
		if err != nil {
			fmt.Fprintf(os.Stderr, "ERROR: Config file not found: %s\n", configPath)
			return 1
		}
		var cfg struct {
			WallPath string `json:"wallPath"`
		}
		json.Unmarshal(data, &cfg)
		wallPath = cfg.WallPath
		if wallPath == "" {
			wallPath = fallback
		}
		if wallPath == "" {
			fmt.Fprintln(os.Stderr, "ERROR: wallPath not found in config")
			return 1
		}
		wallPath, _ = filepath.Abs(wallPath)
		st, err := os.Stat(wallPath)
		if err != nil || !st.IsDir() {
			fmt.Fprintf(os.Stderr, "ERROR: Wallpaper directory not found: %s\n", wallPath)
			return 1
		}
		filepath.Walk(wallPath, func(path string, info os.FileInfo, err error) error {
			if err != nil || info.IsDir() {
				return nil
			}
			rel, _ := filepath.Rel(wallPath, path)
			for _, part := range strings.Split(rel, string(filepath.Separator))[:max(0, len(strings.Split(rel, string(filepath.Separator)))-1)] {
				if strings.HasPrefix(part, ".") {
					return nil
				}
			}
			ext := strings.ToLower(filepath.Ext(path))
			if mediaVideoExts[ext] || mediaImageExts[ext] {
				mediaFiles = append(mediaFiles, path)
			}
			return nil
		})
	} else {
		wallPath = configPath
		if wallPath == "" {
			fmt.Fprintln(os.Stderr, "ERROR: desktop path not found")
			return 1
		}
		wallPath, _ = filepath.Abs(wallPath)
		st, err := os.Stat(wallPath)
		if err != nil || !st.IsDir() {
			fmt.Fprintf(os.Stderr, "ERROR: Desktop path not found: %s\n", wallPath)
			return 1
		}
		entries, _ := os.ReadDir(wallPath)
		for _, e := range entries {
			if e.IsDir() {
				continue
			}
			ext := strings.ToLower(filepath.Ext(e.Name()))
			if mediaVideoExts[ext] || mediaImageExts[ext] {
				mediaFiles = append(mediaFiles, filepath.Join(wallPath, e.Name()))
			}
		}
	}

	thumbDir := filepath.Join(cacheBase, "thumbnails")
	if !recursive {
		thumbDir = cacheBase
	}
	os.MkdirAll(thumbDir, 0o755)

	type job struct{ file, thumb string }
	jobs := []job{}
	for _, f := range mediaFiles {
		rel, _ := filepath.Rel(wallPath, f)
		thumbName := filepath.Base(f) + ".jpg"
		thumb := filepath.Join(thumbDir, filepath.Dir(rel), thumbName)
		if !recursive {
			thumb = filepath.Join(thumbDir, strings.ReplaceAll(filepath.Base(f), filepath.Ext(f), "")+filepath.Ext(f)+".jpg")
		}
		if needsThumbnail(f, thumb) {
			jobs = append(jobs, job{f, thumb})
		}
	}
	if len(jobs) == 0 {
		return 0
	}

	workers := 4
	if workers > len(jobs) {
		workers = len(jobs)
	}
	var wg sync.WaitGroup
	ch := make(chan job)
	for w := 0; w < workers; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := range ch {
				if err := generateThumb(j.file, j.thumb, size); err != nil {
					fmt.Fprintf(os.Stderr, "Failed: %s: %v\n", j.file, err)
				}
			}
		}()
	}
	for _, j := range jobs {
		ch <- j
	}
	close(ch)
	wg.Wait()
	return 0
}

// helper exists to keep bytes import used when inputs are empty
func noopRun() {}
