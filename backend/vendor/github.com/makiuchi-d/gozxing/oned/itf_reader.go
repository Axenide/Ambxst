package oned

import (
	"github.com/makiuchi-d/gozxing"
)

// Implements decoding of the ITF format, or Interleaved Two of Five.
//
// This Reader will scan ITF barcodes of certain lengths only.
// At the moment it reads length 6, 8, 10, 12, 14, 16, 18, 20, 24,
// and 44 as these have appeared "in the wild".
// Not all lengths are scanned, especially shorter ones, to avoid false positives.
// This in turn is due to a lack of required checksum function.
//
// The checksum is optional and is not applied by this Reader. The consumer of the decoded
// value will have to apply a checksum if required.
//
// http://en.wikipedia.org/wiki/Interleaved_2_of_5
// is a great reference for Interleaved 2 of 5 information.

const (
	itfReader_MAX_AVG_VARIANCE        = 0.38
	itfReader_MAX_INDIVIDUAL_VARIANCE = 0.5

	itfReader_W = 3 // Pixel width of a 3x wide line
	itfReader_w = 2 // Pixel width of a 2x wide line
	itfReader_N = 1 // Pixed width of a narrow line

)

var (
	// Valid ITF lengths. Anything longer than the largest value is also allowed.
	itfReader_DEFAULT_ALLOWED_LENGTHS = []int{6, 8, 10, 12, 14}

	// Start/end guard pattern.
	//
	// Note: The end pattern is reversed because the row is reversed before
	// searching for the END_PATTERN
	//
	itfReader_START_PATTERN        = []int{itfReader_N, itfReader_N, itfReader_N, itfReader_N}
	itfReader_END_PATTERN_REVERSED = [][]int{
		{itfReader_N, itfReader_N, itfReader_w}, // 2x
		{itfReader_N, itfReader_N, itfReader_W}, // 3x
	}

	// See ITFWriter.PATTERNS

	// Patterns of Wide / Narrow lines to indicate each digit
	itfReader_PATTERNS = [][]int{
		{itfReader_N, itfReader_N, itfReader_w, itfReader_w, itfReader_N}, // 0
		{itfReader_w, itfReader_N, itfReader_N, itfReader_N, itfReader_w}, // 1
		{itfReader_N, itfReader_w, itfReader_N, itfReader_N, itfReader_w}, // 2
		{itfReader_w, itfReader_w, itfReader_N, itfReader_N, itfReader_N}, // 3
		{itfReader_N, itfReader_N, itfReader_w, itfReader_N, itfReader_w}, // 4
		{itfReader_w, itfReader_N, itfReader_w, itfReader_N, itfReader_N}, // 5
		{itfReader_N, itfReader_w, itfReader_w, itfReader_N, itfReader_N}, // 6
		{itfReader_N, itfReader_N, itfReader_N, itfReader_w, itfReader_w}, // 7
		{itfReader_w, itfReader_N, itfReader_N, itfReader_w, itfReader_N}, // 8
		{itfReader_N, itfReader_w, itfReader_N, itfReader_w, itfReader_N}, // 9
		{itfReader_N, itfReader_N, itfReader_W, itfReader_W, itfReader_N}, // 0
		{itfReader_W, itfReader_N, itfReader_N, itfReader_N, itfReader_W}, // 1
		{itfReader_N, itfReader_W, itfReader_N, itfReader_N, itfReader_W}, // 2
		{itfReader_W, itfReader_W, itfReader_N, itfReader_N, itfReader_N}, // 3
		{itfReader_N, itfReader_N, itfReader_W, itfReader_N, itfReader_W}, // 4
		{itfReader_W, itfReader_N, itfReader_W, itfReader_N, itfReader_N}, // 5
		{itfReader_N, itfReader_W, itfReader_W, itfReader_N, itfReader_N}, // 6
		{itfReader_N, itfReader_N, itfReader_N, itfReader_W, itfReader_W}, // 7
		{itfReader_W, itfReader_N, itfReader_N, itfReader_W, itfReader_N}, // 8
		{itfReader_N, itfReader_W, itfReader_N, itfReader_W, itfReader_N}, // 9
	}
)

type itfReader struct {
	*OneDReader

	// Stores the actual narrow line width of the image being decoded.
	narrowLineWidth int
}

func NewITFReader() gozxing.Reader {
	reader := &itfReader{
		narrowLineWidth: -1,
	}
	reader.OneDReader = NewOneDReader(reader)
	return reader
}

func (this *itfReader) DecodeRow(rowNumber int, row *gozxing.BitArray, hints map[gozxing.DecodeHintType]interface{}) (*gozxing.Result, error) {

	// Find out where the Middle section (payload) starts & ends
	startRange, e := this.decodeStart(row)
	if e != nil {
		return nil, e
	}
	endRange, e := this.decodeEnd(row)
	if e != nil {
		return nil, e
	}

	result := make([]byte, 0, 20)
	result, e = this.decodeMiddle(row, startRange[1], endRange[0], result)
	if e != nil {
		return nil, e
	}

	resultString := string(result)

	allowedLengths, ok := hints[gozxing.DecodeHintType_ALLOWED_LENGTHS].([]int)
	if !ok {
		allowedLengths = itfReader_DEFAULT_ALLOWED_LENGTHS
	}

	// To avoid false positives with 2D barcodes (and other patterns), make
	// an assumption that the decoded string must be a 'standard' length if it's short
	length := len(resultString)
	lengthOK := false
	maxAllowedLength := 0
	for _, allowedLength := range allowedLengths {
		if length == allowedLength {
			lengthOK = true
			break
		}
		if allowedLength > maxAllowedLength {
			maxAllowedLength = allowedLength
		}
	}
	if !lengthOK && length > maxAllowedLength {
		lengthOK = true
	}
	if !lengthOK {
		return nil, gozxing.NewFormatException("length=%v", length)
	}

	resultObject := gozxing.NewResult(
		resultString,
		nil, // no natural byte representation for these barcodes
		[]gozxing.ResultPoint{
			gozxing.NewResultPoint(float64(startRange[1]), float64(rowNumber)),
			gozxing.NewResultPoint(float64(endRange[0]), float64(rowNumber)),
		},
		gozxing.BarcodeFormat_ITF)
	resultObject.PutMetadata(gozxing.ResultMetadataType_SYMBOLOGY_IDENTIFIER, "]I0")
	return resultObject, nil
}

// decodeMiddle decode middle
// @param row          row of black/white values to search
// @param payloadStart offset of start pattern
// @param resultString {@link StringBuilder} to append decoded chars to
// @throws NotFoundException if decoding could not complete successfully
//
func (*itfReader) decodeMiddle(row *gozxing.BitArray, payloadStart, payloadEnd int, resultString []byte) ([]byte, error) {

	// Digits are interleaved in pairs - 5 black lines for one digit, and the
	// 5
	// interleaved white lines for the second digit.
	// Therefore, need to scan 10 lines and then
	// split these into two arrays
	counterDigitPair := make([]int, 10)
	counterBlack := make([]int, 5)
	counterWhite := make([]int, 5)

	for payloadStart < payloadEnd {

		// Get 10 runs of black/white.
		e := RecordPattern(row, payloadStart, counterDigitPair)
		if e != nil {
			return resultString, gozxing.WrapNotFoundException(e)
		}
		// Split them into each array
		for k := 0; k < 5; k++ {
			twoK := 2 * k
			counterBlack[k] = counterDigitPair[twoK]
			counterWhite[k] = counterDigitPair[twoK+1]
		}

		bestMatch, e := itfReader_decodeDigit(counterBlack)
		if e != nil {
			return resultString, gozxing.WrapNotFoundException(e)
		}
		resultString = append(resultString, byte('0'+bestMatch))
		bestMatch, e = itfReader_decodeDigit(counterWhite)
		if e != nil {
			return resultString, gozxing.WrapNotFoundException(e)
		}
		resultString = append(resultString, byte('0'+bestMatch))

		for _, counterDigit := range counterDigitPair {
			payloadStart += counterDigit
		}
	}
	return resultString, nil
}

// decodeStart Identify where the start of the middle / payload section starts.
//
// @param row row of black/white values to search
// @return Array, containing index of start of 'start block' and end of 'start block'
//
func (this *itfReader) decodeStart(row *gozxing.BitArray) ([]int, error) {
	endStart, e := itfReader_skipWhiteSpace(row)
	if e != nil {
		return nil, gozxing.WrapNotFoundException(e)
	}
	startPattern, e := itfReader_findGuardPattern(row, endStart, itfReader_START_PATTERN)
	if e != nil {
		return nil, gozxing.WrapNotFoundException(e)
	}

	// Determine the width of a narrow line in pixels. We can do this by
	// getting the width of the start pattern and dividing by 4 because its
	// made up of 4 narrow lines.
	this.narrowLineWidth = (startPattern[1] - startPattern[0]) / 4

	e = this.validateQuietZone(row, startPattern[0])
	if e != nil {
		return nil, gozxing.WrapNotFoundException(e)
	}

	return startPattern, nil
}

// validateQuietZone The start & end patterns must be pre/post fixed by a quiet zone.
// This zone must be at least 10 times the width of a narrow line.  Scan back until
// we either get to the start of the barcode or match the necessary number of
// quiet zone pixels.
//
// Note: Its assumed the row is reversed when using this method to find
// quiet zone after the end pattern.
//
// ref: http://www.barcode-1.net/i25code.html
//
// @param row bit array representing the scanned barcode.
// @param startPattern index into row of the start or end pattern.
// @throws NotFoundException if the quiet zone cannot be found
//
func (this *itfReader) validateQuietZone(row *gozxing.BitArray, startPattern int) error {
	quietCount := this.narrowLineWidth * 10 // expect to find this many pixels of quiet zone

	// if there are not so many pixel at all let's try as many as possible
	if !(quietCount < startPattern) {
		quietCount = startPattern
	}

	for i := startPattern - 1; quietCount > 0 && i >= 0; i-- {
		if row.Get(i) {
			break
		}
		quietCount--
	}
	if quietCount != 0 {
		// Unable to find the necessary number of quiet zone pixels.
		return gozxing.NewNotFoundException()
	}
	return nil
}

// itfReader_skipWhiteSpace Skip all whitespace until we get to the first black line.
//
// @param row row of black/white values to search
// @return index of the first black line.
// @throws NotFoundException Throws exception if no black lines are found in the row
//
func itfReader_skipWhiteSpace(row *gozxing.BitArray) (int, error) {
	width := row.GetSize()
	endStart := row.GetNextSet(0)
	if endStart == width {
		return endStart, gozxing.NewNotFoundException()
	}

	return endStart, nil
}

// decodeEnd Identify where the end of the middle / payload section ends.
//
// @param row row of black/white values to search
// @return Array, containing index of start of 'end block' and end of 'end block'
//
func (this *itfReader) decodeEnd(row *gozxing.BitArray) ([]int, error) {

	// For convenience, reverse the row and then
	// search from 'the start' for the end block
	row.Reverse()
	defer row.Reverse() // Put the row back the right way.

	endStart, e := itfReader_skipWhiteSpace(row)
	if e != nil {
		return nil, gozxing.WrapNotFoundException(e)
	}

	endPattern, e := itfReader_findGuardPattern(row, endStart, itfReader_END_PATTERN_REVERSED[0])
	if _, ok := e.(gozxing.NotFoundException); ok {
		endPattern, e = itfReader_findGuardPattern(row, endStart, itfReader_END_PATTERN_REVERSED[1])
	}
	if e != nil {
		return nil, gozxing.WrapNotFoundException(e)
	}

	// The start & end patterns must be pre/post fixed by a quiet zone. This
	// zone must be at least 10 times the width of a narrow line.
	// ref: http://www.barcode-1.net/i25code.html
	e = this.validateQuietZone(row, endPattern[0])
	if e != nil {
		return nil, gozxing.WrapNotFoundException(e)
	}
	// Now recalculate the indices of where the 'endblock' starts & stops to
	// accommodate
	// the reversed nature of the search
	temp := endPattern[0]
	endPattern[0] = row.GetSize() - endPattern[1]
	endPattern[1] = row.GetSize() - temp

	return endPattern, nil
}

// itfReader_findGuardPattern finds guard pattern
// @param row       row of black/white values to search
// @param rowOffset position to start search
// @param pattern   pattern of counts of number of black and white pixels that are
//                  being searched for as a pattern
// @return start/end horizontal offset of guard pattern, as an array of two ints
// @throws NotFoundException if pattern is not found
//
func itfReader_findGuardPattern(row *gozxing.BitArray, rowOffset int, pattern []int) ([]int, error) {
	patternLength := len(pattern)
	counters := make([]int, patternLength)
	width := row.GetSize()
	isWhite := false

	counterPosition := 0
	patternStart := rowOffset
	for x := rowOffset; x < width; x++ {
		if row.Get(x) != isWhite {
			counters[counterPosition]++
		} else {
			if counterPosition == patternLength-1 {
				if PatternMatchVariance(counters, pattern, itfReader_MAX_INDIVIDUAL_VARIANCE) < itfReader_MAX_AVG_VARIANCE {
					return []int{patternStart, x}, nil
				}
				patternStart += counters[0] + counters[1]
				copy(counters, counters[2:2+counterPosition-1])
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

// itfReader_decodeDigit Attempts to decode a sequence of ITF black/white lines into single digit.
//
// @param counters the counts of runs of observed black/white/black/... values
// @return The decoded digit
// @throws NotFoundException if digit cannot be decoded
//
func itfReader_decodeDigit(counters []int) (int, error) {
	bestVariance := itfReader_MAX_AVG_VARIANCE // worst variance we'll accept
	bestMatch := -1
	max := len(itfReader_PATTERNS)
	for i := 0; i < max; i++ {
		pattern := itfReader_PATTERNS[i]
		variance := PatternMatchVariance(counters, pattern, itfReader_MAX_INDIVIDUAL_VARIANCE)
		if variance < bestVariance {
			bestVariance = variance
			bestMatch = i
		} else if variance == bestVariance {
			// if we find a second 'best match' with the same variance, we can not reliably report to have a suitable match
			bestMatch = -1
		}
	}
	if bestMatch >= 0 {
		return bestMatch % 10, nil
	} else {
		return 0, gozxing.NewNotFoundException()
	}
}
