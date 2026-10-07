package ocr

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"

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
			"file":    s.file,
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

	return s.recognize(pngBytes, p.Langs)
}

// file recognizes the saved screenshot, without recapturing the desktop.
func (s *Service) file(params json.RawMessage) (any, error) {
	var p struct {
		Path  string `json:"path"`
		Langs string `json:"langs"`
	}
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}
	if !filepath.IsAbs(p.Path) {
		return nil, fmt.Errorf("screenshot path must be absolute")
	}
	info, err := os.Stat(p.Path)
	if err != nil {
		return nil, fmt.Errorf("read screenshot: %w", err)
	}
	if !info.Mode().IsRegular() {
		return nil, fmt.Errorf("screenshot must be a regular file")
	}
	f, err := os.Open(p.Path)
	if err != nil {
		return nil, fmt.Errorf("read screenshot: %w", err)
	}
	defer f.Close()
	info, err = f.Stat()
	if err != nil {
		return nil, err
	}
	if !info.Mode().IsRegular() {
		return nil, fmt.Errorf("screenshot must be a regular file")
	}
	const maxBytes = 32 << 20
	data, err := io.ReadAll(io.LimitReader(f, maxBytes+1))
	if err != nil {
		return nil, err
	}
	if len(data) > maxBytes {
		return nil, fmt.Errorf("screenshot exceeds 32 MiB")
	}
	return s.recognize(data, p.Langs)
}

func (s *Service) recognize(pngBytes []byte, langs string) (any, error) {
	text, err := recognizePNG(pngBytes, langs)
	if err != nil {
		return nil, err
	}
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
