package oned

import (
	"strconv"

	"github.com/makiuchi-d/gozxing"
)

type UPCEANExtension2Support struct {
	decodeMiddleCounters  []int
	decodeRowStringBuffer []byte
}

func NewUPCEANExtension2Support() *UPCEANExtension2Support {
	return &UPCEANExtension2Support{
		make([]int, 4),
		make([]byte, 0, 2),
	}
}

func (this *UPCEANExtension2Support) decodeRow(
	rowNumber int, row *gozxing.BitArray, extensionStartRange []int) (*gozxing.Result, error) {

	this.decodeRowStringBuffer = this.decodeRowStringBuffer[:0]
	end, e := this.decodeMiddle(row, extensionStartRange)
	if e != nil {
		return nil, e
	}

	resultString := string(this.decodeRowStringBuffer)
	extensionData := this.parseExtensionString(resultString)

	extensionResult := gozxing.NewResult(
		resultString,
		nil,
		[]gozxing.ResultPoint{
			gozxing.NewResultPoint(float64(extensionStartRange[0]+extensionStartRange[1])/2.0, float64(rowNumber)),
			gozxing.NewResultPoint(float64(end), float64(rowNumber)),
		},
		gozxing.BarcodeFormat_UPC_EAN_EXTENSION)
	if extensionData != nil {
		extensionResult.PutAllMetadata(extensionData)
	}
	return extensionResult, nil
}

func (this *UPCEANExtension2Support) decodeMiddle(row *gozxing.BitArray, startRange []int) (int, error) {
	resultString := this.decodeRowStringBuffer
	counters := this.decodeMiddleCounters
	counters[0] = 0
	counters[1] = 0
	counters[2] = 0
	counters[3] = 0
	end := row.GetSize()
	rowOffset := startRange[1]

	checkParity := 0

	for x := 0; x < 2 && rowOffset < end; x++ {
		bestMatch, e := upceanReader_decodeDigit(row, counters, rowOffset, UPCEANReader_L_AND_G_PATTERNS)
		if e != nil {
			return 0, gozxing.WrapNotFoundException(e)
		}
		resultString = append(resultString, byte('0'+bestMatch%10))
		for _, counter := range counters {
			rowOffset += counter
		}
		if bestMatch >= 10 {
			checkParity |= 1 << uint(1-x)
		}
		if x != 1 {
			// Read off separator if not last
			rowOffset = row.GetNextSet(rowOffset)
			rowOffset = row.GetNextUnset(rowOffset)
		}
	}

	this.decodeRowStringBuffer = resultString

	if len(resultString) != 2 {
		return 0, gozxing.NewNotFoundException("len(resultString) = %v", len(resultString))
	}

	rstr, _ := strconv.Atoi(string(resultString))
	if parity := rstr % 4; parity != checkParity {
		return 0, gozxing.NewChecksumException("parity=%v, wants %v", parity, checkParity)
	}

	return rowOffset, nil
}

// @param raw raw content of extension
// @return formatted interpretation of raw content as a {@link Map} mapping
//  one {@link ResultMetadataType} to appropriate value, or {@code null} if not known
func (this *UPCEANExtension2Support) parseExtensionString(raw string) map[gozxing.ResultMetadataType]interface{} {
	if len(raw) != 2 {
		return nil
	}
	num, e := strconv.Atoi(raw)
	if e != nil {
		return nil
	}
	result := map[gozxing.ResultMetadataType]interface{}{
		gozxing.ResultMetadataType_ISSUE_NUMBER: num,
	}
	return result
}
