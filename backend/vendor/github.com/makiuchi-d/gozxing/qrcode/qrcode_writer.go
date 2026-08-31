package qrcode

import (
	"strconv"

	"github.com/makiuchi-d/gozxing"
	"github.com/makiuchi-d/gozxing/qrcode/decoder"
	"github.com/makiuchi-d/gozxing/qrcode/encoder"
)

const (
	qrcodeWriter_QUIET_ZONE_SIZE = 4
)

type QRCodeWriter struct{}

func NewQRCodeWriter() *QRCodeWriter {
	return &QRCodeWriter{}
}

func (this *QRCodeWriter) EncodeWithoutHint(
	contents string, format gozxing.BarcodeFormat, width, height int) (*gozxing.BitMatrix, error) {
	return this.Encode(contents, format, width, height, nil)
}

func (this *QRCodeWriter) Encode(
	contents string, format gozxing.BarcodeFormat, width, height int,
	hints map[gozxing.EncodeHintType]interface{}) (*gozxing.BitMatrix, error) {

	if len(contents) == 0 {
		return nil, gozxing.NewWriterException("IllegalArgumentException: Found empty contents")
	}

	if format != gozxing.BarcodeFormat_QR_CODE {
		return nil, gozxing.NewWriterException(
			"IllegalArgumentException: Can only encode QR_CODE, but got %v", format)
	}

	if width < 0 || height < 0 {
		return nil, gozxing.NewWriterException(
			"IllegalArgumentException: Requested dimensions are too small: %vx%v", width, height)
	}

	errorCorrectionLevel := decoder.ErrorCorrectionLevel_L
	quietZone := qrcodeWriter_QUIET_ZONE_SIZE
	if hints != nil {
		if ec, ok := hints[gozxing.EncodeHintType_ERROR_CORRECTION]; ok {
			if ecl, ok := ec.(decoder.ErrorCorrectionLevel); ok {
				errorCorrectionLevel = ecl
			} else if str, ok := ec.(string); ok {
				ecl, e := decoder.ErrorCorrectionLevel_ValueOf(str)
				if e != nil {
					return nil, gozxing.NewWriterException("EncodeHintType_ERROR_CORRECTION: %w", e)
				}
				errorCorrectionLevel = ecl
			} else {
				return nil, gozxing.NewWriterException(
					"IllegalArgumentException: EncodeHintType_ERROR_CORRECTION %v", ec)
			}
		}
		if m, ok := hints[gozxing.EncodeHintType_MARGIN]; ok {
			if qz, ok := m.(int); ok {
				quietZone = qz
			} else if str, ok := m.(string); ok {
				qz, e := strconv.Atoi(str)
				if e != nil {
					return nil, gozxing.NewWriterException("EncodeHintType_MARGIN = \"%v\": %w", m, e)
				}
				quietZone = qz
			} else {
				return nil, gozxing.NewWriterException(
					"IllegalArgumentException: EncodeHintType_MARGIN %v", m)
			}
		}
	}

	code, e := encoder.Encoder_encode(contents, errorCorrectionLevel, hints)
	if e != nil {
		return nil, e
	}
	return renderResult(code, width, height, quietZone)
}

// renderResult Note that the input matrix uses 0 == white, 1 == black, while the output matrix uses
// 0 == black, 255 == white (i.e. an 8 bit greyscale bitmap).
func renderResult(code *encoder.QRCode, width, height, quietZone int) (*gozxing.BitMatrix, error) {
	input := code.GetMatrix()
	if input == nil {
		return nil, gozxing.NewWriterException("IllegalStateException")
	}
	inputWidth := input.GetWidth()
	inputHeight := input.GetHeight()
	qrWidth := inputWidth + (quietZone * 2)
	qrHeight := inputHeight + (quietZone * 2)
	outputWidth := qrWidth
	if outputWidth < width {
		outputWidth = width
	}
	outputHeight := qrHeight
	if outputHeight < height {
		outputHeight = height
	}

	multiple := outputWidth / qrWidth
	if h := outputHeight / qrHeight; multiple > h {
		multiple = h
	}
	// Padding includes both the quiet zone and the extra white pixels to accommodate the requested
	// dimensions. For example, if input is 25x25 the QR will be 33x33 including the quiet zone.
	// If the requested size is 200x160, the multiple will be 4, for a QR of 132x132. These will
	// handle all the padding from 100x100 (the actual QR) up to 200x160.
	leftPadding := (outputWidth - (inputWidth * multiple)) / 2
	topPadding := (outputHeight - (inputHeight * multiple)) / 2

	output, e := gozxing.NewBitMatrix(outputWidth, outputHeight)
	if e != nil {
		return nil, gozxing.WrapWriterException(e)
	}

	for inputY, outputY := 0, topPadding; inputY < inputHeight; inputY, outputY = inputY+1, outputY+multiple {
		// Write the contents of this row of the barcode
		for inputX, outputX := 0, leftPadding; inputX < inputWidth; inputX, outputX = inputX+1, outputX+multiple {
			if input.Get(inputX, inputY) == 1 {
				output.SetRegion(outputX, outputY, multiple, multiple)
			}
		}
	}

	return output, nil
}
