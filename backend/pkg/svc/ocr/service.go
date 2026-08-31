package ocr

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"

	"ambxst/backend/pkg/capture"
	"ambxst/backend/pkg/ipc"
)

type Service struct{}

func NewService() *Service {
	return &Service{}
}

func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "ocr",
		Methods: map[string]ipc.HandlerFunc{
			"text":    s.text,
			"barcode": s.barcode,
		},
	})
}

type rectParams struct {
	X      int    `json:"x"`
	Y      int    `json:"y"`
	Width  int    `json:"width"`
	Height int    `json:"height"`
	Langs  string `json:"langs,omitempty"`
}

func (s *Service) text(params json.RawMessage) (any, error) {
	var p rectParams
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}

	pngBytes, closer, err := capture.RegionPNG("", p.X, p.Y, p.Width, p.Height)
	if err != nil {
		return nil, err
	}
	defer closer()

	langs := p.Langs
	if strings.TrimSpace(langs) == "" {
		langs = "eng+spa"
	}

	cmd := exec.Command("tesseract", "-", "-", "-l", langs)
	cmd.Stdin = bytes.NewReader(pngBytes)
	out, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("tesseract: %w", err)
	}
	text := strings.TrimSpace(string(out))
	if text != "" {
		copyText(text)
	}
	return map[string]any{"text": text}, nil
}

func (s *Service) barcode(params json.RawMessage) (any, error) {
	var p rectParams
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}

	pngBytes, closer, err := capture.RegionPNG("", p.X, p.Y, p.Width, p.Height)
	if err != nil {
		return nil, err
	}
	defer closer()

	content, err := decodeBarcode(pngBytes)
	if err != nil {
		return nil, err
	}
	if content != "" {
		copyText(content)
	}
	return map[string]any{"content": content}, nil
}

// copyText spawns wl-copy detached: its clipboard-serving child inherits
// nothing and the handler returns immediately.
func copyText(text string) {
	cmd := exec.Command("wl-copy", "--type", "text/plain")
	cmd.Stdin = strings.NewReader(text)
	cmd.Stdout = nil
	cmd.Stderr = nil
	if err := cmd.Start(); err != nil {
		return
	}
	go func() { _ = cmd.Wait() }()
}
