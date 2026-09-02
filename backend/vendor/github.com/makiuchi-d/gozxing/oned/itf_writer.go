package oned

import (
	"github.com/makiuchi-d/gozxing"
)

// This object renders a ITF code as a {@link BitMatrix}

const (
	itfWriter_W = 3 // Pixel width of a 3x wide line
	itfWriter_N = 1 // Pixed width of a narrow line
)

var (
	itfWriter_START_PATTERN = []int{1, 1, 1, 1}
	itfWriter_END_PATTERN   = []int{3, 1, 1}

	// See ITFReader.PATTERNS

	itfWriter_PATTERNS = [][]int{
		{itfWriter_N, itfWriter_N, itfWriter_W, itfWriter_W, itfWriter_N}, // 0
		{itfWriter_W, itfWriter_N, itfWriter_N, itfWriter_N, itfWriter_W}, // 1
		{itfWriter_N, itfWriter_W, itfWriter_N, itfWriter_N, itfWriter_W}, // 2
		{itfWriter_W, itfWriter_W, itfWriter_N, itfWriter_N, itfWriter_N}, // 3
		{itfWriter_N, itfWriter_N, itfWriter_W, itfWriter_N, itfWriter_W}, // 4
		{itfWriter_W, itfWriter_N, itfWriter_W, itfWriter_N, itfWriter_N}, // 5
		{itfWriter_N, itfWriter_W, itfWriter_W, itfWriter_N, itfWriter_N}, // 6
		{itfWriter_N, itfWriter_N, itfWriter_N, itfWriter_W, itfWriter_W}, // 7

		{itfWriter_W, itfWriter_N, itfWriter_N, itfWriter_W, itfWriter_N}, // 8
		{itfWriter_N, itfWriter_W, itfWriter_N, itfWriter_W, itfWriter_N}, // 9
	}
)

type itfEncoder struct{}

func NewITFWriter() gozxing.Writer {
	return NewOneDimensionalCodeWriter(itfEncoder{})
}

func (itfEncoder) getSupportedWriteFormats() gozxing.BarcodeFormats {
	return gozxing.BarcodeFormats{gozxing.BarcodeFormat_ITF}
}

func (e itfEncoder) encode(contents string) ([]bool, error) {
	return e.encodeWithHints(contents, nil)
}

func (itfEncoder) encodeWithHints(contents string, hints map[gozxing.EncodeHintType]interface{}) ([]bool, error) {
	length := len(contents)
	if length%2 != 0 {
		return nil, gozxing.NewWriterException(
			"IllegalArgumentException: The length of the input should be even, %v", length)
	}
	if length > 80 {
		return nil, gozxing.NewWriterException("IllegalArgumentException: "+
			"Requested contents should be less than 80 digits long, but got %v", length)
	}

	if e := onedWriter_checkNumeric(contents); e != nil {
		return nil, gozxing.WrapWriterException(e)
	}

	result := make([]bool, 9+9*length)
	pos := onedWriter_appendPattern(result, 0, itfWriter_START_PATTERN, true)
	for i := 0; i < length; i += 2 {
		one := contents[i] - '0'
		two := contents[i+1] - '0'
		encoding := make([]int, 10)
		for j := 0; j < 5; j++ {
			encoding[2*j] = itfWriter_PATTERNS[one][j]
			encoding[2*j+1] = itfWriter_PATTERNS[two][j]
		}
		pos += onedWriter_appendPattern(result, pos, encoding, true)
	}
	onedWriter_appendPattern(result, pos, itfWriter_END_PATTERN, true)

	return result, nil
}
