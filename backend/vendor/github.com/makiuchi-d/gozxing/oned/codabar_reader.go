package oned

import (
	"math"

	"github.com/makiuchi-d/gozxing"
)

// Decodes Codabar barcodes.

// These values are critical for determining how permissive the decoding
// will be. All stripe sizes must be within the window these define, as
// compared to the average stripe size.
const codabarReader_MAX_ACCEPTABLE = 2.0
const codabarReader_PADDING = 1.5

const codabarReader_ALPHABET = "0123456789-$:/.+ABCD"

// These represent the encodings of characters, as patterns of wide and narrow bars.
// The 7 least-significant bits of each int correspond to the pattern of wide and narrow,
// with 1s representing "wide" and 0s representing narrow.
var codabarReader_CHARACTER_ENCODINGS = []int{
	0x003, 0x006, 0x009, 0x060, 0x012, 0x042, 0x021, 0x024, 0x030, 0x048, // 0-9
	0x00c, 0x018, 0x045, 0x051, 0x054, 0x015, 0x01A, 0x029, 0x00B, 0x00E, // -$:/.+ABCD
}

// minimal number of characters that should be present (including start and stop characters)
// under normal circumstances this should be set to 3, but can be set higher
// as a last-ditch attempt to reduce false positives.
const codabarReader_MIN_CHARACTER_LENGTH = 3

// official start and end patterns
var codabarReader_STARTEND_ENCODING = []byte{'A', 'B', 'C', 'D'}

// some Codabar generator allow the Codabar string to be closed by every
// character. This will cause lots of false positives!

// some industries use a checksum standard but this is not part of the original Codabar standard
// for more information see : http://www.mecsw.com/specs/codabar.html

type codabarReader struct {
	*OneDReader

	// Keep some instance variables to avoid reallocations
	decodeRowResult []byte
	counters        []int
	counterLength   int
}

func NewCodaBarReader() gozxing.Reader {
	reader := &codabarReader{
		decodeRowResult: make([]byte, 0, 20),
		counters:        make([]int, 0, 80),
		counterLength:   0,
	}
	reader.OneDReader = NewOneDReader(reader)
	return reader
}

func (this *codabarReader) DecodeRow(rowNumber int, row *gozxing.BitArray, hints map[gozxing.DecodeHintType]interface{}) (*gozxing.Result, error) {

	this.counters = this.counters[:0]
	e := this.setCounters(row)
	if e != nil {
		return nil, e
	}
	startOffset, e := this.findStartPattern()
	if e != nil {
		return nil, e
	}
	nextStart := startOffset

	this.decodeRowResult = this.decodeRowResult[:0]
	for nextStart < this.counterLength {
		charOffset := this.toNarrowWidePattern(nextStart)
		if charOffset == -1 {
			return nil, gozxing.NewNotFoundException()
		}
		// Hack: We store the position in the alphabet table into a
		// StringBuilder, so that we can access the decoded patterns in
		// validatePattern. We'll translate to the actual characters later.
		this.decodeRowResult = append(this.decodeRowResult, byte(charOffset))
		nextStart += 8
		// Stop as soon as we see the end character.
		if len(this.decodeRowResult) > 1 &&
			codabarReader_arrayContains(codabarReader_STARTEND_ENCODING, codabarReader_ALPHABET[charOffset]) {
			break
		}
	} // no fixed end pattern so keep on reading while data is available

	// Look for whitespace after pattern:
	trailingWhitespace := this.counters[nextStart-1]
	lastPatternSize := 0
	for i := -8; i < -1; i++ {
		lastPatternSize += this.counters[nextStart+i]
	}

	// We need to see whitespace equal to 50% of the last pattern size,
	// otherwise this is probably a false positive. The exception is if we are
	// at the end of the row. (I.e. the barcode barely fits.)
	if nextStart < this.counterLength && trailingWhitespace < lastPatternSize/2 {
		return nil, gozxing.NewNotFoundException()
	}

	e = this.validatePattern(startOffset)
	if e != nil {
		return nil, e
	}

	// Translate character table offsets to actual characters.
	for i := 0; i < len(this.decodeRowResult); i++ {
		this.decodeRowResult[i] = codabarReader_ALPHABET[this.decodeRowResult[i]]
	}
	// Ensure a valid start and end character
	startchar := this.decodeRowResult[0]
	if !codabarReader_arrayContains(codabarReader_STARTEND_ENCODING, startchar) {
		return nil, gozxing.NewNotFoundException()
	}
	endchar := this.decodeRowResult[len(this.decodeRowResult)-1]
	if !codabarReader_arrayContains(codabarReader_STARTEND_ENCODING, endchar) {
		return nil, gozxing.NewNotFoundException()
	}

	// remove stop/start characters character and check if a long enough string is contained
	if len(this.decodeRowResult) <= codabarReader_MIN_CHARACTER_LENGTH {
		// Almost surely a false positive ( start + stop + at least 1 character)
		return nil, gozxing.NewNotFoundException()
	}

	if _, ok := hints[gozxing.DecodeHintType_RETURN_CODABAR_START_END]; !ok {
		this.decodeRowResult = this.decodeRowResult[1 : len(this.decodeRowResult)-1]
	}

	runningCount := 0
	for i := 0; i < startOffset; i++ {
		runningCount += this.counters[i]
	}
	left := float64(runningCount)
	for i := startOffset; i < nextStart-1; i++ {
		runningCount += this.counters[i]
	}
	right := float64(runningCount)
	result := gozxing.NewResult(
		string(this.decodeRowResult),
		nil,
		[]gozxing.ResultPoint{
			gozxing.NewResultPoint(left, float64(rowNumber)),
			gozxing.NewResultPoint(right, float64(rowNumber))},
		gozxing.BarcodeFormat_CODABAR)
	result.PutMetadata(gozxing.ResultMetadataType_SYMBOLOGY_IDENTIFIER, "]F0")
	return result, nil
}

func (this *codabarReader) validatePattern(start int) error {
	// First, sum up the total size of our four categories of stripe sizes;
	sizes := []int{0, 0, 0, 0}
	counts := []int{0, 0, 0, 0}
	end := len(this.decodeRowResult) - 1

	// We break out of this loop in the middle, in order to handle
	// inter-character spaces properly.
	pos := start
	for i := 0; i <= end; i++ {
		pattern := codabarReader_CHARACTER_ENCODINGS[this.decodeRowResult[i]]
		for j := 6; j >= 0; j-- {
			// Even j = bars, while odd j = spaces. Categories 2 and 3 are for
			// long stripes, while 0 and 1 are for short stripes.
			category := (j & 1) + (pattern&1)*2
			sizes[category] += this.counters[pos+j]
			counts[category]++
			pattern >>= 1
		}
		// We ignore the inter-character space - it could be of any size.
		pos += 8
	}

	// Calculate our allowable size thresholds using fixed-point math.
	maxes := make([]float64, 4)
	mins := make([]float64, 4)
	// Define the threshold of acceptability to be the midpoint between the
	// average small stripe and the average large stripe. No stripe lengths
	// should be on the "wrong" side of that line.
	for i := 0; i < 2; i++ {
		mins[i] = 0.0 // Accept arbitrarily small "short" stripes.
		mins[i+2] = (float64(sizes[i])/float64(counts[i]) + float64(sizes[i+2])/float64(counts[i+2])) / 2.0
		maxes[i] = mins[i+2]
		maxes[i+2] = (float64(sizes[i+2])*codabarReader_MAX_ACCEPTABLE + codabarReader_PADDING) / float64(counts[i+2])
	}

	// Now verify that all of the stripes are within the thresholds.
	pos = start
	for i := 0; i <= end; i++ {
		pattern := codabarReader_CHARACTER_ENCODINGS[this.decodeRowResult[i]]
		for j := 6; j >= 0; j-- {
			// Even j = bars, while odd j = spaces. Categories 2 and 3 are for
			// long stripes, while 0 and 1 are for short stripes.
			category := (j & 1) + (pattern&1)*2
			size := float64(this.counters[pos+j])
			if size < mins[category] || size > maxes[category] {
				return gozxing.NewNotFoundException()
			}
			pattern >>= 1
		}
		pos += 8
	}
	return nil
}

// setCounters Records the size of all runs of white and black pixels, starting with white.
// This is just like recordPattern, except it records all the counters, and
// uses our builtin "counters" member for storage.
// @param row row to count from
func (this *codabarReader) setCounters(row *gozxing.BitArray) error {
	this.counterLength = 0
	// Start from the first white bit.
	i := row.GetNextUnset(0)
	end := row.GetSize()
	if i >= end {
		return gozxing.NewNotFoundException()
	}
	isWhite := true
	count := 0
	for i < end {
		if row.Get(i) != isWhite {
			count++
		} else {
			this.counterAppend(count)
			count = 1
			isWhite = !isWhite
		}
		i++
	}
	this.counterAppend(count)
	return nil
}

func (this *codabarReader) counterAppend(e int) {
	this.counters = append(this.counters, e)
	this.counterLength++
}

func (this *codabarReader) findStartPattern() (int, error) {
	for i := 1; i < this.counterLength; i += 2 {
		charOffset := this.toNarrowWidePattern(i)
		if charOffset != -1 &&
			codabarReader_arrayContains(codabarReader_STARTEND_ENCODING, codabarReader_ALPHABET[charOffset]) {
			// Look for whitespace before start pattern, >= 50% of width of start pattern
			// We make an exception if the whitespace is the first element.
			patternSize := 0
			for j := i; j < i+7; j++ {
				patternSize += this.counters[j]
			}
			if i == 1 || this.counters[i-1] >= patternSize/2 {
				return i, nil
			}
		}
	}
	return 0, gozxing.NewNotFoundException()
}

func codabarReader_arrayContains(array []byte, key byte) bool {
	for _, c := range array {
		if c == key {
			return true
		}
	}
	return false
}

// Assumes that counters[position] is a bar.
func (this *codabarReader) toNarrowWidePattern(position int) int {
	end := position + 7
	if end >= this.counterLength {
		return -1
	}

	theCounters := this.counters

	maxBar := 0
	minBar := math.MaxInt32
	for j := position; j < end; j += 2 {
		currentCounter := theCounters[j]
		if currentCounter < minBar {
			minBar = currentCounter
		}
		if currentCounter > maxBar {
			maxBar = currentCounter
		}
	}
	thresholdBar := (minBar + maxBar) / 2

	maxSpace := 0
	minSpace := math.MaxInt32
	for j := position + 1; j < end; j += 2 {
		currentCounter := theCounters[j]
		if currentCounter < minSpace {
			minSpace = currentCounter
		}
		if currentCounter > maxSpace {
			maxSpace = currentCounter
		}
	}
	thresholdSpace := (minSpace + maxSpace) / 2

	bitmask := 1 << 7
	pattern := 0
	for i := 0; i < 7; i++ {
		threshold := thresholdSpace
		if (i & 1) == 0 {
			threshold = thresholdBar
		}
		bitmask >>= 1
		if theCounters[position+i] > threshold {
			pattern |= bitmask
		}
	}

	for i := 0; i < len(codabarReader_CHARACTER_ENCODINGS); i++ {
		if codabarReader_CHARACTER_ENCODINGS[i] == pattern {
			return i
		}
	}
	return -1
}
