package oned

import (
	"strings"

	"github.com/makiuchi-d/gozxing"
)

// Decodes Code 93 barcodes.

// code93AlphabetString Note that 'abcd' are dummy characters in place of control characters.
// ($)=a, (%)=b, (/)=c, (+)=d
const code93AlphabetString = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-. $/+%abcd*"

var code93Alphabet = []byte(code93AlphabetString)

// code93CharacterEncodings These represent the encodings of characters, as patterns of wide and narrow bars.
// The 9 least-significant bits of each int correspond to the pattern of wide and narrow.
var code93CharacterEncodings = []int{
	0x114, 0x148, 0x144, 0x142, 0x128, 0x124, 0x122, 0x150, 0x112, 0x10A, // 0-9
	0x1A8, 0x1A4, 0x1A2, 0x194, 0x192, 0x18A, 0x168, 0x164, 0x162, 0x134, // A-J
	0x11A, 0x158, 0x14C, 0x146, 0x12C, 0x116, 0x1B4, 0x1B2, 0x1AC, 0x1A6, // K-T
	0x196, 0x19A, 0x16C, 0x166, 0x136, 0x13A, // U-Z
	0x12E, 0x1D4, 0x1D2, 0x1CA, 0x16E, 0x176, 0x1AE, // - - %
	0x126, 0x1DA, 0x1D6, 0x132, 0x15E, // Control chars? $-*
}

var code93AsteriskEncoding = code93CharacterEncodings[47]

type code93Reader struct {
	*OneDReader
	decodeRowResult []byte
	counters        []int
}

func NewCode93Reader() gozxing.Reader {
	this := &code93Reader{
		decodeRowResult: make([]byte, 0, 20),
		counters:        make([]int, 6),
	}
	this.OneDReader = NewOneDReader(this)
	return this
}

func (this *code93Reader) DecodeRow(rowNumber int, row *gozxing.BitArray, hints map[gozxing.DecodeHintType]interface{}) (*gozxing.Result, error) {

	startLeft, startRight, e := this.findAsteriskPattern(row)
	if e != nil {
		return nil, e
	}
	// Read off white space
	nextStart := row.GetNextSet(startRight)
	end := row.GetSize()

	theCounters := this.counters
	for i := range theCounters {
		theCounters[i] = 0
	}
	result := this.decodeRowResult[:0]

	var lastStart int
	for {
		e := RecordPattern(row, nextStart, theCounters)
		if e != nil {
			return nil, gozxing.WrapNotFoundException(e)
		}
		pattern := code93ToPattern(theCounters)
		if pattern < 0 {
			return nil, gozxing.NewNotFoundException("counters = %v", theCounters)
		}
		decodedChar, e := code93PatternToChar(pattern)
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

	lastPatternSize := 0
	for _, counter := range theCounters {
		lastPatternSize += counter
	}

	// Should be at least one more black module
	if nextStart == end || !row.Get(nextStart) {
		return nil, gozxing.NewNotFoundException("nextStart=%d, end=%d", nextStart, end)
	}

	if len(result) < 2 {
		// false positive -- need at least 2 checksum digits
		return nil, gozxing.NewNotFoundException("len(result) = %d", len(result))
	}

	if e := code93CheckChecksums(result); e != nil {
		return nil, e
	}
	// Remove checksum digits
	result = result[:len(result)-2]

	resultString, e := code93DecodeExtended(result)
	if e != nil {
		return nil, e
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
		gozxing.BarcodeFormat_CODE_93)
	resultObject.PutMetadata(gozxing.ResultMetadataType_SYMBOLOGY_IDENTIFIER, "]G0")
	return resultObject, nil
}

func (this *code93Reader) findAsteriskPattern(row *gozxing.BitArray) (int, int, error) {
	width := row.GetSize()
	rowOffset := row.GetNextSet(0)

	theCounters := this.counters
	for i := range theCounters {
		theCounters[i] = 0
	}
	patternStart := rowOffset
	isWhite := false
	patternLength := len(theCounters)

	counterPosition := 0
	for i := rowOffset; i < width; i++ {
		if row.Get(i) != isWhite {
			theCounters[counterPosition]++
		} else {
			if counterPosition == patternLength-1 {
				if code93ToPattern(theCounters) == code93AsteriskEncoding {
					return patternStart, i, nil
				}
				patternStart += theCounters[0] + theCounters[1]
				copy(theCounters, theCounters[2:2+counterPosition-1])
				theCounters[counterPosition-1] = 0
				theCounters[counterPosition] = 0
				counterPosition--
			} else {
				counterPosition++
			}
			theCounters[counterPosition] = 1
			isWhite = !isWhite
		}
	}
	return 0, 0, gozxing.NewNotFoundException()
}

func code93ToPattern(counters []int) int {
	sum := 0
	for _, counter := range counters {
		sum += counter
	}
	sumf := float64(sum)
	pattern := 0
	max := len(counters)
	for i := 0; i < max; i++ {
		scaled := int(float64(counters[i])*9/sumf + 0.5)
		if scaled < 1 || scaled > 4 {
			return -1
		}
		if (i & 0x01) == 0 {
			for j := 0; j < scaled; j++ {
				pattern = (pattern << 1) | 0x01
			}
		} else {
			pattern <<= uint(scaled)
		}
	}
	return pattern
}

func code93PatternToChar(pattern int) (byte, error) {
	for i := 0; i < len(code93CharacterEncodings); i++ {
		if code93CharacterEncodings[i] == pattern {
			return code93Alphabet[i], nil
		}
	}
	return 0, gozxing.NewNotFoundException("pattern = %d", pattern)
}

func code93DecodeExtended(encoded []byte) (string, error) {
	length := len(encoded)
	decoded := make([]byte, 0, length)
	for i := 0; i < length; i++ {
		c := encoded[i]
		// ($)=a, (%)=b, (/)=c, (+)=d
		if c >= 'a' && c <= 'd' {
			if i >= length-1 {
				return "", gozxing.NewFormatException("i=%d, length=%d", i, length)
			}
			next := encoded[i+1]
			decodedChar := byte(0)
			switch c {
			case 'd':
				// +A to +Z map to a to z
				if next >= 'A' && next <= 'Z' {
					decodedChar = next + 32
				} else {
					return "", gozxing.NewFormatException("encoded = (+)0x02x", next)
				}
				break
			case 'a':
				// $A to $Z map to control codes SH to SB
				if next >= 'A' && next <= 'Z' {
					decodedChar = next - 64
				} else {
					return "", gozxing.NewFormatException("encoded = ($)0x02x", next)
				}
				break
			case 'b':
				if next >= 'A' && next <= 'E' {
					// %A to %E map to control codes ESC to USep
					decodedChar = next - 38
				} else if next >= 'F' && next <= 'J' {
					// %F to %J map to ; < = > ?
					decodedChar = next - 11
				} else if next >= 'K' && next <= 'O' {
					// %K to %O map to [ \ ] ^ _
					decodedChar = next + 16
				} else if next >= 'P' && next <= 'T' {
					// %P to %S map to { | } ~
					decodedChar = next + 43
				} else if next == 'U' {
					decodedChar = 0
				} else if next == 'V' {
					decodedChar = '@'
				} else if next == 'W' {
					decodedChar = '`'
				} else if next >= 'X' && next <= 'Z' {
					// %X to %Z all map to DEL (127)
					decodedChar = 127
				} else {
					return "", gozxing.NewFormatException("encoded = (%)0x02x", next)
				}
				break
			case 'c':
				// /A to /O map to ! to , and /Z maps to :
				if next >= 'A' && next <= 'O' {
					decodedChar = next - 32
				} else if next == 'Z' {
					decodedChar = ':'
				} else {
					return "", gozxing.NewFormatException("encoded = (/)0x02x", next)
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

func code93CheckChecksums(result []byte) error {
	length := len(result)
	e := code93CheckOneChecksum(result, length-2, 20)
	if e == nil {
		e = code93CheckOneChecksum(result, length-1, 15)
	}
	return e
}

func code93CheckOneChecksum(result []byte, checkPosition, weightMax int) error {
	weight := 1
	total := 0
	for i := checkPosition - 1; i >= 0; i-- {
		total += weight * strings.Index(code93AlphabetString, string(result[i]))
		weight++
		if weight > weightMax {
			weight = 1
		}
	}
	if s, t := result[checkPosition], code93Alphabet[total%47]; s != t {
		return gozxing.NewChecksumException("checkPosition=%d, total=%d", s, t)
	}
	return nil
}
