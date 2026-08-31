package oned

import (
	"strconv"

	"github.com/makiuchi-d/gozxing"
)

type encoder interface {
	// encodeWithoutHint Encode the contents to boolean array expression of one-dimensional barcode.
	// Start code and end code should be included in result, and side margins should not be included.
	//
	// @param contents barcode contents to encode
	// @return a {@code boolean[]} of horizontal pixels (false = white, true = black)
	//
	encode(contents string) ([]bool, error)

	// Can be overwritten if the encode requires to read the hints map. Otherwise it defaults to {@code encode}.
	// @param contents barcode contents to encode
	// @param hints encoding hints
	// @return a {@code boolean[]} of horizontal pixels (false = white, true = black)
	//
	encodeWithHints(contents string, hints map[gozxing.EncodeHintType]interface{}) ([]bool, error)

	getSupportedWriteFormats() gozxing.BarcodeFormats
}

type OneDimensionalCodeWriter struct {
	encoder
	defaultMargin int
}

func NewOneDimensionalCodeWriter(enc encoder) *OneDimensionalCodeWriter {
	return &OneDimensionalCodeWriter{
		encoder:       enc,
		defaultMargin: 10,
	}
}

func (this *OneDimensionalCodeWriter) EncodeWithoutHint(
	contents string, format gozxing.BarcodeFormat, width, height int) (*gozxing.BitMatrix, error) {
	return this.Encode(contents, format, width, height, nil)
}

// Encode the contents following specified format.
// {@code width} and {@code height} are required size. This method may return bigger size
// {@code BitMatrix} when specified size is too small. The user can set both {@code width} and
// {@code height} to zero to get minimum size barcode. If negative value is set to {@code width}
// or {@code height}, {@code IllegalArgumentException} is thrown.
func (this *OneDimensionalCodeWriter) Encode(
	contents string, format gozxing.BarcodeFormat, width, height int,
	hints map[gozxing.EncodeHintType]interface{}) (*gozxing.BitMatrix, error) {

	if len(contents) == 0 {
		return nil, gozxing.NewWriterException("IllegalArgumentException: Found empty contents")
	}

	if width < 0 || height < 0 {
		return nil, gozxing.NewWriterException(
			"IllegalArgumentException: Negative size is not allowed. Input: %dx%d", width, height)
	}
	supportedFormats := this.getSupportedWriteFormats()
	if !supportedFormats.Contains(format) {
		return nil, gozxing.NewWriterException(
			"IllegalArgumentException: Can only encode %v, but got %v", supportedFormats, format)
	}

	sidesMargin := this.defaultMargin
	if margin, ok := hints[gozxing.EncodeHintType_MARGIN]; ok {
		if m, ok := margin.(int); ok {
			sidesMargin = m
		} else if m, ok := margin.(string); ok {
			var e error
			sidesMargin, e = strconv.Atoi(m)
			if e != nil {
				return nil, e
			}
		} else {
			return nil, gozxing.NewWriterException(
				"IllegalArgumentException: invalid type hints[EncodeHintType_MARGIN], %T", margin)
		}
	}

	code, e := this.encodeWithHints(contents, hints)
	if e != nil {
		return nil, e
	}
	return onedWriter_renderResult(code, width, height, sidesMargin)
}

// onedWriter_renderResult @return a byte array of horizontal pixels (0 = white, 1 = black)
func onedWriter_renderResult(code []bool, width, height, sidesMargin int) (*gozxing.BitMatrix, error) {
	inputWidth := len(code)
	// Add quiet zone on both sides.
	fullWidth := inputWidth + sidesMargin
	outputWidth := max(width, fullWidth)
	outputHeight := max(1, height)

	multiple := outputWidth / fullWidth
	leftPadding := (outputWidth - (inputWidth * multiple)) / 2

	output, e := gozxing.NewBitMatrix(outputWidth, outputHeight)
	if e != nil {
		return nil, gozxing.WrapWriterException(e)
	}
	for inputX, outputX := 0, leftPadding; inputX < inputWidth; inputX, outputX = inputX+1, outputX+multiple {
		if code[inputX] {
			output.SetRegion(outputX, 0, multiple, outputHeight)
		}
	}
	return output, nil
}

// onedWriter_checkNumeric returns IllegalArgumentException if input contains characters other than digits 0-9.
func onedWriter_checkNumeric(contents string) error {
	for _, c := range contents {
		if c < '0' || c > '9' {
			return gozxing.NewWriterException(
				"IllegalArgumentException: Input should only contain digits 0-9, 0x%02x", c)
		}
	}
	return nil
}

// onedWriter_appendPattern append pattern
// @param target encode black/white pattern into this array
// @param pos position to start encoding at in {@code target}
// @param pattern lengths of black/white runs to encode
// @param startColor starting color - false for white, true for black
// @return the number of elements added to target.
func onedWriter_appendPattern(target []bool, pos int, pattern []int, startColor bool) int {
	color := startColor
	numAdded := 0
	for _, len := range pattern {
		for j := 0; j < len; j++ {
			target[pos] = color
			pos++
		}
		numAdded += len
		color = !color
	}
	return numAdded
}
