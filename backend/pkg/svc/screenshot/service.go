package screenshot

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"time"

	"ambxst/backend/internal/screenshot"
	"ambxst/backend/pkg/axmon"
	"ambxst/backend/pkg/capture"
	"ambxst/backend/pkg/ipc"
	"ambxst/backend/pkg/paths"
)

type Service struct {
	paths *paths.Paths
	mu    sync.Mutex
}

func NewService(p *paths.Paths) *Service {
	return &Service{paths: p}
}

func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "screenshot",
		Methods: map[string]ipc.HandlerFunc{
			"frame":   s.frame,
			"capture": s.capture,
			"list":    s.list,
			"dir":     s.dir,
		},
	})
}

type frameParams struct {
	Output string `json:"output"`
	Cursor bool   `json:"cursor"`
}

// frame captures a full output to /tmp for the QML freeze overlay.
func (s *Service) frame(params json.RawMessage) (any, error) {
	var p frameParams
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}
	if p.Output == "" {
		return nil, fmt.Errorf("output is required")
	}

	result, closer, err := capture.Frame(p.Output, p.Cursor)
	if err != nil {
		return nil, err
	}
	defer closer()

	outPath := filepath.Join(os.TempDir(), fmt.Sprintf("ambxst_frame_%s.png", p.Output))
	if err := writePNG(result, outPath); err != nil {
		return nil, err
	}
	return map[string]any{
		"path":   outPath,
		"width":  result.Buffer.Width,
		"height": result.Buffer.Height,
	}, nil
}

type captureParams struct {
	Mode      string `json:"mode"`
	Output    string `json:"output"`
	X         int    `json:"x"`
	Y         int    `json:"y"`
	Width     int    `json:"width"`
	Height    int    `json:"height"`
	Clipboard bool   `json:"clipboard"`
	Filename  string `json:"filename"`
	OutPath   string `json:"outPath"`
}

// capture saves a screenshot. Region coordinates are logical global pixels;
// mode "output"/"screen"/"fullscreen" capture whole outputs.
func (s *Service) capture(params json.RawMessage) (any, error) {
	var p captureParams
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}

	var result *screenshot.CaptureResult
	var closer func()
	var err error

	switch p.Mode {
	case "region":
		result, closer, err = capture.Region(p.Output, p.X, p.Y, p.Width, p.Height, false)
	case "output", "screen", "fullscreen":
		name := p.Output
		if name == "" && (p.Mode == "screen" || p.Mode == "fullscreen") {
			monitors, lerr := axmon.List()
			if lerr != nil {
				return nil, lerr
			}
			if m, ok := axmon.Focused(monitors); ok {
				name = m.Name
			}
		}
		if name == "" {
			return nil, fmt.Errorf("no output available")
		}
		result, closer, err = capture.Frame(name, false)
	default:
		return nil, fmt.Errorf("unknown mode %q", p.Mode)
	}
	if err != nil {
		return nil, err
	}
	defer closer()

	var outPath string
	var w, h int
	if p.OutPath != "" {
		outPath = p.OutPath
		if err := writePNG(result, outPath); err != nil {
			return nil, err
		}
		w, h = result.Buffer.Width, result.Buffer.Height
	} else {
		outPath, w, h, err = s.saveCapture(result, p.Filename)
		if err != nil {
			return nil, err
		}
	}

	if p.Clipboard {
		copyFileToClipboard(outPath)
	}

	return map[string]any{"path": outPath, "width": w, "height": h}, nil
}

// list returns monitor geometry from axctl plus wayland-reported scale info.
func (s *Service) list(_ json.RawMessage) (any, error) {
	monitors, err := axmon.List()
	if err != nil {
		return nil, err
	}
	out := make([]map[string]any, 0, len(monitors))
	for _, m := range monitors {
		out = append(out, map[string]any{
			"name":      m.Name,
			"x":         m.X(),
			"y":         m.Y(),
			"width":     m.Width,
			"height":    m.Height,
			"scale":     m.EffectiveScale(),
			"transform": m.Transform(),
			"focused":   m.IsFocused,
		})
	}
	return map[string]any{"outputs": out}, nil
}

func (s *Service) dir(_ json.RawMessage) (any, error) {
	dir := screenshotsDir(s.paths)
	return map[string]any{"dir": dir}, nil
}

func writePNG(result *screenshot.CaptureResult, outPath string) error {
	f, err := os.Create(outPath)
	if err != nil {
		return err
	}
	defer f.Close()
	return screenshot.EncodeBufferPNG(f, result.Buffer, result.Format, nil)
}

func (s *Service) saveCapture(result *screenshot.CaptureResult, filename string) (string, int, int, error) {
	dir := screenshotsDir(s.paths)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", 0, 0, err
	}
	if filename == "" {
		filename = "Screenshot_" + time.Now().Format("2006-01-02-15-04-05") + ".png"
	}
	outPath := filepath.Join(dir, filename)
	if err := writePNG(result, outPath); err != nil {
		return "", 0, 0, err
	}
	return outPath, result.Buffer.Width, result.Buffer.Height, nil
}

func copyFileToClipboard(path string) {
	f, err := os.Open(path)
	if err != nil {
		return
	}
	defer f.Close()
	cmd := exec.Command("wl-copy", "--type", "image/png")
	cmd.Stdin = f
	_ = cmd.Run()
}

func screenshotsDir(p *paths.Paths) string {
	return filepath.Join(p.PicturesDir(), "Screenshots")
}
