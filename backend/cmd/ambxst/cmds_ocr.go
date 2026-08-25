package main

import (
	"bytes"
	"fmt"
	"os/exec"
	"strconv"
	"strings"

	"ambxst/backend/internal/screenshot"
	"ambxst/backend/pkg/capture"
)

// --- OCR / QR: slurp region -> screencopy crop -> engine stdin ---

func runOCR(args []string) int {
	for _, dep := range []string{"slurp", "tesseract", "wl-copy", "notify-send"} {
		if _, err := exec.LookPath(dep); err != nil {
			notifyCritical("OCR Error", "Missing dependency: "+dep)
			return 1
		}
	}

	region, ok := slurpRegion()
	if !ok {
		return 0
	}

	png, err := captureRegionPNG(region)
	if err != nil {
		notifyCritical("OCR Error", err.Error())
		return 1
	}

	langs := "eng+spa"
	if len(args) > 0 && strings.TrimSpace(args[0]) != "" {
		langs = strings.TrimSpace(args[0])
	}

	cmd := exec.Command("tesseract", "stdin", "stdout", "-l", langs)
	cmd.Stdin = bytes.NewReader(png)
	out, err := cmd.Output()
	if err != nil {
		notifyCritical("OCR Error", "tesseract failed")
		return 1
	}

	text := strings.TrimSpace(string(out))
	if text == "" {
		exec.Command("notify-send", "OCR Result", "No text detected", "-u", "low").Run()
		return 0
	}

	copyText(text)
	exec.Command("notify-send", "OCR Result", "Text copied to clipboard").Run()
	return 0
}

func runQR() int {
	for _, dep := range []string{"slurp", "wl-copy", "notify-send"} {
		if _, err := exec.LookPath(dep); err != nil {
			notifyCritical("QR Scan Error", "Missing dependency: "+dep)
			return 1
		}
	}

	region, ok := slurpRegion()
	if !ok {
		return 0
	}

	png, err := captureRegionPNG(region)
	if err != nil {
		notifyCritical("QR Scan Error", err.Error())
		return 1
	}

	result, err := decodeBarcode(png)
	if err != nil || strings.TrimSpace(result) == "" {
		exec.Command("notify-send", "QR/Barcode Result", "No code detected", "-u", "low").Run()
		return 0
	}

	copyText(result)
	exec.Command("notify-send", "QR/Barcode Result", "Content copied to clipboard").Run()
	return 0
}

type screenRegion struct {
	x, y, w, h int
}

// slurpRegion shows the compositor's interactive selector. Returns
// cancelled=false-ok when the user dismisses it.
func slurpRegion() (screenRegion, bool) {
	out, err := exec.Command("slurp").Output()
	if err != nil || strings.TrimSpace(string(out)) == "" {
		return screenRegion{}, false
	}
	fields := strings.Fields(strings.TrimSpace(string(out)))
	if len(fields) < 2 {
		return screenRegion{}, false
	}
	xy := strings.Split(fields[0], ",")
	wh := strings.Split(fields[1], "x")
	if len(xy) != 2 || len(wh) != 2 {
		return screenRegion{}, false
	}
	var r screenRegion
	r.x, _ = strconv.Atoi(xy[0])
	r.y, _ = strconv.Atoi(xy[1])
	r.w, _ = strconv.Atoi(wh[0])
	r.h, _ = strconv.Atoi(wh[1])
	if r.w <= 0 || r.h <= 0 {
		return screenRegion{}, false
	}
	return r, true
}

// captureRegionPNG captures a logical-global rect through the shared engine.
func captureRegionPNG(r screenRegion) ([]byte, error) {
	result, closer, err := capture.Region("", r.x, r.y, r.w, r.h, false)
	if err != nil {
		return nil, err
	}
	defer closer()

	if screenshot.PixelFormat(result.Format).Is10Bit() {
		result.Buffer.Convert10To8()
		result.Format = uint32(result.Buffer.Format)
	}

	var buf bytes.Buffer
	if err := screenshot.EncodeBufferPNG(&buf, result.Buffer, result.Format, nil); err != nil {
		return nil, fmt.Errorf("encode png: %w", err)
	}
	return buf.Bytes(), nil
}

func notifyCritical(summary, body string) {
	exec.Command("notify-send", summary, body, "-u", "critical").Run()
}
