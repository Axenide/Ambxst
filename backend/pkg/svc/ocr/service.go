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

type Service struct {
	// copyFn routes OCR results to the clipboard service (native
	// data-control owner); wired by the daemon at boot.
	copyFn func(text string) error
}

func NewService() *Service {
	return &Service{}
}

// SetClipboardCopy wires the clipboard copy path (daemon boot).
func (s *Service) SetClipboardCopy(fn func(text string) error) {
	s.copyFn = fn
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
		s.copyText(text)
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
		s.copyText(content)
	}
	return map[string]any{"content": content}, nil
}

// copyText routes the text to the clipboard service when wired; without
// the daemon wiring there is nothing to own the selection.
func (s *Service) copyText(text string) {
	if s.copyFn == nil {
		return
	}
	_ = s.copyFn(text)
}
