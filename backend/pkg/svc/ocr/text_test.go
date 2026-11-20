package ocr

import (
	"bytes"
	"encoding/json"
	"image"
	"image/color"
	"image/png"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestParseTSVUnicodeAndParagraphs(t *testing.T) {
	data := "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext\n" +
		"5\t1\t1\t1\t1\t1\t10\t10\t30\t20\t80\tПривет\n" +
		"5\t1\t1\t1\t1\t2\t45\t10\t20\t20\t100\tмир\n" +
		"5\t1\t1\t1\t2\t1\t10\t40\t30\t20\t90\t中文\n" +
		"5\t1\t2\t1\t1\t1\t10\t70\t30\t20\t90\t한국어\n"
	lines, err := parseTSV(data)
	if err != nil {
		t.Fatal(err)
	}
	if got := joinLines(lines); got != "Привет мир\n中文\n\n한국어" {
		t.Fatalf("unexpected text: %q", got)
	}
	if lines[0].confidence < 86.6 || lines[0].confidence > 86.7 {
		t.Fatalf("confidence must weight Unicode characters, got %f", lines[0].confidence)
	}
	if lines[0].bounds != image.Rect(10, 10, 65, 30) {
		t.Fatalf("unexpected bounds: %v", lines[0].bounds)
	}
}

func TestParseTSVRejectsInvalidWords(t *testing.T) {
	for _, value := range []string{"NaN", "Inf", "-1", "101", "invalid"} {
		_, err := parseTSV("5\t1\t1\t1\t1\t1\t10\t10\t30\t20\t" + value + "\tword")
		if err == nil {
			t.Fatalf("accepted confidence %q", value)
		}
	}
}

func TestImproveLinesKeepsReadingOrderAndMarginalResults(t *testing.T) {
	original := []textLine{
		{text: "original Chinese", bounds: image.Rect(10, 10, 100, 30), confidence: 50},
		{text: "original Korean", bounds: image.Rect(10, 40, 100, 60), confidence: 80},
	}
	retry := []textLine{
		{text: "worse Korean", bounds: image.Rect(10, 40, 100, 60), confidence: 85},
		{text: "better Chinese", bounds: image.Rect(10, 10, 100, 30), confidence: 95},
	}
	got := improveLines(original, retry)
	if got[0].text != "better Chinese" || got[1].text != "original Korean" {
		t.Fatalf("unexpected choices: %v", got)
	}
	if original[0].text != "original Chinese" {
		t.Fatal("modified the original result")
	}
	// A nearby column must not replace this line, regardless of confidence.
	retry[1].bounds = image.Rect(150, 10, 240, 30)
	if got := improveLines(original, retry); got[0].text != original[0].text {
		t.Fatal("replaced a line from a different column")
	}
}

func TestPreparePNGDarkBackgroundAndAlpha(t *testing.T) {
	for _, background := range []color.NRGBA{{R: 20, G: 20, B: 20, A: 255}, {}} {
		src := image.NewNRGBA(image.Rect(0, 0, 4, 4))
		for y := range 4 {
			for x := range 4 {
				src.SetNRGBA(x, y, background)
			}
		}
		src.SetNRGBA(1, 1, color.NRGBA{R: 230, G: 230, B: 230, A: 255})
		if background.A == 0 {
			src.SetNRGBA(1, 1, color.NRGBA{A: 255})
		}
		var input bytes.Buffer
		if err := png.Encode(&input, src); err != nil {
			t.Fatal(err)
		}
		data, scale, border, err := preparePNG(input.Bytes())
		if err != nil {
			t.Fatal(err)
		}
		result, err := png.Decode(bytes.NewReader(data))
		if err != nil {
			t.Fatal(err)
		}
		gray := result.(*image.Gray)
		if gray.GrayAt(border, border).Y < 230 || gray.GrayAt(border+scale, border+scale).Y > 30 {
			t.Fatal("expected dark strokes on a light background")
		}
		if gray.GrayAt(0, 0).Y != 255 || gray.Bounds().Dx() != 4*scale+2*border {
			t.Fatal("missing border")
		}
	}
}

func TestOCRFileRejectsInvalidInputs(t *testing.T) {
	s := NewService()
	s.SetClipboardCopy(func(string) error { t.Fatal("copied an invalid result"); return nil })
	file := filepath.Join(t.TempDir(), "invalid.png")
	if err := os.WriteFile(file, []byte("not a PNG"), 0600); err != nil {
		t.Fatal(err)
	}
	for _, path := range []string{"relative.png", file, filepath.Dir(file)} {
		params, _ := json.Marshal(map[string]string{"path": path})
		if _, err := s.file(params); err == nil {
			t.Fatalf("accepted invalid path/image %q", path)
		}
	}
}

func TestOCRSavedImageRoundTrip(t *testing.T) {
	if _, err := exec.LookPath("tesseract"); err != nil {
		t.Skip("tesseract is not installed")
	}
	available, err := exec.Command("tesseract", "--list-langs").Output()
	if err != nil || !strings.Contains(string(available), "\neng\n") {
		t.Skip("English model is not installed")
	}
	if _, err := exec.LookPath("pango-view"); err != nil {
		t.Skip("pango-view is not installed")
	}
	path := filepath.Join(t.TempDir(), "screenshot.png")
	if out, err := exec.Command("pango-view", "--no-display", "--pixels", "--font", "sans 16", "--margin", "20", "--text", "Screenshot OCR 1280", "--output", path).CombinedOutput(); err != nil {
		t.Fatalf("render fixture: %v: %s", err, out)
	}
	s := NewService()
	copied := ""
	s.SetClipboardCopy(func(text string) error { copied = text; return nil })
	params, _ := json.Marshal(map[string]string{"path": path, "langs": "eng"})
	result, err := s.file(params)
	if err != nil {
		t.Fatal(err)
	}
	text := result.(map[string]any)["text"].(string)
	if text != "Screenshot OCR 1280" || copied != text {
		t.Fatalf("OCR/clipboard mismatch: text=%q copied=%q", text, copied)
	}
	copied = ""
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := s.recognize(data, "eng", false); err != nil {
		t.Fatal(err)
	}
	if copied != "" {
		t.Fatal("preview copied text before confirmation")
	}
}

func TestCopySelectionPreservesText(t *testing.T) {
	s := NewService()
	var copied string
	s.SetClipboardCopy(func(text string) error { copied = text; return nil })
	params, _ := json.Marshal(map[string]string{"text": " 中文\n한국어 "})
	if _, err := s.copy(params); err != nil {
		t.Fatal(err)
	}
	if copied != " 中文\n한국어 " {
		t.Fatalf("changed selection: %q", copied)
	}
}
