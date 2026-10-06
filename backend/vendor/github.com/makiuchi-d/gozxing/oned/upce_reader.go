package oned

import (
	"github.com/makiuchi-d/gozxing"
)

// upce_MIDDLE_END_PATTERN The pattern that marks the middle, and end, of a UPC-E pattern.
// There is no "second half" to a UPC-E barcode.
var upce_MIDDLE_END_PATTERN = []int{1, 1, 1, 1, 1, 1}

// For an UPC-E barcode, the final digit is represented by the parities used
// to encode the middle six digits, according to the table below.
//
//                Parity of next 6 digits
//    Digit   0     1     2     3     4     5
//       0    Even   Even  Even Odd  Odd   Odd
//       1    Even   Even  Odd  Even Odd   Odd
//       2    Even   Even  Odd  Odd  Even  Odd
//       3    Even   Even  Odd  Odd  Odd   Even
//       4    Even   Odd   Even Even Odd   Odd
//       5    Even   Odd   Odd  Even Even  Odd
//       6    Even   Odd   Odd  Odd  Even  Even
//       7    Even   Odd   Even Odd  Even  Odd
//       8    Even   Odd   Even Odd  Odd   Even
//       9    Even   Odd   Odd  Even Odd   Even
//
// The encoding is represented by the following array, which is a bit pattern
// using Odd = 0 and Even = 1. For example, 5 is represented by:
//
//              Odd Even Even Odd Odd Even
// in binary:
//                0    1    1   0   0    1   == 0x19
//

// upce_NUMSYS_AND_CHECK_DIGIT_PATTERNS See {@link #L_AND_G_PATTERNS};
// these values similarly represent patterns of
// even-odd parity encodings of digits that imply both the number system (0 or 1)
// used, and the check digit.
//
var upce_NUMSYS_AND_CHECK_DIGIT_PATTERNS = [][]int{
	{0x38, 0x34, 0x32, 0x31, 0x2C, 0x26, 0x23, 0x2A, 0x29, 0x25},
	{0x07, 0x0B, 0x0D, 0x0E, 0x13, 0x19, 0x1C, 0x15, 0x16, 0x1A},
}

type upcEReader struct {
	*upceanReader
	decodeMiddleCounters []int
}

func NewUPCEReader() gozxing.Reader {
	this := &upcEReader{
		decodeMiddleCounters: make([]int, 4),
	}
	this.upceanReader = newUPCEANReader(this)
	return this
}

func (this *upcEReader) decodeMiddle(row *gozxing.BitArray, startRange []int, result []byte) (int, []byte, error) {
	counters := this.decodeMiddleCounters
	counters[0] = 0
	counters[1] = 0
	counters[2] = 0
	counters[3] = 0
	end := row.GetSize()
	rowOffset := startRange[1]

	lgPatternFound := 0

	result = append(result, '0') // put in determineNumSysAndCheckDigit()

	for x := 0; x < 6 && rowOffset < end; x++ {
		bestMatch, e := upceanReader_decodeDigit(row, counters, rowOffset, UPCEANReader_L_AND_G_PATTERNS)
		if e != nil {
			return 0, result, gozxing.WrapNotFoundException(e)
		}
		result = append(result, '0'+byte(bestMatch%10))
		for _, counter := range counters {
			rowOffset += counter
		}
		if bestMatch >= 10 {
			lgPatternFound |= 1 << uint(5-x)
		}
	}

	result, e := determineNumSysAndCheckDigit(result, lgPatternFound)
	if e != nil {
		return 0, result, e
	}

	return rowOffset, result, nil
}

func (this *upcEReader) decodeEnd(row *gozxing.BitArray, endStart int) ([]int, error) {
	return upceanReader_findGuardPattern(row, endStart, true, upce_MIDDLE_END_PATTERN)
}

func (this *upcEReader) checkChecksum(s string) (bool, error) {
	return upceanReader_checkChecksum(convertUPCEtoUPCA(s))
}

func determineNumSysAndCheckDigit(resultString []byte, lgPatternFound int) ([]byte, error) {
	for numSys := byte(0); numSys <= 1; numSys++ {
		for d := byte(0); d < 10; d++ {
			if lgPatternFound == upce_NUMSYS_AND_CHECK_DIGIT_PATTERNS[numSys][d] {
				resultString[0] = '0' + numSys
				resultString = append(resultString, '0'+d)
				return resultString, nil
			}
		}
	}
	return resultString, gozxing.NewNotFoundException()
}

func (this *upcEReader) getBarcodeFormat() gozxing.BarcodeFormat {
	return gozxing.BarcodeFormat_UPC_E
}

// convertUPCEtoUPCA Expands a UPC-E value back into its full, equivalent UPC-A code value.
//
// @param upce UPC-E code as string of digits
// @return equivalent UPC-A code as string of digits
//
func convertUPCEtoUPCA(upce string) string {
	upceChars := upce[1:7]
	result := make([]byte, 0, 12)
	result = append(result, upce[0])
	lastChar := upceChars[5]
	switch lastChar {
	case '0', '1', '2':
		result = append(result, upceChars[0:2]...)
		result = append(result, lastChar)
		result = append(result, []byte("0000")...)
		result = append(result, upceChars[2:5]...)
	case '3':
		result = append(result, upceChars[0:3]...)
		result = append(result, []byte("00000")...)
		result = append(result, upceChars[3:5]...)
	case '4':
		result = append(result, upceChars[0:4]...)
		result = append(result, []byte("00000")...)
		result = append(result, upceChars[4])
	default:
		result = append(result, upceChars[0:5]...)
		result = append(result, []byte("0000")...)
		result = append(result, lastChar)
	}
	// Only append check digit in conversion if supplied
	if len(upce) >= 8 {
		result = append(result, upce[7])
	}
	return string(result)
}
