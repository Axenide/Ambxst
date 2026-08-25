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

	icon := filepath.Join(os.TempDir(), "color_picker_preview.png")
	writeColorSwatch(icon, picked.R, picked.G, picked.B)
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

func copyText(text string) {
	runInput(exec.Command("wl-copy"), []byte(text))
}
