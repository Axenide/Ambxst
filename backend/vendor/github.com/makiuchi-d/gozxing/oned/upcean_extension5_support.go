package oned

import (
	"fmt"
	"strconv"

	"github.com/makiuchi-d/gozxing"
)

var checkDigitEncodings = []int{
	0x18, 0x14, 0x12, 0x11, 0x0C, 0x06, 0x03, 0x0A, 0x09, 0x05,
}

type UPCEANExtension5Support struct {
	decodeMiddleCounters  []int
	decodeRowStringBuffer []byte
}

func NewUPCEANExtension5Support() *UPCEANExtension5Support {
	return &UPCEANExtension5Support{
		make([]int, 4),
		make([]byte, 0, 5),
	}
}

func (this *UPCEANExtension5Support) decodeRow(
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

func (this *UPCEANExtension5Support) decodeMiddle(row *gozxing.BitArray, startRange []int) (int, error) {
	resultString := this.decodeRowStringBuffer
	counters := this.decodeMiddleCounters
	counters[0] = 0
	counters[1] = 0
	counters[2] = 0
	counters[3] = 0
	end := row.GetSize()
	rowOffset := startRange[1]

	lgPatternFound := 0

	for x := 0; x < 5 && rowOffset < end; x++ {
		bestMatch, e := upceanReader_decodeDigit(row, counters, rowOffset, UPCEANReader_L_AND_G_PATTERNS)
		if e != nil {
			return 0, gozxing.WrapNotFoundException(e)
		}
		resultString = append(resultString, byte('0'+bestMatch%10))
		for _, counter := range counters {
			rowOffset += counter
		}
		if bestMatch >= 10 {
			lgPatternFound |= 1 << uint(4-x)
		}
		if x != 4 {
			// Read off separator if not last
			rowOffset = row.GetNextSet(rowOffset)
			rowOffset = row.GetNextUnset(rowOffset)
		}
	}

	this.decodeRowStringBuffer = resultString

	if len(resultString) != 5 {
		return 0, gozxing.NewNotFoundException("len(resultString) = %v", len(resultString))
	}

	checkDigit, e := this.determineCheckDigit(lgPatternFound)
	if e != nil {
		return 0, e
	}
	if checksum := this.extensionChecksum(string(resultString)); checksum != checkDigit {
		return 0, gozxing.NewChecksumException("chechsum = %v, wants %v", checksum, checkDigit)
	}

	return rowOffset, nil
}

func (this *UPCEANExtension5Support) extensionChecksum(s string) int {
	length := len(s)
	sum := 0
	for i := length - 2; i >= 0; i -= 2 {
		sum += int(s[i]) - '0'
	}
	sum *= 3
	for i := length - 1; i >= 0; i -= 2 {
		sum += int(s[i] - '0')
	}
	sum *= 3
	return sum % 10
}

func (this *UPCEANExtension5Support) determineCheckDigit(lgPatternFound int) (int, error) {
	for d := 0; d < 10; d++ {
		if lgPatternFound == checkDigitEncodings[d] {
			return d, nil
		}
	}
	return 0, gozxing.NewNotFoundException()
}

// @param raw raw content of extension
// @return formatted interpretation of raw content as a {@link Map} mapping
//  one {@link ResultMetadataType} to appropriate value, or {@code null} if not known
func (this *UPCEANExtension5Support) parseExtensionString(raw string) map[gozxing.ResultMetadataType]interface{} {
	if len(raw) != 5 {
		return nil
	}
	value := this.parseExtension5String(raw)
	if value == "" {
		return nil
	}
	result := map[gozxing.ResultMetadataType]interface{}{
		gozxing.ResultMetadataType_SUGGESTED_PRICE: value,
	}
	return result
}

func (this *UPCEANExtension5Support) parseExtension5String(raw string) string {
	var currency string
	switch raw[0] {
	case '0':
		currency = "£"
	case '5':
		currency = "$"
	case '9':
		// Reference: http://www.jollytech.com
		switch raw {
		case "90000":
			// No suggested retail price
			return ""
		case "99991":
			// Complementary
			return "0.00"
		case "99990":
			return "Used"
		}
		// Otherwise... unknown currency?
		currency = ""
	default:
		currency = ""
	}
	rawAmount, e := strconv.Atoi(raw[1:])
	if e != nil {
		return ""
	}
	units := rawAmount / 100
	hundredths := rawAmount % 100
	return fmt.Sprintf("%s%d.%02d", currency, units, hundredths)
}
