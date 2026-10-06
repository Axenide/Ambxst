package oned

import (
	"strconv"

	"github.com/makiuchi-d/gozxing"
)

const (
	// These two values are critical for determining how permissive the decoding will be.
	// We've arrived at these values through a lot of trial and error. Setting them any higher
	// lets false positives creep in quickly.
	UPCEANReader_MAX_AVG_VARIANCE        = 0.48
	UPCEANReader_MAX_INDIVIDUAL_VARIANCE = 0.7
)

var (
	// Start/end guard pattern.
	UPCEANReader_START_END_PATTERN = []int{1, 1, 1}

	// Pattern marking the middle of a UPC/EAN pattern, separating the two halves.
	UPCEANReader_MIDDLE_PATTERN = []int{1, 1, 1, 1, 1}

	// end guard pattern.
	UPCEANReader_END_PATTERN = []int{1, 1, 1, 1, 1, 1}

	// "Odd", or "L" patterns used to encode UPC/EAN digits.
	UPCEANReader_L_PATTERNS = [][]int{
		{3, 2, 1, 1}, // 0
		{2, 2, 2, 1}, // 1
		{2, 1, 2, 2}, // 2
		{1, 4, 1, 1}, // 3
		{1, 1, 3, 2}, // 4
		{1, 2, 3, 1}, // 5
		{1, 1, 1, 4}, // 6
		{1, 3, 1, 2}, // 7
		{1, 2, 1, 3}, // 8
		{3, 1, 1, 2}, // 9
	}

	// As above but also including the "even", or "G" patterns used to encode UPC/EAN digits.
	UPCEANReader_L_AND_G_PATTERNS [][]int
)

func init() {
	UPCEANReader_L_AND_G_PATTERNS = make([][]int, 20)
	copy(UPCEANReader_L_AND_G_PATTERNS, UPCEANReader_L_PATTERNS)
	for i := 10; i < 20; i++ {
		widths := UPCEANReader_L_PATTERNS[i-10]
		reversedWidths := make([]int, len(widths))
		for j := 0; j < len(widths); j++ {
			reversedWidths[j] = widths[len(widths)-j-1]
		}
		UPCEANReader_L_AND_G_PATTERNS[i] = reversedWidths
	}
}

type upceanRowDecoder interface {
	RowDecoder

	// getBarcodeFormat Get the format of this decoder.
	// @return The 1D format.
	getBarcodeFormat() gozxing.BarcodeFormat

	// decodeMiddle Subclasses override this to decode the portion of a barcode between the start
	// and end guard patterns.
	//
	// @param row row of black/white values to search
	// @param startRange start/end offset of start guard pattern
	// @param resultString {@link StringBuilder} to append decoded chars to
	// @return horizontal offset of first pixel after the "middle" that was decoded
	// @throws NotFoundException if decoding could not complete successfully
	decodeMiddle(row *gozxing.BitArray, startRange []int, result []byte) (int, []byte, error)

	decodeEnd(row *gozxing.BitArray, endStart int) ([]int, error)

	// checkChecksum Check checksum
	// @param s string of digits to check
	// @return {@link #checkStandardUPCEANChecksum(CharSequence)}
	// @throws FormatException if the string does not contain only digits
	checkChecksum(s string) (bool, error)
}

type upceanReader struct {
	upceanRowDecoder
	*OneDReader
	decodeRowStringBuffer []byte
	extensionReader       *UPCEANExtensionSupport
}

func newUPCEANReader(rowDecoder upceanRowDecoder) *upceanReader {
	this := &upceanReader{
		upceanRowDecoder:      rowDecoder,
		decodeRowStringBuffer: make([]byte, 13),
		extensionReader:       NewUPCEANExtensionSupport(),
	}
	this.OneDReader = NewOneDReader(rowDecoder)
	return this
}

func upceanReader_findStartGuardPattern(row *gozxing.BitArray) ([]int, error) {
	foundStart := false
	var startRange []int
	nextStart := 0
	counters := make([]int, len(UPCEANReader_START_END_PATTERN))
	for !foundStart {
		for i := range counters {
			counters[i] = 0
		}
		var e error
		startRange, e = upceanReader_findGuardPatternWithCounters(
			row, nextStart, false, UPCEANReader_START_END_PATTERN, counters)
		if e != nil {
			return nil, e
		}
		start := startRange[0]
		nextStart = startRange[1]
		// Make sure there is a quiet zone at least as big as the start pattern before the barcode.
		// If this check would run off the left edge of the image, do not accept this barcode,
		// as it is very likely to be a false positive.
		quietStart := start - (nextStart - start)
		if quietStart >= 0 {
			foundStart, _ = row.IsRange(quietStart, start, false)
		}
	}
	return startRange, nil
}

func (this *upceanReader) DecodeRow(rowNumber int, row *gozxing.BitArray, hints map[gozxing.DecodeHintType]interface{}) (*gozxing.Result, error) {
	start, e := upceanReader_findStartGuardPattern(row)
	if e != nil {
		return nil, gozxing.WrapNotFoundException(e)
	}
	return this.decodeRowWithStartRange(rowNumber, row, start, hints)
}

// decodeRowWithStartRange Like {@link #decodeRow(int, BitArray, Map)}, but
// allows caller to inform method about where the UPC/EAN start pattern is
// found. This allows this to be computed once and reused across many implementations.</p>
//
// @param rowNumber row index into the image
// @param row encoding of the row of the barcode image
// @param startGuardRange start/end column where the opening start pattern was found
// @param hints optional hints that influence decoding
// @return {@link Result} encapsulating the result of decoding a barcode in the row
// @throws NotFoundException if no potential barcode is found
// @throws ChecksumException if a potential barcode is found but does not pass its checksum
// @throws FormatException if a potential barcode is found but format is invalid
func (this *upceanReader) decodeRowWithStartRange(
	rowNumber int, row *gozxing.BitArray, startGuardRange []int,
	hints map[gozxing.DecodeHintType]interface{}) (*gozxing.Result, error) {

	var resultPointCallback gozxing.ResultPointCallback
	if hint, ok := hints[gozxing.DecodeHintType_NEED_RESULT_POINT_CALLBACK]; ok {
		resultPointCallback = hint.(gozxing.ResultPointCallback)
	}
	symbologyIdentifier := 0

	if resultPointCallback != nil {
		resultPointCallback(gozxing.NewResultPoint(
			float64(startGuardRange[0]+startGuardRange[1])/2.0, float64(rowNumber)))
	}

	result := this.decodeRowStringBuffer[:0]
	endStart, result, e := this.decodeMiddle(row, startGuardRange, result)
	if e != nil {
		return nil, e
	}

	rowNumberf := float64(rowNumber)
	if resultPointCallback != nil {
		resultPointCallback(gozxing.NewResultPoint(float64(endStart), rowNumberf))
	}

	endRange, e := this.decodeEnd(row, endStart)
	if e != nil {
		return nil, gozxing.WrapNotFoundException(e)
	}

	if resultPointCallback != nil {
		resultPointCallback(gozxing.NewResultPoint(
			float64(endRange[0]+endRange[1])/2.0, rowNumberf))
	}

	// Make sure there is a quiet zone at least as big as the end pattern after the barcode. The
	// spec might want more whitespace, but in practice this is the maximum we can count on.
	end := endRange[1]
	quietEnd := end + (end - endRange[0])
	if quietEnd >= row.GetSize() {
		return nil, gozxing.NewNotFoundException("quietEnd=%v, row size=%v", quietEnd, row.GetSize())
	}
	rowIsRange, _ := row.IsRange(end, quietEnd, false)
	if !rowIsRange {
		return nil, gozxing.NewNotFoundException("raw is not range")
	}

	this.decodeRowStringBuffer = result

	resultString := string(result)
	// UPC/EAN should never be less than 8 chars anyway
	if len(resultString) < 8 {
		return nil, gozxing.NewFormatException("len(resultString) = %v", len(resultString))
	}
	ok, e := this.checkChecksum(resultString)
	if e != nil {
		return nil, gozxing.WrapChecksumException(e)
	}
	if !ok {
		return nil, gozxing.NewChecksumException()
	}

	left := float64(startGuardRange[1]+startGuardRange[0]) / 2.0
	right := float64(endRange[1]+endRange[0]) / 2.0
	format := this.getBarcodeFormat()
	decodeResult := gozxing.NewResult(
		resultString,
		nil, // no natural byte representation for these barcodes
		[]gozxing.ResultPoint{
			gozxing.NewResultPoint(left, float64(rowNumber)),
			gozxing.NewResultPoint(right, float64(rowNumber)),
		},
		format)

	extensionLength := 0

	extensionResult, e := this.extensionReader.decodeRow(rowNumber, row, endRange[1])
	if e == nil {
		decodeResult.PutMetadata(gozxing.ResultMetadataType_UPC_EAN_EXTENSION, extensionResult.GetText())
		decodeResult.PutAllMetadata(extensionResult.GetResultMetadata())
		decodeResult.AddResultPoints(extensionResult.GetResultPoints())
		extensionLength = len(extensionResult.GetText())
	} else {
		// ignore ReaderException
		if _, ok := e.(gozxing.ReaderException); !ok {
			return nil, gozxing.WrapReaderException(e)
		}
	}

	if hint, ok := hints[gozxing.DecodeHintType_ALLOWED_EAN_EXTENSIONS]; ok {
		allowedExtensions, ok := hint.([]int)
		if ok {
			valid := false
			for _, length := range allowedExtensions {
				if extensionLength == length {
					valid = true
					break
				}
			}
			if !valid {
				return nil, gozxing.NewNotFoundException()
			}
		}
	}

	if format == gozxing.BarcodeFormat_EAN_13 || format == gozxing.BarcodeFormat_UPC_A {
		countryID := eanManufacturerOrgSupportLookupCountryIdentifier(resultString)
		if countryID != "" {
			decodeResult.PutMetadata(gozxing.ResultMetadataType_POSSIBLE_COUNTRY, countryID)
		}
	}
	if format == gozxing.BarcodeFormat_EAN_8 {
		symbologyIdentifier = 4
	}

	decodeResult.PutMetadata(
		gozxing.ResultMetadataType_SYMBOLOGY_IDENTIFIER, "]E"+strconv.Itoa(symbologyIdentifier))

	return decodeResult, nil
}

// checkChecksum Check checksum
// @param s string of digits to check
// @return {@link #checkStandardUPCEANChecksum(CharSequence)}
// @throws FormatException if the string does not contain only digits
func upceanReader_checkChecksum(s string) (bool, error) {
	return upceanReader_checkStandardUPCEANChecksum(s)
}

// checkStandardUPCEANChecksum Computes the UPC/EAN checksum on a string of digits,
// and reports whether the checksum is correct or not.
//
// @param s string of digits to check
/// @return true iff string of digits passes the UPC/EAN checksum algorithm
// @throws FormatException if the string does not contain only digits
func upceanReader_checkStandardUPCEANChecksum(s string) (bool, error) {
	length := len(s)
	if length == 0 {
		return false, nil
	}
	check := int(s[length-1] - '0')
	sum, e := upceanReader_getStandardUPCEANChecksum(s[:length-1])
	if e != nil {
		return false, e
	}
	return sum == check, nil
}

func upceanReader_getStandardUPCEANChecksum(s string) (int, error) {
	length := len(s)
	sum := 0
	for i := length - 1; i >= 0; i -= 2 {
		digit := int(s[i] - '0')
		if digit < 0 || digit > 9 {
			return 0, gozxing.NewFormatException("0x%02x is not digit", s[i])
		}
		sum += digit
	}
	sum *= 3
	for i := length - 2; i >= 0; i -= 2 {
		digit := int(s[i] - '0')
		if digit < 0 || digit > 9 {
			return 0, gozxing.NewFormatException("0x%02x is not digit", s[i])
		}
		sum += digit
	}
	return (1000 - sum) % 10, nil
}

func upceanReader_decodeEnd(row *gozxing.BitArray, endStart int) ([]int, error) {
	return upceanReader_findGuardPattern(row, endStart, false, UPCEANReader_START_END_PATTERN)
}

func upceanReader_findGuardPattern(row *gozxing.BitArray, rowOffset int, whiteFirst bool, pattern []int) ([]int, error) {
	counters := make([]int, len(pattern))
	return upceanReader_findGuardPatternWithCounters(row, rowOffset, whiteFirst, pattern, counters)
}

// UPCEANReader_findGuardPatternWithCounters Find guard pattern
// @param row row of black/white values to search
// @param rowOffset position to start search
// @param whiteFirst if true, indicates that the pattern specifies white/black/white/...
// pixel counts, otherwise, it is interpreted as black/white/black/...
// @param pattern pattern of counts of number of black and white pixels that are being
// searched for as a pattern
// @param counters array of counters, as long as pattern, to re-use
// @return start/end horizontal offset of guard pattern, as an array of two ints
// @throws NotFoundException if pattern is not found
func upceanReader_findGuardPatternWithCounters(
	row *gozxing.BitArray, rowOffset int, whiteFirst bool, pattern, counters []int) ([]int, error) {

	width := row.GetSize()
	if whiteFirst {
		rowOffset = row.GetNextUnset(rowOffset)
	} else {
		rowOffset = row.GetNextSet(rowOffset)
	}
	counterPosition := 0
	patternStart := rowOffset
	patternLength := len(pattern)
	isWhite := whiteFirst
	for x := rowOffset; x < width; x++ {
		if row.Get(x) != isWhite {
			counters[counterPosition]++
		} else {
			if counterPosition == patternLength-1 {
				if PatternMatchVariance(counters, pattern, UPCEANReader_MAX_INDIVIDUAL_VARIANCE) < UPCEANReader_MAX_AVG_VARIANCE {
					return []int{patternStart, x}, nil
				}
				patternStart += counters[0] + counters[1]
				copy(counters[:counterPosition-1], counters[2:counterPosition+1])
				counters[counterPosition-1] = 0
				counters[counterPosition] = 0
				counterPosition--
			} else {
				counterPosition++
			}
			counters[counterPosition] = 1
			isWhite = !isWhite
		}
	}
	return nil, gozxing.NewNotFoundException()
}

// UPCEANReader_decodeDigit Attempts to decode a single UPC/EAN-encoded digit.
//
// @param row row of black/white values to decode
// @param counters the counts of runs of observed black/white/black/... values
// @param rowOffset horizontal offset to start decoding from
// @param patterns the set of patterns to use to decode -- sometimes different encodings
// for the digits 0-9 are used, and this indicates the encodings for 0 to 9 that should
// be used
// @return horizontal offset of first pixel beyond the decoded digit
// @throws NotFoundException if digit cannot be decoded
func upceanReader_decodeDigit(row *gozxing.BitArray, counters []int, rowOffset int, patterns [][]int) (int, error) {
	e := RecordPattern(row, rowOffset, counters)
	if e != nil {
		return 0, e
	}
	bestVariance := UPCEANReader_MAX_AVG_VARIANCE // worst variance we'll accept
	bestMatch := -1
	max := len(patterns)
	for i := 0; i < max; i++ {
		pattern := patterns[i]
		variance := PatternMatchVariance(counters, pattern, UPCEANReader_MAX_INDIVIDUAL_VARIANCE)
		if variance < bestVariance {
			bestVariance = variance
			bestMatch = i
		}
	}
	if bestMatch < 0 {
		return 0, gozxing.NewNotFoundException()
	}
	return bestMatch, nil
}
