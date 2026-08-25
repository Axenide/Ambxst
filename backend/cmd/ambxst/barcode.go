package main

import (
	"bytes"
	"image"
	"image/png"

	"github.com/makiuchi-d/gozxing"
	"github.com/makiuchi-d/gozxing/aztec"
	"github.com/makiuchi-d/gozxing/datamatrix"
	"github.com/makiuchi-d/gozxing/oned"
	"github.com/makiuchi-d/gozxing/qrcode"
)

// decodeBarcode reads QR codes and 1D/2D barcodes (EAN/UPC, Code128,
// Code39, Code93, Codabar, ITF, Aztec, DataMatrix) from PNG bytes,
// replacing the previous zbarimg dependency.
func decodeBarcode(pngBytes []byte) (string, error) {
	img, err := png.Decode(bytes.NewReader(pngBytes))
	if err != nil {
		return "", err
	}
	return decodeBarcodeImage(img)
}

func decodeBarcodeImage(img image.Image) (string, error) {
	bmp, err := gozxing.NewBinaryBitmapFromImage(img)
	if err != nil {
		return "", err
	}

	readers := []gozxing.Reader{
		qrcode.NewQRCodeReader(),
		oned.NewMultiFormatUPCEANReader(nil),
		oned.NewCode128Reader(),
		oned.NewCode39Reader(),
		oned.NewCode93Reader(),
		oned.NewCodaBarReader(),
		oned.NewITFReader(),
		aztec.NewAztecReader(),
		datamatrix.NewDataMatrixReader(),
	}

	for _, reader := range readers {
		result, err := reader.DecodeWithoutHints(bmp)
		if err == nil && result != nil && result.GetText() != "" {
			return result.GetText(), nil
		}
	}
	return "", nil
}
