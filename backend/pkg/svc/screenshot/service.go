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

	result, closer, err := s.captureUpright(p.Output, p.Cursor)
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
		result, closer, err = s.captureRegion(p)
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
		result, closer, err = s.captureUpright(name, false)
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

// captureUpright connects, captures one output raw and normalizes it.
// The returned closer releases the buffer; call before returning.
func (s *Service) captureUpright(outputName string, cursor bool) (*screenshot.CaptureResult, func(), error) {
	engine := screenshot.NewEngine(cursorMode(cursor))
	if err := engine.Connect(); err != nil {
		return nil, func() {}, err
	}

	raw, err := engine.CaptureOutputFrame(outputName)
	if err != nil {
		engine.Close()
		return nil, func() {}, err
	}

	result, err := screenshot.Upright(raw)
	if err != nil {
		raw.Buffer.Close()
		engine.Close()
		return nil, func() {}, err
	}

	closer := func() {
		result.Buffer.Close()
		engine.Close()
	}
	return result, closer, nil
}

// captureRegion resolves the owning monitor for a logical global rect and
// crops the captured output at physical scale.
func (s *Service) captureRegion(p captureParams) (*screenshot.CaptureResult, func(), error) {
	rect := screenshot.Region{
		X:      int32(p.X),
		Y:      int32(p.Y),
		Width:  int32(p.Width),
		Height: int32(p.Height),
	}
	if rect.IsEmpty() {
		return nil, nil, fmt.Errorf("empty region")
	}

	monitors, err := axmon.List()
	if err != nil {
		return nil, nil, err
	}

	name := p.Output
	if name == "" {
		m, ok := axmon.Containing(monitors, int(rect.X+rect.Width/2), int(rect.Y+rect.Height/2))
		if !ok {
			m, ok = axmon.Containing(monitors, int(rect.X), int(rect.Y))
		}
		if !ok {
			return nil, nil, fmt.Errorf("region outside all outputs")
		}
		name = m.Name
	}
	mon, ok := axmon.FindByName(monitors, name)
	if !ok {
		return nil, nil, fmt.Errorf("output %q not found", name)
	}

	result, closer, err := s.captureUpright(name, false)
	if err != nil {
		return nil, nil, err
	}

	scale := mon.EffectiveScale()
	localX := int(float64(int(rect.X)-mon.X())*scale + 0.5)
	localY := int(float64(int(rect.Y)-mon.Y())*scale + 0.5)
	w := int(float64(rect.Width)*scale + 0.5)
	h := int(float64(rect.Height)*scale + 0.5)

	cropped, err := screenshot.CropBuffer(result, int32(localX), int32(localY), int32(w), int32(h))
	if err != nil {
		closer()
		return nil, nil, err
	}

	combinedCloser := func() {
		cropped.Buffer.Close()
		closer()
	}
	return cropped, combinedCloser, nil
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

func cursorMode(on bool) screenshot.CursorMode {
	if on {
		return screenshot.CursorOn
	}
	return screenshot.CursorOff
}

func screenshotsDir(p *paths.Paths) string {
	return filepath.Join(p.PicturesDir(), "Screenshots")
}
