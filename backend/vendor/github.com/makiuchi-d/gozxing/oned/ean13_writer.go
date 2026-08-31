package oned

import (
	"strconv"

	"github.com/makiuchi-d/gozxing"
)

const (
	ean13Writer_CODE_WIDTH = 3 + // start guard
		(7 * 6) + // left bars
		5 + // middle guard
		(7 * 6) + // right bars
		3 // end guard
)

type ean13Encoder struct{}

func NewEAN13Writer() gozxing.Writer {
	return NewUPCEANWriter(ean13Encoder{})
}

func (ean13Encoder) getSupportedWriteFormats() gozxing.BarcodeFormats {
	return gozxing.BarcodeFormats{gozxing.BarcodeFormat_EAN_13}
}

func (e ean13Encoder) encode(contents string) ([]bool, error) {
	return e.encodeWithHints(contents, nil)
}

func (ean13Encoder) encodeWithHints(contents string, hints map[gozxing.EncodeHintType]interface{}) ([]bool, error) {
	length := len(contents)
	switch length {
	case 12:
		// No check digit present, calculate it and add it
		check, e := upceanReader_getStandardUPCEANChecksum(contents)
		if e != nil {
			return nil, gozxing.NewWriterException("IllegalArgumentException: %s", e.Error())
		}
		contents += strconv.Itoa(check)
		break
	case 13:
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
			"Requested contents should be 12 or 13 digits long, but got %v", length)
	}

	if e := onedWriter_checkNumeric(contents); e != nil {
		return nil, e
	}

	firstDigit := contents[0] - '0'
	parities := ean13Reader_FIRST_DIGIT_ENCODINGS[firstDigit]
	result := make([]bool, ean13Writer_CODE_WIDTH)
	pos := 0

	pos += onedWriter_appendPattern(result, pos, UPCEANReader_START_END_PATTERN, true)

	// See EAN13Reader for a description of how the first digit & left bars are encoded
	for i := 1; i <= 6; i++ {
		digit := contents[i] - '0'
		if ((parities >> uint(6-i)) & 1) == 1 {
			digit += 10
		}
		pos += onedWriter_appendPattern(result, pos, UPCEANReader_L_AND_G_PATTERNS[digit], false)
	}

	pos += onedWriter_appendPattern(result, pos, UPCEANReader_MIDDLE_PATTERN, false)

	for i := 7; i <= 12; i++ {
		digit := contents[i] - '0'
		pos += onedWriter_appendPattern(result, pos, UPCEANReader_L_PATTERNS[digit], true)
	}
	onedWriter_appendPattern(result, pos, UPCEANReader_START_END_PATTERN, true)

	return result, nil
}
