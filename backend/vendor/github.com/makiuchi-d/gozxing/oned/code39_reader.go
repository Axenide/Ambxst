package oned

// Decodes Code 39 barcodes. Supports "Full ASCII Code 39" if USE_CODE_39_EXTENDED_MODE is set.

import (
	"math"
	"strings"

	"github.com/makiuchi-d/gozxing"
)

const code39AlphabetString = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-. $/+%"

// code39CharacterEncodings These represent the encodings of characters, as patterns of wide and narrow bars.
// The 9 least-significant bits of each int correspond to the pattern of wide and narrow,
// with 1s representing "wide" and 0s representing narrow.
var code39CharacterEncodings = []int{
	0x034, 0x121, 0x061, 0x160, 0x031, 0x130, 0x070, 0x025, 0x124, 0x064, // 0-9
	0x109, 0x049, 0x148, 0x019, 0x118, 0x058, 0x00D, 0x10C, 0x04C, 0x01C, // A-J
	0x103, 0x043, 0x142, 0x013, 0x112, 0x052, 0x007, 0x106, 0x046, 0x016, // K-T
	0x181, 0x0C1, 0x1C0, 0x091, 0x190, 0x0D0, 0x085, 0x184, 0x0C4, 0x0A8, // U-$
	0x0A2, 0x08A, 0x02A, // /-%
}

const code39AsteriskEncoding = 0x094

type code39Reader struct {
	*OneDReader
	usingCheckDigit bool
	extendedMode    bool
	decodeRowResult []byte
	counters        []int
}

// NewCode39Reader Creates a reader that assumes all encoded data is data, and does not treat the final
// character as a check digit. It will not decoded "extended Code 39" sequences.
func NewCode39Reader() gozxing.Reader {
	return NewCode39ReaderWithCheckDigitFlag(false)
}

// NewCode39ReaderWithCheckDigitFlag Creates a reader that can be configured to check the last character as a check digit.
// It will not decoded "extended Code 39" sequences.
//
// @param usingCheckDigit if true, treat the last data character as a check digit, not
// data, and verify that the checksum passes.
func NewCode39ReaderWithCheckDigitFlag(usingCheckDigit bool) gozxing.Reader {
	return NewCode39ReaderWithFlags(usingCheckDigit, false)
}

// NewCode39ReaderWithFlags Creates a reader that can be configured to check the last character as a check digit,
// or optionally attempt to decode "extended Code 39" sequences that are used to encode
// the full ASCII character set.
//
// @param usingCheckDigit if true, treat the last data character as a check digit, not
// data, and verify that the checksum passes.
// @param extendedMode if true, will attempt to decode extended Code 39 sequences in the
// text.
func NewCode39ReaderWithFlags(usingCheckDigit, extendedMode bool) gozxing.Reader {
	this := &code39Reader{
		usingCheckDigit: usingCheckDigit,
		extendedMode:    extendedMode,
		decodeRowResult: make([]byte, 0, 20),
		counters:        make([]int, 9),
	}
	this.OneDReader = NewOneDReader(this)
	return this
}

func (this *code39Reader) DecodeRow(rowNumber int, row *gozxing.BitArray, hints map[gozxing.DecodeHintType]interface{}) (*gozxing.Result, error) {

	theCounters := this.counters
	for i := range theCounters {
		theCounters[i] = 0
	}
	result := this.decodeRowResult[:0]

	startLeft, startRight, e := code39FindAsteriskPattern(row, theCounters)
	if e != nil {
		return nil, e
	}
	// Read off white space
	nextStart := row.GetNextSet(startRight)
	end := row.GetSize()

	var lastStart int
	for {
		e := RecordPattern(row, nextStart, theCounters)
		if e != nil {
			return nil, gozxing.WrapNotFoundException(e)
		}
		pattern := code39ToNarrowWidePattern(theCounters)
		if pattern < 0 {
			return nil, gozxing.NewNotFoundException("counters = %v", theCounters)
		}
		decodedChar, e := code39PatternToChar(pattern)
		if e != nil {
			return nil, e
		}
		result = append(result, decodedChar)
		lastStart = nextStart
		for _, counter := range theCounters {
			nextStart += counter
		}
		// Read off white space
		nextStart = row.GetNextSet(nextStart)
		if decodedChar == '*' {
			break
		}
	}
	result = result[:len(result)-1] // remove asterisk

	// Look for whitespace after pattern:
	lastPatternSize := 0
	for _, counter := range theCounters {
		lastPatternSize += counter
	}
	whiteSpaceAfterEnd := nextStart - lastStart - lastPatternSize
	// If 50% of last pattern size, following last pattern, is not whitespace, fail
	// (but if it's whitespace to the very end of the image, that's OK)
	if nextStart != end && (whiteSpaceAfterEnd*2) < lastPatternSize {
		return nil, gozxing.NewNotFoundException(
			"nextStart=%d, end=%d, whiteSpaceAfterEnd=%d, lastPatternSize=%d",
			nextStart, end, whiteSpaceAfterEnd, lastPatternSize)
	}

	if this.usingCheckDigit {
		max := len(result) - 1
		total := 0
		for i := 0; i < max; i++ {
			total += strings.Index(code39AlphabetString, string(result[i]))
		}
		if s, t := result[max], code39AlphabetString[total%43]; s != t {
			return nil, gozxing.NewChecksumException("lastchar=0x%02x, wants 0x%02x", s, t)
		}
		result = result[:max]
	}

	if len(result) == 0 {
		// false positive
		return nil, gozxing.NewNotFoundException("empty result")
	}

	var resultString string
	if this.extendedMode {
		var e error
		resultString, e = code39DecodeExtended(result)
		if e != nil {
			return nil, e
		}
	} else {
		resultString = string(result)
	}

	left := float64(startLeft+startRight) / 2.0
	right := float64(lastStart) + float64(lastPatternSize)/2.0
	rowNumberf := float64(rowNumber)
	resultObject := gozxing.NewResult(
		resultString,
		nil,
		[]gozxing.ResultPoint{
			gozxing.NewResultPoint(left, rowNumberf),
			gozxing.NewResultPoint(right, rowNumberf)},
		gozxing.BarcodeFormat_CODE_39)
	resultObject.PutMetadata(gozxing.ResultMetadataType_SYMBOLOGY_IDENTIFIER, "]A0")
	return resultObject, nil
}

func code39FindAsteriskPattern(row *gozxing.BitArray, counters []int) (int, int, error) {
	width := row.GetSize()
	rowOffset := row.GetNextSet(0)

	counterPosition := 0
	patternStart := rowOffset
	isWhite := false
	patternLength := len(counters)

	for i := rowOffset; i < width; i++ {
		if row.Get(i) != isWhite {
			counters[counterPosition]++
		} else {
			if counterPosition == patternLength-1 {
				// Look for whitespace before start pattern, >= 50% of width of start pattern
				if code39ToNarrowWidePattern(counters) == code39AsteriskEncoding {
					if b, _ := row.IsRange(max(0, patternStart-((i-patternStart)/2)), patternStart, false); b {
						return patternStart, i, nil
					}
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
	return 0, 0, gozxing.NewNotFoundException()
}

// For efficiency, returns -1 on failure. Not throwing here saved as many as 700 exceptions
// per image when using some of our blackbox images.
func code39ToNarrowWidePattern(counters []int) int {
	numCounters := len(counters)
	maxNarrowCounter := 0
	wideCounters := 0
	for {
		minCounter := math.MaxInt32
		for _, counter := range counters {
			if counter < minCounter && counter > maxNarrowCounter {
				minCounter = counter
			}
		}
		maxNarrowCounter = minCounter
		wideCounters = 0
		totalWideCountersWidth := 0
		pattern := 0
		for i := 0; i < numCounters; i++ {
			counter := counters[i]
			if counter > maxNarrowCounter {
				pattern |= 1 << uint(numCounters-1-i)
				wideCounters++
				totalWideCountersWidth += counter
			}
		}
		if wideCounters == 3 {
			// Found 3 wide counters, but are they close enough in width?
			// We can perform a cheap, conservative check to see if any individual
			// counter is more than 1.5 times the average:
			for i := 0; i < numCounters && wideCounters > 0; i++ {
				counter := counters[i]
				if counter > maxNarrowCounter {
					wideCounters--
					// totalWideCountersWidth = 3 * average, so this checks if counter >= 3/2 * average
					if (counter * 2) >= totalWideCountersWidth {
						return -1
					}
				}
			}
			return pattern
		}
		if !(wideCounters > 3) {
			break
		}
	}
	return -1
}

func code39PatternToChar(pattern int) (byte, error) {
	for i := 0; i < len(code39CharacterEncodings); i++ {
		if code39CharacterEncodings[i] == pattern {
			return code39AlphabetString[i], nil
		}
	}
	if pattern == code39AsteriskEncoding {
		return '*', nil
	}
	return 0, gozxing.NewNotFoundException("pattern = %d", pattern)
}

func code39DecodeExtended(encoded []byte) (string, error) {
	length := len(encoded)
	decoded := make([]byte, 0, length)
	for i := 0; i < length; i++ {
		c := encoded[i]
		if c == '+' || c == '$' || c == '%' || c == '/' {
			next := encoded[i+1]
			decodedChar := byte(0)
			switch c {
			case '+':
				// +A to +Z map to a to z
				if next >= 'A' && next <= 'Z' {
					decodedChar = next + 32
				} else {
					return string(decoded), gozxing.NewFormatException("encoded = '+'0x%02x", next)
				}
				break
			case '$':
				// $A to $Z map to control codes SH to SB
				if next >= 'A' && next <= 'Z' {
					decodedChar = next - 64
				} else {
					return string(decoded), gozxing.NewFormatException("encoded = '$'0x%02x", next)
				}
				break
			case '%':
				// %A to %E map to control codes ESC to US
				if next >= 'A' && next <= 'E' {
					decodedChar = next - 38
				} else if next >= 'F' && next <= 'J' {
					decodedChar = next - 11
				} else if next >= 'K' && next <= 'O' {
					decodedChar = next + 16
				} else if next >= 'P' && next <= 'T' {
					decodedChar = next + 43
				} else if next == 'U' {
					decodedChar = 0
				} else if next == 'V' {
					decodedChar = '@'
				} else if next == 'W' {
					decodedChar = '`'
				} else if next == 'X' || next == 'Y' || next == 'Z' {
					decodedChar = 127
				} else {
					return string(decoded), gozxing.NewFormatException("encoded = '%%'0x%02x", next)
				}
				break
			case '/':
				// /A to /O map to ! to , and /Z maps to :
				if next >= 'A' && next <= 'O' {
					decodedChar = next - 32
				} else if next == 'Z' {
					decodedChar = ':'
				} else {
					return string(decoded), gozxing.NewFormatException("encoded = '/'0x%02x", next)
				}
				break
			}
			decoded = append(decoded, decodedChar)
			// bump up i again since we read two characters
			i++
		} else {
			decoded = append(decoded, c)
		}
	}
	return string(decoded), nil
}
