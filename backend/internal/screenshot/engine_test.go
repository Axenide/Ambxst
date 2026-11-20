package screenshot

import (
	"bytes"
	"image/png"
	"testing"
)

func newTestBuffer(t *testing.T, w, h int) *ShmBuffer {
	t.Helper()
	buf, err := CreateShmBuffer(w, h, w*4)
	if err != nil {
		t.Fatalf("create buffer: %v", err)
	}
	buf.Format = FormatARGB8888
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			off := y*buf.Stride + x*4
			buf.Data()[off+0] = 0x80
			buf.Data()[off+1] = byte(y)
			buf.Data()[off+2] = byte(x)
			buf.Data()[off+3] = 0xFF
		}
	}
	return buf
}

func TestCropBuffer(t *testing.T) {
	src := &CaptureResult{
		Buffer:    newTestBuffer(t, 16, 12),
		YInverted: false,
		Format:    uint32(FormatARGB8888),
	}
	defer src.Buffer.Close()

	cropped, err := CropBuffer(src, 4, 3, 8, 6)
	if err != nil {
		t.Fatalf("crop: %v", err)
	}
	defer cropped.Buffer.Close()

	if cropped.Buffer.Width != 8 || cropped.Buffer.Height != 6 {
		t.Fatalf("unexpected dims %dx%d", cropped.Buffer.Width, cropped.Buffer.Height)
	}

	for y := 0; y < 6; y++ {
		for x := 0; x < 8; x++ {
			off := y*cropped.Buffer.Stride + x*4
			g := cropped.Buffer.Data()[off+1]
			r := cropped.Buffer.Data()[off+2]
			if r != byte(4+x) || g != byte(3+y) {
				t.Fatalf("pixel (%d,%d): got r=%d g=%d want r=%d g=%d", x, y, r, g, 4+x, 3+y)
			}
		}
	}
}

func TestCropBufferClamps(t *testing.T) {
	src := &CaptureResult{Buffer: newTestBuffer(t, 10, 10)}
	defer src.Buffer.Close()

	cropped, err := CropBuffer(src, -4, -4, 20, 20)
	if err != nil {
		t.Fatalf("crop: %v", err)
	}
	defer cropped.Buffer.Close()

	if cropped.Buffer.Width != 10 || cropped.Buffer.Height != 10 {
		t.Fatalf("expected clamped to full buffer, got %dx%d", cropped.Buffer.Width, cropped.Buffer.Height)
	}
}

func TestCropBufferEmptyRect(t *testing.T) {
	src := &CaptureResult{Buffer: newTestBuffer(t, 10, 10)}
	defer src.Buffer.Close()

	if _, err := CropBuffer(src, 0, 0, 0, 5); err == nil {
		t.Fatal("expected error for zero-width rect")
	}
	if _, err := CropBuffer(src, 50, 50, 5, 5); err == nil {
		t.Fatal("expected error for out-of-bounds rect")
	}
}

func TestUprightFlipsInverted(t *testing.T) {
	buf, err := CreateShmBuffer(2, 2, 8)
	if err != nil {
		t.Fatal(err)
	}
	buf.Format = FormatARGB8888
	copy(buf.Data(), []byte{
		1, 0, 0, 255, 1, 0, 0, 255,
		2, 0, 0, 255, 2, 0, 0, 255,
	})

	result, err := Upright(&CaptureResult{Buffer: buf, YInverted: true})
	if err != nil {
		t.Fatalf("upright: %v", err)
	}
	defer result.Buffer.Close()

	if result.Buffer.Data()[0] != 2 {
		t.Fatalf("expected vertical flip, first row byte = %d", result.Buffer.Data()[0])
	}
	if result.YInverted {
		t.Fatal("YInverted should be cleared")
	}
}

func TestUprightForOutputSkipsAlreadyOrientedQuarterTurn(t *testing.T) {
	result := &CaptureResult{
		Buffer:    newTestBuffer(t, 9, 16),
		Region:    Region{Width: 16, Height: 9},
		Transform: Transform90,
	}

	upright, err := UprightForOutput(result, nil)
	if err != nil {
		t.Fatalf("upright: %v", err)
	}
	defer upright.Buffer.Close()

	if upright.Buffer.Width != 9 || upright.Buffer.Height != 16 {
		t.Fatalf("expected already-oriented 9x16 buffer, got %dx%d", upright.Buffer.Width, upright.Buffer.Height)
	}
	if got := upright.Buffer.Data()[1]; got != 0 {
		t.Fatalf("top-left pixel changed orientation: got y=%d want 0", got)
	}
}

func TestUprightForOutputRotatesRawQuarterTurn(t *testing.T) {
	result := &CaptureResult{
		Buffer:    newTestBuffer(t, 16, 9),
		Region:    Region{Width: 16, Height: 9},
		Transform: Transform90,
	}

	upright, err := UprightForOutput(result, nil)
	if err != nil {
		t.Fatalf("upright: %v", err)
	}
	defer upright.Buffer.Close()

	if upright.Buffer.Width != 9 || upright.Buffer.Height != 16 {
		t.Fatalf("expected rotated 9x16 buffer, got %dx%d", upright.Buffer.Width, upright.Buffer.Height)
	}
	if got := upright.Buffer.Data()[1]; got != 8 {
		t.Fatalf("top-left pixel has y=%d, want 8 after rotation", got)
	}
}

func TestFrameInLogicalOrientation(t *testing.T) {
	tests := []struct {
		name            string
		transform       int32
		outputWidth     int32
		outputHeight    int32
		frameWidth      int
		frameHeight     int
		hyprlandLogical bool
		want            bool
	}{
		{name: "normal", transform: TransformNormal, outputWidth: 16, outputHeight: 9, frameWidth: 16, frameHeight: 9, want: true},
		{name: "rotated frame is logical", transform: Transform90, outputWidth: 16, outputHeight: 9, frameWidth: 9, frameHeight: 16, want: true},
		{name: "native frame needs rotation", transform: Transform90, outputWidth: 16, outputHeight: 9, frameWidth: 16, frameHeight: 9, want: false},
		{name: "270 rotated frame is logical", transform: Transform270, outputWidth: 16, outputHeight: 9, frameWidth: 9, frameHeight: 16, want: true},
		{name: "square uses compositor fallback", transform: Transform90, outputWidth: 10, outputHeight: 10, frameWidth: 10, frameHeight: 10, hyprlandLogical: true, want: true},
		{name: "nonlogical square uses transform", transform: Transform90, outputWidth: 10, outputHeight: 10, frameWidth: 10, frameHeight: 10, want: false},
		{name: "180 uses compositor fallback", transform: Transform180, outputWidth: 16, outputHeight: 9, frameWidth: 16, frameHeight: 9, hyprlandLogical: true, want: true},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			fallback := func() bool { return test.hyprlandLogical }
			got := frameInLogicalOrientation(test.transform, test.outputWidth, test.outputHeight, test.frameWidth, test.frameHeight, fallback)
			if got != test.want {
				t.Fatalf("frameInLogicalOrientation() = %v, want %v", got, test.want)
			}
		})
	}
}

func TestFrameInLogicalOrientationDoesNotQueryCompositorForNormalTransform(t *testing.T) {
	called := false
	logical := frameInLogicalOrientation(TransformNormal, 16, 9, 16, 9, func() bool {
		called = true
		return false
	})
	if !logical {
		t.Fatal("normal transform should already be logical")
	}
	if called {
		t.Fatal("compositor fallback should not be queried for normal transform")
	}
}

func TestEncodeDecodePNGRoundTrip(t *testing.T) {
	src := &CaptureResult{Buffer: newTestBuffer(t, 9, 7)}
	defer src.Buffer.Close()

	var out bytes.Buffer
	if err := EncodeBufferPNG(&out, src.Buffer, uint32(FormatARGB8888), nil); err != nil {
		t.Fatalf("encode: %v", err)
	}

	img, err := png.Decode(bytes.NewReader(out.Bytes()))
	if err != nil {
		t.Fatalf("decode: %v", err)
	}

	bounds := img.Bounds()
	if bounds.Dx() != 9 || bounds.Dy() != 7 {
		t.Fatalf("unexpected decoded dims %v", bounds)
	}

	for y := 0; y < 7; y++ {
		for x := 0; x < 9; x++ {
			c := img.At(x, y)
			r, g, b, _ := c.RGBA()
			if uint8(r>>8) != byte(x) || uint8(g>>8) != byte(y) || uint8(b>>8) != 0x80 {
				t.Fatalf("pixel (%d,%d) mismatch: %v", x, y, c)
			}
		}
	}
}
func TestTenBitSwapRB(t *testing.T) {
	if !tenBitSwapRB(uint32(FormatXRGB2101010)) {
		t.Fatal("XRGB2101010 should swap")
	}
	if tenBitSwapRB(uint32(FormatXBGR2101010)) {
		t.Fatal("XBGR2101010 should not swap")
	}
}
