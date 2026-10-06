package oned

import (
	"github.com/makiuchi-d/gozxing"
)

type ean8Reader struct {
	*upceanReader
	decodeMiddleCounters []int
}

func NewEAN8Reader() gozxing.Reader {
	this := &ean8Reader{
		decodeMiddleCounters: make([]int, 4),
	}
	this.upceanReader = newUPCEANReader(this)
	return this
}

func (this *ean8Reader) decodeMiddle(row *gozxing.BitArray, startRange []int, result []byte) (int, []byte, error) {
	counters := this.decodeMiddleCounters
	counters[0] = 0
	counters[1] = 0
	counters[2] = 0
	counters[3] = 0
	end := row.GetSize()
	rowOffset := startRange[1]

	for x := 0; x < 4 && rowOffset < end; x++ {
		bestMatch, e := upceanReader_decodeDigit(row, counters, rowOffset, UPCEANReader_L_PATTERNS)
		if e != nil {
			return 0, result, gozxing.WrapNotFoundException(e)
		}
		result = append(result, byte('0'+bestMatch))
		for _, counter := range counters {
			rowOffset += counter
		}
	}

	middleRange, e := upceanReader_findGuardPattern(row, rowOffset, true, UPCEANReader_MIDDLE_PATTERN)
	if e != nil {
		return 0, result, gozxing.WrapNotFoundException(e)
	}
	rowOffset = middleRange[1]

	for x := 0; x < 4 && rowOffset < end; x++ {
		bestMatch, e := upceanReader_decodeDigit(row, counters, rowOffset, UPCEANReader_L_PATTERNS)
		if e != nil {
			return 0, result, gozxing.WrapNotFoundException(e)
		}
		result = append(result, byte('0'+bestMatch))
		for _, counter := range counters {
			rowOffset += counter
		}
	}

	return rowOffset, result, nil
}

func (this *ean8Reader) getBarcodeFormat() gozxing.BarcodeFormat {
	return gozxing.BarcodeFormat_EAN_8
}

func (this *ean8Reader) decodeEnd(row *gozxing.BitArray, endStart int) ([]int, error) {
	return upceanReader_decodeEnd(row, endStart)
}

func (this *ean8Reader) checkChecksum(s string) (bool, error) {
	return upceanReader_checkChecksum(s)
}
