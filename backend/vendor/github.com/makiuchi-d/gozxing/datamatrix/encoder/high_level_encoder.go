package encoder

import (
	"math"
	"strings"

	"github.com/makiuchi-d/gozxing"
)

// DataMatrix ECC 200 data encoder following the algorithm described in ISO/IEC 16022:200(E) in annex S.

const (
	// Padding character
	HighLevelEncoder_PAD = 129

	// mode latch to C40 encodation mode
	HighLevelEncoder_LATCH_TO_C40 = 230

	// mode latch to Base 256 encodation mode
	HighLevelEncoder_LATCH_TO_BASE256 = 231

	// FNC1 Codeword
	// HighLevelEncoder_FUNC1 = 232

	// Structured Append Codeword
	// HighLevelEncoder_STRUCTURED_APPEND = 233

	// Reader Programming
	// HighLevelEncoder_READER_PROGRAMMING = 234

	// Upper Shift
	HighLevelEncoder_UPPER_SHIFT = 235

	// 05 Macro
	HighLevelEncoder_MACRO_05 = 236

	// 06 Macro
	HighLevelEncoder_MACRO_06 = 237

	// mode latch to ANSI X.12 encodation mode
	HighLevelEncoder_LATCH_TO_ANSIX12 = 238

	// mode latch to Text encodation mode
	HighLevelEncoder_LATCH_TO_TEXT = 239

	// mode latch to EDIFACT encodation mode
	HighLevelEncoder_LATCH_TO_EDIFACT = 240

	// ECI character (Extended Channel Interpretation)
	// HighLevelEncoder_ECI = 241

	// Unlatch from C40 encodation
	HighLevelEncoder_C40_UNLATCH = 254

	// Unlatch from X12 encodation
	HighLevelEncoder_X12_UNLATCH = 254

	// 05 Macro header
	HighLevelEncoder_MACRO_05_HEADER = "[)>\u001E05\u001D"

	// 06 Macro header
	HighLevelEncoder_MACRO_06_HEADER = "[)>\u001E06\u001D"

	// Macro trailer
	HighLevelEncoder_MACRO_TRAILER = "\u001E\u0004"

	HighLevelEncoder_ASCII_ENCODATION   = 0
	HighLevelEncoder_C40_ENCODATION     = 1
	HighLevelEncoder_TEXT_ENCODATION    = 2
	HighLevelEncoder_X12_ENCODATION     = 3
	HighLevelEncoder_EDIFACT_ENCODATION = 4
	HighLevelEncoder_BASE256_ENCODATION = 5
)

func randomize253State(codewordPosition int) byte {
	pseudoRandom := ((149 * codewordPosition) % 253) + 1
	tempVariable := HighLevelEncoder_PAD + pseudoRandom
	if tempVariable <= 254 {
		return byte(tempVariable)
	}
	return byte(tempVariable - 254)
}

// EncodeHighLevel Performs message encoding of a DataMatrix message using the
// algorithm described in annex P of ISO/IEC 16022:2000(E).
//
// @param msg     the message
// @param shape   requested shape. May be {@code SymbolShapeHint.FORCE_NONE},
//                {@code SymbolShapeHint.FORCE_SQUARE} or {@code SymbolShapeHint.FORCE_RECTANGLE}.
// @param minSize the minimum symbol size constraint or null for no constraint
// @param maxSize the maximum symbol size constraint or null for no constraint
// @return the encoded message (the char values range from 0 to 255)
//
func EncodeHighLevel(msg string, shape SymbolShapeHint, minSize, maxSize *gozxing.Dimension) ([]byte, error) {
	//the codewords 0..255 are encoded as Unicode characters
	encoders := []Encoder{
		NewASCIIEncoder(), NewC40Encoder(), NewTextEncoder(),
		NewX12Encoder(), NewEdifactEncoder(), NewBase256Encoder(),
	}

	context, e := NewEncoderContext(msg)
	if e != nil {
		return nil, e
	}
	context.SetSymbolShape(shape)
	context.SetSizeConstraints(minSize, maxSize)

	if strings.HasPrefix(msg, HighLevelEncoder_MACRO_05_HEADER) &&
		strings.HasSuffix(msg, HighLevelEncoder_MACRO_TRAILER) {
		context.WriteCodeword(HighLevelEncoder_MACRO_05)
		context.SetSkipAtEnd(2)
		context.pos += len(HighLevelEncoder_MACRO_05_HEADER)
	} else if strings.HasPrefix(msg, HighLevelEncoder_MACRO_06_HEADER) &&
		strings.HasSuffix(msg, HighLevelEncoder_MACRO_TRAILER) {
		context.WriteCodeword(HighLevelEncoder_MACRO_06)
		context.SetSkipAtEnd(2)
		context.pos += len(HighLevelEncoder_MACRO_06_HEADER)
	}

	encodingMode := HighLevelEncoder_ASCII_ENCODATION //Default mode
	for context.HasMoreCharacters() {
		encoders[encodingMode].encode(context)
		if context.GetNewEncoding() >= 0 {
			encodingMode = context.GetNewEncoding()
			context.ResetEncoderSignal()
		}
	}
	length := context.GetCodewordCount()
	e = context.UpdateSymbolInfo()
	if e != nil {
		return nil, gozxing.WrapWriterException(e)
	}

	capacity := context.GetSymbolInfo().GetDataCapacity()
	if length < capacity &&
		encodingMode != HighLevelEncoder_ASCII_ENCODATION &&
		encodingMode != HighLevelEncoder_BASE256_ENCODATION &&
		encodingMode != HighLevelEncoder_EDIFACT_ENCODATION {
		context.WriteCodeword(0xfe) //Unlatch (254)
	}
	//Padding
	codewords := context.GetCodewords()
	if len(codewords) < capacity {
		codewords = append(codewords, HighLevelEncoder_PAD)
	}
	for len(codewords) < capacity {
		codewords = append(codewords, randomize253State(len(codewords)+1))
	}
	context.codewords = codewords

	return context.GetCodewords(), nil
}

func HighLevelEncoder_lookAheadTest(msg []byte, startpos, currentMode int) int {
	if startpos >= len(msg) {
		return currentMode
	}
	var charCounts []float64
	//step J
	if currentMode == HighLevelEncoder_ASCII_ENCODATION {
		charCounts = []float64{0, 1, 1, 1, 1, 1.25}
	} else {
		charCounts = []float64{1, 2, 2, 2, 2, 2.25}
		charCounts[currentMode] = 0
	}

	charsProcessed := 0
	for {
		//step K
		if (startpos + charsProcessed) == len(msg) {
			min := math.MaxInt32
			mins := make([]byte, 6)
			intCharCounts := make([]int, 6)
			min = findMinimums(charCounts, intCharCounts, min, mins)
			minCount := getMinimumCount(mins)

			if intCharCounts[HighLevelEncoder_ASCII_ENCODATION] == min {
				return HighLevelEncoder_ASCII_ENCODATION
			}
			if minCount == 1 && mins[HighLevelEncoder_BASE256_ENCODATION] > 0 {
				return HighLevelEncoder_BASE256_ENCODATION
			}
			if minCount == 1 && mins[HighLevelEncoder_EDIFACT_ENCODATION] > 0 {
				return HighLevelEncoder_EDIFACT_ENCODATION
			}
			if minCount == 1 && mins[HighLevelEncoder_TEXT_ENCODATION] > 0 {
				return HighLevelEncoder_TEXT_ENCODATION
			}
			if minCount == 1 && mins[HighLevelEncoder_X12_ENCODATION] > 0 {
				return HighLevelEncoder_X12_ENCODATION
			}
			return HighLevelEncoder_C40_ENCODATION
		}

		c := msg[startpos+charsProcessed]
		charsProcessed++

		//step L
		if HighLevelEncoder_isDigit(c) {
			charCounts[HighLevelEncoder_ASCII_ENCODATION] += 0.5
		} else if HighLevelEncoder_isExtendedASCII(c) {
			charCounts[HighLevelEncoder_ASCII_ENCODATION] =
				math.Ceil(charCounts[HighLevelEncoder_ASCII_ENCODATION])
			charCounts[HighLevelEncoder_ASCII_ENCODATION] += 2.0
		} else {
			charCounts[HighLevelEncoder_ASCII_ENCODATION] =
				math.Ceil(charCounts[HighLevelEncoder_ASCII_ENCODATION])
			charCounts[HighLevelEncoder_ASCII_ENCODATION]++
		}

		//step M
		if isNativeC40(c) {
			charCounts[HighLevelEncoder_C40_ENCODATION] += 2.0 / 3.0
		} else if HighLevelEncoder_isExtendedASCII(c) {
			charCounts[HighLevelEncoder_C40_ENCODATION] += 8.0 / 3.0
		} else {
			charCounts[HighLevelEncoder_C40_ENCODATION] += 4.0 / 3.0
		}

		//step N
		if isNativeText(c) {
			charCounts[HighLevelEncoder_TEXT_ENCODATION] += 2.0 / 3.0
		} else if HighLevelEncoder_isExtendedASCII(c) {
			charCounts[HighLevelEncoder_TEXT_ENCODATION] += 8.0 / 3.0
		} else {
			charCounts[HighLevelEncoder_TEXT_ENCODATION] += 4.0 / 3.0
		}

		//step O
		if isNativeX12(c) {
			charCounts[HighLevelEncoder_X12_ENCODATION] += 2.0 / 3.0
		} else if HighLevelEncoder_isExtendedASCII(c) {
			charCounts[HighLevelEncoder_X12_ENCODATION] += 13.0 / 3.0
		} else {
			charCounts[HighLevelEncoder_X12_ENCODATION] += 10.0 / 3.0
		}

		//step P
		if isNativeEDIFACT(c) {
			charCounts[HighLevelEncoder_EDIFACT_ENCODATION] += 3.0 / 4.0
		} else if HighLevelEncoder_isExtendedASCII(c) {
			charCounts[HighLevelEncoder_EDIFACT_ENCODATION] += 17.0 / 4.0
		} else {
			charCounts[HighLevelEncoder_EDIFACT_ENCODATION] += 13.0 / 4.0
		}

		// step Q
		if isSpecialB256(c) {
			charCounts[HighLevelEncoder_BASE256_ENCODATION] += 4.0
		} else {
			charCounts[HighLevelEncoder_BASE256_ENCODATION]++
		}

		//step R
		if charsProcessed >= 4 {
			intCharCounts := make([]int, 6)
			mins := make([]byte, 6)
			findMinimums(charCounts, intCharCounts, math.MaxInt32, mins)
			minCount := getMinimumCount(mins)

			if intCharCounts[HighLevelEncoder_ASCII_ENCODATION] < intCharCounts[HighLevelEncoder_BASE256_ENCODATION] &&
				intCharCounts[HighLevelEncoder_ASCII_ENCODATION] < intCharCounts[HighLevelEncoder_C40_ENCODATION] &&
				intCharCounts[HighLevelEncoder_ASCII_ENCODATION] < intCharCounts[HighLevelEncoder_TEXT_ENCODATION] &&
				intCharCounts[HighLevelEncoder_ASCII_ENCODATION] < intCharCounts[HighLevelEncoder_X12_ENCODATION] &&
				intCharCounts[HighLevelEncoder_ASCII_ENCODATION] < intCharCounts[HighLevelEncoder_EDIFACT_ENCODATION] {
				return HighLevelEncoder_ASCII_ENCODATION
			}
			if intCharCounts[HighLevelEncoder_BASE256_ENCODATION] < intCharCounts[HighLevelEncoder_ASCII_ENCODATION] ||
				(mins[HighLevelEncoder_C40_ENCODATION]+mins[HighLevelEncoder_TEXT_ENCODATION]+mins[HighLevelEncoder_X12_ENCODATION]+mins[HighLevelEncoder_EDIFACT_ENCODATION]) == 0 {
				return HighLevelEncoder_BASE256_ENCODATION
			}
			if minCount == 1 && mins[HighLevelEncoder_EDIFACT_ENCODATION] > 0 {
				return HighLevelEncoder_EDIFACT_ENCODATION
			}
			if minCount == 1 && mins[HighLevelEncoder_TEXT_ENCODATION] > 0 {
				return HighLevelEncoder_TEXT_ENCODATION
			}
			if minCount == 1 && mins[HighLevelEncoder_X12_ENCODATION] > 0 {
				return HighLevelEncoder_X12_ENCODATION
			}
			if intCharCounts[HighLevelEncoder_C40_ENCODATION]+1 < intCharCounts[HighLevelEncoder_ASCII_ENCODATION] &&
				intCharCounts[HighLevelEncoder_C40_ENCODATION]+1 < intCharCounts[HighLevelEncoder_BASE256_ENCODATION] &&
				intCharCounts[HighLevelEncoder_C40_ENCODATION]+1 < intCharCounts[HighLevelEncoder_EDIFACT_ENCODATION] &&
				intCharCounts[HighLevelEncoder_C40_ENCODATION]+1 < intCharCounts[HighLevelEncoder_TEXT_ENCODATION] {
				if intCharCounts[HighLevelEncoder_C40_ENCODATION] < intCharCounts[HighLevelEncoder_X12_ENCODATION] {
					return HighLevelEncoder_C40_ENCODATION
				}
				if intCharCounts[HighLevelEncoder_C40_ENCODATION] == intCharCounts[HighLevelEncoder_X12_ENCODATION] {
					p := startpos + charsProcessed + 1
					for p < len(msg) {
						tc := msg[p]
						if isX12TermSep(tc) {
							return HighLevelEncoder_X12_ENCODATION
						}
						if !isNativeX12(tc) {
							break
						}
						p++
					}
					return HighLevelEncoder_C40_ENCODATION
				}
			}
		}
	}
}

func findMinimums(charCounts []float64, intCharCounts []int, min int, mins []byte) int {
	for i := range mins {
		mins[i] = 0
	}
	for i := 0; i < 6; i++ {
		intCharCounts[i] = int(math.Ceil(charCounts[i]))
		current := intCharCounts[i]
		if min > current {
			min = current
			for j := range mins {
				mins[j] = 0
			}
		}
		if min == current {
			mins[i]++
		}
	}
	return min
}

func getMinimumCount(mins []byte) int {
	minCount := 0
	for i := 0; i < 6; i++ {
		minCount += int(mins[i])
	}
	return minCount
}

func HighLevelEncoder_isDigit(ch byte) bool {
	return ch >= '0' && ch <= '9'
}

func HighLevelEncoder_isExtendedASCII(ch byte) bool {
	return ch >= 128 && ch <= 255
}

func isNativeC40(ch byte) bool {
	return (ch == ' ') || (ch >= '0' && ch <= '9') || (ch >= 'A' && ch <= 'Z')
}

func isNativeText(ch byte) bool {
	return (ch == ' ') || (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'z')
}

func isNativeX12(ch byte) bool {
	return isX12TermSep(ch) || (ch == ' ') || (ch >= '0' && ch <= '9') || (ch >= 'A' && ch <= 'Z')
}

func isX12TermSep(ch byte) bool {
	return (ch == '\r') || //CR
		(ch == '*') ||
		(ch == '>')
}

func isNativeEDIFACT(ch byte) bool {
	return ch >= ' ' && ch <= '^'
}

func isSpecialB256(ch byte) bool {
	return false //TODO NOT IMPLEMENTED YET!!!
}

// determineConsecutiveDigitCount Determines the number of consecutive characters that are encodable using numeric compaction.
//
// @param msg      the message
// @param startpos the start position within the message
// @return the requested character count
//
func HighLevelEncoder_determineConsecutiveDigitCount(msg []byte, startpos int) int {
	count := 0
	len := len(msg)
	idx := startpos
	if idx < len {
		ch := msg[idx]
		for HighLevelEncoder_isDigit(ch) && idx < len {
			count++
			idx++
			if idx < len {
				ch = msg[idx]
			}
		}
	}
	return count
}
