package oned

import (
	"strconv"

	"github.com/makiuchi-d/gozxing"
)

const (
	upcEWriter_CODE_WIDTH = 3 + // start guard
		(7 * 6) + // bars
		6 // end guard
)

type upcEEncoder struct{}

func NewUPCEWriter() gozxing.Writer {
	return NewUPCEANWriter(upcEEncoder{})
}

func (upcEEncoder) getSupportedWriteFormats() gozxing.BarcodeFormats {
	return gozxing.BarcodeFormats{gozxing.BarcodeFormat_UPC_E}
}

func (e upcEEncoder) encode(contents string) ([]bool, error) {
	return e.encodeWithHints(contents, nil)
}

func (upcEEncoder) encodeWithHints(contents string, hints map[gozxing.EncodeHintType]interface{}) ([]bool, error) {
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
		ok, e := upceanReader_checkStandardUPCEANChecksum(convertUPCEtoUPCA(contents))
		if e != nil {
			return nil, gozxing.NewWriterException("IllegalArgumentException: Illegal contents")
		}
		if !ok {
			return nil, gozxing.NewWriterException("IllegalArgumentException: Contents do not pass checksum")
		}
		break
	default:
		return nil, gozxing.NewWriterException("IllegalArgumentException: "+
			"Requested contents should be 7 or 8 digits long, but got %v", length)
	}

	if e := onedWriter_checkNumeric(contents); e != nil {
		return nil, e
	}

	firstDigit := contents[0] - '0'
	if firstDigit != 0 && firstDigit != 1 {
		return nil, gozxing.NewWriterException("IllegalArgumentException: Number system must be 0 or 1")
	}

	checkDigit := contents[7] - '0'
	parities := upce_NUMSYS_AND_CHECK_DIGIT_PATTERNS[firstDigit][checkDigit]
	result := make([]bool, upcEWriter_CODE_WIDTH)

	pos := onedWriter_appendPattern(result, 0, UPCEANReader_START_END_PATTERN, true)

	for i := 1; i <= 6; i++ {
		digit := contents[i] - '0'
		if (parities >> uint(6-i) & 1) == 1 {
			digit += 10
		}
		pos += onedWriter_appendPattern(result, pos, UPCEANReader_L_AND_G_PATTERNS[digit], false)
	}

	onedWriter_appendPattern(result, pos, UPCEANReader_END_PATTERN, false)

	return result, nil
}
