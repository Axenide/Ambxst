package oned

import (
	"strconv"

	"github.com/makiuchi-d/gozxing"
)

const (
	ean8Writer_CODE_WIDTH = 3 + // start guard
		(7 * 4) + // left bars
		5 + // middle guard
		(7 * 4) + // right bars
		3 // end guard
)

type ean8Encoder struct{}

func NewEAN8Writer() gozxing.Writer {
	return NewUPCEANWriter(ean8Encoder{})
}

func (ean8Encoder) getSupportedWriteFormats() gozxing.BarcodeFormats {
	return gozxing.BarcodeFormats{gozxing.BarcodeFormat_EAN_8}
}

// encode encode contents string
// @return a byte array of horizontal pixels (false = white, true = black)
func (e ean8Encoder) encode(contents string) ([]bool, error) {
	return e.encodeWithHints(contents, nil)
}

func (ean8Encoder) encodeWithHints(contents string, hints map[gozxing.EncodeHintType]interface{}) ([]bool, error) {
	length := len(contents)
	switch length {
	case 7:
		// No check digit present, calculate it and add it
		check, e := upceanReader_getStandardUPCEANChecksum(contents)
		if e != nil {
			return nil, gozxing.NewWriterException("IllegalArgumentException: %s", e.Error())
		}
		contents += strconv.Itoa(check)
		break
	case 8:
		ok, e := upceanReader_checkStandardUPCEANChecksum(contents)
		if e != nil {
			return nil, gozxing.NewWriterException(
				"IllegalArgumentException: Illegal contents, %s", e.Error())
		}
		if !ok {
			return nil, gozxing.NewWriterException(
				"IllegalArgumentException: Contents do not pass checksum")
		}
		break
	default:
		return nil, gozxing.NewWriterException("IllegalArgumentException: "+
			"Requested contents should be 7 or 8 digits long, but got %v", length)
	}

	if e := onedWriter_checkNumeric(contents); e != nil {
		return nil, e
	}

	result := make([]bool, ean8Writer_CODE_WIDTH)
	pos := 0

	pos += onedWriter_appendPattern(result, pos, UPCEANReader_START_END_PATTERN, true)

	for i := 0; i <= 3; i++ {
		digit := int(contents[i] - '0')
		pos += onedWriter_appendPattern(result, pos, UPCEANReader_L_PATTERNS[digit], false)
	}

	pos += onedWriter_appendPattern(result, pos, UPCEANReader_MIDDLE_PATTERN, false)

	for i := 4; i <= 7; i++ {
		digit := int(contents[i] - '0')
		pos += onedWriter_appendPattern(result, pos, UPCEANReader_L_PATTERNS[digit], true)
	}
	onedWriter_appendPattern(result, pos, UPCEANReader_START_END_PATTERN, true)

	return result, nil
}
