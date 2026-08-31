package oned

import (
	"github.com/makiuchi-d/gozxing"
)

// For an EAN-13 barcode, the first digit is represented by the parities used
// to encode the next six digits, according to the table below. For example,
// if the barcode is 5 123456 789012 then the value of the first digit is
// signified by using odd for '1', even for '2', even for '3', odd for '4',
// odd for '5', and even for '6'. See http://en.wikipedia.org/wiki/EAN-13
//
//                Parity of next 6 digits
//    Digit   0     1     2     3     4     5
//       0    Odd   Odd   Odd   Odd   Odd   Odd
//       1    Odd   Odd   Even  Odd   Even  Even
//       2    Odd   Odd   Even  Even  Odd   Even
//       3    Odd   Odd   Even  Even  Even  Odd
//       4    Odd   Even  Odd   Odd   Even  Even
//       5    Odd   Even  Even  Odd   Odd   Even
//       6    Odd   Even  Even  Even  Odd   Odd
//       7    Odd   Even  Odd   Even  Odd   Even
//       8    Odd   Even  Odd   Even  Even  Odd
//       9    Odd   Even  Even  Odd   Even  Odd
//
// Note that the encoding for '0' uses the same parity as a UPC barcode. Hence
// a UPC barcode can be converted to an EAN-13 barcode by prepending a 0.
//
// The encoding is represented by the following array, which is a bit pattern
// using Odd = 0 and Even = 1. For example, 5 is represented by:
//
//              Odd Even Even Odd Odd Even
// in binary:
//                0    1    1   0   0    1   == 0x19
//
var ean13Reader_FIRST_DIGIT_ENCODINGS = []int{
	0x00, 0x0B, 0x0D, 0xE, 0x13, 0x19, 0x1C, 0x15, 0x16, 0x1A,
}

type ean13Reader struct {
	*upceanReader
	decodeMiddleCounters []int
}

func NewEAN13Reader() gozxing.Reader {
	this := &ean13Reader{
		decodeMiddleCounters: make([]int, 4),
	}
	this.upceanReader = newUPCEANReader(this)
	return this
}

func (this *ean13Reader) decodeMiddle(row *gozxing.BitArray, startRange []int, resultString []byte) (int, []byte, error) {
	counters := this.decodeMiddleCounters
	counters[0] = 0
	counters[1] = 0
	counters[2] = 0
	counters[3] = 0
	end := row.GetSize()
	rowOffset := startRange[1]

	lgPatternFound := 0
	resultString = append(resultString, '0') // rewrite this after determine.

	for x := 0; x < 6 && rowOffset < end; x++ {
		bestMatch, e := upceanReader_decodeDigit(row, counters, rowOffset, UPCEANReader_L_AND_G_PATTERNS)
		if e != nil {
			return 0, resultString, gozxing.WrapNotFoundException(e)
		}
		resultString = append(resultString, byte('0'+bestMatch%10))
		for _, counter := range counters {
			rowOffset += counter
		}
		if bestMatch >= 10 {
			lgPatternFound |= 1 << uint(5-x)
		}
	}

	firstDigit, e := ean13Reader_determineFirstDigit(lgPatternFound)
	if e != nil {
		return 0, resultString, e
	}
	resultString[0] += firstDigit

	middleRange, e := upceanReader_findGuardPattern(row, rowOffset, true, UPCEANReader_MIDDLE_PATTERN)
	if e != nil {
		return 0, resultString, gozxing.WrapNotFoundException(e)
	}
	rowOffset = middleRange[1]

	for x := 0; x < 6 && rowOffset < end; x++ {
		bestMatch, e := upceanReader_decodeDigit(row, counters, rowOffset, UPCEANReader_L_PATTERNS)
		if e != nil {
			return 0, resultString, gozxing.WrapNotFoundException(e)
		}
		resultString = append(resultString, byte('0'+bestMatch))
		for _, counter := range counters {
			rowOffset += counter
		}
	}

	return rowOffset, resultString, nil
}

func (this *ean13Reader) getBarcodeFormat() gozxing.BarcodeFormat {
	return gozxing.BarcodeFormat_EAN_13
}

// ean13Reader_determineFirstDigit Based on pattern of odd-even ('L' and 'G') patterns
// used to encoded the explicitly-encoded digits in a barcode,
// determines the implicitly encoded first digit and adds it to the result string.
//
// @param resultString string to insert decoded first digit into
// @param lgPatternFound int whose bits indicates the pattern of odd/even L/G patterns used to
//  encode digits
// @throws NotFoundException if first digit cannot be determined
func ean13Reader_determineFirstDigit(lgPatternFound int) (byte, error) {
	for d := 0; d < 10; d++ {
		if lgPatternFound == ean13Reader_FIRST_DIGIT_ENCODINGS[d] {
			return byte(d), nil
		}
	}
	return 0, gozxing.NewNotFoundException()
}

func (this *ean13Reader) decodeEnd(row *gozxing.BitArray, endStart int) ([]int, error) {
	return upceanReader_decodeEnd(row, endStart)
}

func (this *ean13Reader) checkChecksum(s string) (bool, error) {
	return upceanReader_checkChecksum(s)
}
