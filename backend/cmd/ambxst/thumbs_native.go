package main

import (
	"fmt"
	"image"
	"image/draw"
	"image/jpeg"

	_ "image/gif"
	_ "image/png"
	"os"
	"path/filepath"
	"strings"

	"golang.org/x/image/bmp"
	xdraw "golang.org/x/image/draw"
	"golang.org/x/image/tiff"
	_ "golang.org/x/image/webp"
)

// decodeAnyImage decodes jpg/png/gif via stdlib and webp/tiff/bmp via
// golang.org/x/image.
func decodeAnyImage(path string) (image.Image, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	switch strings.ToLower(filepath.Ext(path)) {
	case ".jpg", ".jpeg":
		return jpeg.Decode(f)
	case ".tif", ".tiff":
		return tiff.Decode(f)
	case ".bmp":
		return bmp.Decode(f)
	default:
		img, _, err := image.Decode(f)
		return img, err
	}
}

// scaleCenterCrop aspect-fills src into size×size and center-crops,
// mirroring the previous ImageMagick -resize^ + -extent pipeline.
func scaleCenterCrop(src image.Image, size int) image.Image {
	b := src.Bounds()
	sw, sh := b.Dx(), b.Dy()
	if sw <= 0 || sh <= 0 {
		return src
	}
	scale := float64(size) / float64(sw)
	if fh := float64(size) / float64(sh); fh > scale {
		scale = fh
	}
	dw, dh := int(float64(sw)*scale+0.5), int(float64(sh)*scale+0.5)
	if dw < 1 {
		dw = 1
	}
	if dh < 1 {
		dh = 1
	}

	scaled := image.NewRGBA(image.Rect(0, 0, dw, dh))
	xdraw.CatmullRom.Scale(scaled, scaled.Bounds(), src, b, draw.Src, nil)

	cx, cy := (dw-size)/2, (dh-size)/2
	if cx < 0 {
		cx = 0
	}
	if cy < 0 {
		cy = 0
	}
	rect := image.Rect(cx, cy, cx+min(size, dw), cy+min(size, dh))
	return scaled.SubImage(rect)
}

// generateThumbImage renders an image thumbnail natively (no ImageMagick).
func generateThumbImage(filePath, thumbPath string, size int) error {
	src, err := decodeAnyImage(filePath)
	if err != nil {
		return fmt.Errorf("decode: %w", err)
	}
	out := scaleCenterCrop(src, size)

	f, err := os.Create(thumbPath)
	if err != nil {
		return err
	}
	defer f.Close()
	return jpeg.Encode(f, out, &jpeg.Options{Quality: 85})
}
