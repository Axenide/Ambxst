package main

import (
	"fmt"
	"image"
	"image/color"
	"os"
	"os/exec"
	"path/filepath"
	"runtime/debug"
	"strings"

	"ambxst/backend/internal/colorpicker"
	"ambxst/backend/internal/screenshot"
)

// --- colorpicker: interactive layer-shell loupe -> clipboard -> notify actions ---

func runColorPicker() int {
	debug.SetGCPercent(-1)
	debug.SetMemoryLimit(1 << 30)

	picker := colorpicker.New(colorpicker.Config{
		Format:    colorpicker.FormatHex,
		Lowercase: false,
	})
	picked, err := picker.Run()
	if err != nil {
		exec.Command("notify-send", "Color Picker", "Error: "+err.Error(), "-u", "critical").Run()
		return 1
	}
	if picked == nil {
		return 0
	}

	hexColor := picked.ToHex(false)
	rgbColor := picked.ToRGB()
	hsvColor := picked.ToHSV()

	icon := colorSwatchPath(hexColor)
	writeColorSwatch(icon, picked.R, picked.G, picked.B)
	pruneStaleSwatches(icon)
	copyText(hexColor)

	action, _ := exec.Command("notify-send", "Color Picked",
		fmt.Sprintf("%s copied to clipboard", hexColor),
		"-i", icon, "-a", "ColorPicker", "-u", "normal",
		"--action=hex=Copy HEX", "--action=rgb=Copy RGB", "--action=hsv=Copy HSV").Output()

	chosen := strings.TrimSpace(string(action))
	chosenColor := map[string]string{"hex": hexColor, "rgb": rgbColor, "hsv": hsvColor}[chosen]
	if chosenColor == "" {
		chosenColor = hexColor
	}
	copyText(chosenColor)
	exec.Command("notify-send", "Color Picker", "Copied: "+chosenColor, "-i", icon, "-u", "low").Run()
	return 0
}

func writeColorSwatch(path string, r, g, b uint8) {
	img := image.NewRGBA(image.Rect(0, 0, 64, 64))
	fill := color.RGBA{R: r, G: g, B: b, A: 0xFF}
	for y := 0; y < 64; y++ {
		for x := 0; x < 64; x++ {
			img.Set(x, y, fill)
		}
	}
	f, err := os.Create(path)
	if err != nil {
		return
	}
	defer f.Close()
	_ = screenshot.EncodePNG(f, img)
}

// colorSwatchPath keys the swatch file by the picked color so notification
// renderers that cache by path show the right image for each pick.
func colorSwatchPath(hexColor string) string {
	name := strings.TrimPrefix(strings.ToLower(hexColor), "#")
	return filepath.Join(os.TempDir(), "ambxst_color_swatch_"+name+".png")
}

// pruneStaleSwatches removes swatches from previous picks so /tmp never
// accumulates more than one.
func pruneStaleSwatches(current string) {
	matches, _ := filepath.Glob(filepath.Join(os.TempDir(), "ambxst_color_swatch_*.png"))
	for _, m := range matches {
		if m != current {
			os.Remove(m)
		}
	}
}

// copyText must not wait on wl-copy: it forks a clipboard-serving child
// that inherits our pipes and lives until the content is replaced. Waiting
// on it would stall everything queued after the copy.
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
