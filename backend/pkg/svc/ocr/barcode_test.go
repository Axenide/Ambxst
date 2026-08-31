package ocr

import (
	"image"
	"image/color"
	"testing"

	"github.com/makiuchi-d/gozxing"
	"github.com/makiuchi-d/gozxing/oned"
	"github.com/makiuchi-d/gozxing/qrcode"
)

func matrixToBlank(w, h int) image.Image {
	img := image.NewGray(image.Rect(0, 0, w, h))
	img.Set(0, 0, color.White)
	return img
}

func TestDecodeBarcodeQRRoundTrip(t *testing.T) {
	writer := qrcode.NewQRCodeWriter()
	matrix, err := writer.EncodeWithoutHint("hello-barcode-test", gozxing.BarcodeFormat_QR_CODE, 120, 120)
	if err != nil {
		t.Fatalf("encode qr: %v", err)
	}

	got, err := decodeBarcodeImage(matrix)
	if err != nil {
		t.Fatalf("decode: %v", err)
	}
	if got != "hello-barcode-test" {
		t.Fatalf("got %q", got)
	}
}

func TestDecodeBarcodeCode128RoundTrip(t *testing.T) {
	writer := oned.NewCode128Writer()
	matrix, err := writer.Encode("AMBXST-12345", gozxing.BarcodeFormat_CODE_128, 300, 80, nil)
	if err != nil {
		t.Fatalf("encode code128: %v", err)
	}

	got, err := decodeBarcodeImage(matrix)
	if err != nil {
		t.Fatalf("decode: %v", err)
	}
	if got != "AMBXST-12345" {
		t.Fatalf("got %q", got)
	}
}

func TestDecodeBarcodeEAN13RoundTrip(t *testing.T) {
	writer := oned.NewEAN13Writer()
	matrix, err := writer.Encode("590123412345", gozxing.BarcodeFormat_EAN_13, 260, 90, nil)
	if err != nil {
		t.Fatalf("encode ean13: %v", err)
	}

	got, err := decodeBarcodeImage(matrix)
	if err != nil {
		t.Fatalf("decode: %v", err)
	}
	if got != "5901234123457" {
		t.Fatalf("got %q (expected checksum digit appended)", got)
	}
}

func TestDecodeBarcodeEmptyImage(t *testing.T) {
	// A blank image contains no codes: expect empty string, no error.
	blank := matrixToBlank(50, 50)
	got, err := decodeBarcodeImage(blank)
	if err != nil {
		t.Fatalf("decode blank: %v", err)
	}
	if got != "" {
		t.Fatalf("expected empty result, got %q", got)
	}
}
