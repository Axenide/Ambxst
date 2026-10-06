package decoder

import (
	"strconv"

	"golang.org/x/text/encoding/charmap"

	"github.com/makiuchi-d/gozxing"
	"github.com/makiuchi-d/gozxing/common"
)

// Data Matrix Codes can encode text as bits in one of several modes, and can use multiple modes
// in one Data Matrix Code. This class decodes the bits back into text.
//
// See ISO 16022:2006, 5.2.1 - 5.2.9.2

type Mode int

const (
	Mode_PDA_ENCODE Mode = iota
	Mode_ASCII_ENCODE
	Mode_C40_ENCODE
	Mode_TEXT_ENCODE
	Mode_ANSIX12_ENCODE
	Mode_EDIFACT_ENCODE
	Mode_BASE256_ENCODE
	Mode_ECI_ENCODE
)

var (
	// See ISO 16022:2006, Annex C Table C.1
	// The C40 Basic Character Set (*'s used for placeholders for the shift values)

	C40_BASIC_SET_CHARS = []byte{
		'*', '*', '*', ' ', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
		'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N',
		'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
	}

	C40_SHIFT2_SET_CHARS = []byte{
		'!', '"', '#', '$', '%', '&', '\'', '(', ')', '*', '+', ',', '-', '.',
		'/', ':', ';', '<', '=', '>', '?', '@', '[', '\\', ']', '^', '_',
	}

	// See ISO 16022:2006, Annex C Table C.2
	// The Text Basic Character Set (*'s used for placeholders for the shift values)

	TEXT_BASIC_SET_CHARS = []byte{
		'*', '*', '*', ' ', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
		'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n',
		'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
	}

	// Shift 2 for Text is the same encoding as C40

	TEXT_SHIFT2_SET_CHARS = C40_SHIFT2_SET_CHARS

	TEXT_SHIFT3_SET_CHARS = []byte{
		'`', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N',
		'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '{', '|', '}', '~', 127,
	}
)

type intSet map[int]struct{}

func (s intSet) add(n int) {
	s[n] = struct{}{}
}

func (s intSet) contains(n int) bool {
	_, ok := s[n]
	return ok
}

func DecodedBitStreamParser_decode(bytes []byte) (*common.DecoderResult, error) {
	bits := common.NewBitSource(bytes)
	result := make([]byte, 0, 100)
	resultTrailer := make([]byte, 0)
	byteSegments := make([][]byte, 0, 1)
	mode := Mode_ASCII_ENCODE
	fnc1Positions := intSet{} // Would be replaceable by looking directly at 'bytes', if we're sure to not having to account for multi byte values.
	symbologyModifier := 0
	isECIencoded := false

	for mode != Mode_PDA_ENCODE && bits.Available() > 0 {
		var e error
		if mode == Mode_ASCII_ENCODE {
			mode, result, resultTrailer, e = decodeAsciiSegment(bits, result, resultTrailer, fnc1Positions)
		} else {
			switch mode {
			case Mode_C40_ENCODE:
				result, e = decodeC40Segment(bits, result, fnc1Positions)
			case Mode_TEXT_ENCODE:
				result, e = decodeTextSegment(bits, result, fnc1Positions)
			case Mode_ANSIX12_ENCODE:
				result, e = decodeAnsiX12Segment(bits, result)
			case Mode_EDIFACT_ENCODE:
				result = decodeEdifactSegment(bits, result)
			case Mode_BASE256_ENCODE:
				result, byteSegments, e = decodeBase256Segment(bits, result, byteSegments)
			case Mode_ECI_ENCODE:
				isECIencoded = true // ECI detection only, atm continue decoding as ASCII
			default:
				return nil, gozxing.NewFormatException("mode = %v", mode)
			}
			mode = Mode_ASCII_ENCODE
		}
		if e != nil {
			return nil, e
		}
	}
	if len(resultTrailer) > 0 {
		result = append(result, resultTrailer...)
	}

	if len(byteSegments) == 0 {
		byteSegments = nil
	}
	if isECIencoded {
		// Examples for this numbers can be found in this documentation of a hardware barcode scanner:
		// https://honeywellaidc.force.com/supportppr/s/article/List-of-barcode-symbology-AIM-Identifiers
		if fnc1Positions.contains(0) || fnc1Positions.contains(4) {
			symbologyModifier = 5
		} else if fnc1Positions.contains(1) || fnc1Positions.contains(5) {
			symbologyModifier = 6
		} else {
			symbologyModifier = 4
		}
	} else {
		if fnc1Positions.contains(0) || fnc1Positions.contains(4) {
			symbologyModifier = 2
		} else if fnc1Positions.contains(1) || fnc1Positions.contains(5) {
			symbologyModifier = 3
		} else {
			symbologyModifier = 1
		}
	}

	return common.NewDecoderResultWithSymbologyModifier(bytes, string(result), byteSegments, "", symbologyModifier), nil
}

// decodeAsciiSegment See ISO 16022:2006, 5.2.3 and Annex C, Table C.2
func decodeAsciiSegment(bits *common.BitSource, result, resultTrailer []byte, fnc1positions intSet) (Mode, []byte, []byte, error) {
	upperShift := false
	for bits.Available() > 0 {
		oneByte, _ := bits.ReadBits(8)
		if oneByte == 0 {
			return Mode_ASCII_ENCODE, result, resultTrailer, gozxing.NewFormatException("oneByte == 0")
		} else if oneByte <= 128 { // ASCII data (ASCII value + 1)
			if upperShift {
				oneByte += 128
				//upperShift = false;
			}
			result = append(result, byte(oneByte-1))
			return Mode_ASCII_ENCODE, result, resultTrailer, nil
		} else if oneByte == 129 { // Pad
			return Mode_PDA_ENCODE, result, resultTrailer, nil
		} else if oneByte <= 229 { // 2-digit data 00-99 (Numeric Value + 130)
			value := oneByte - 130
			if value < 10 { // pad with '0' for single digit values
				result = append(result, '0')
			}
			result = append(result, []byte(strconv.Itoa(value))...)
		} else {
			switch oneByte {
			case 230: // Latch to C40 encodation
				return Mode_C40_ENCODE, result, resultTrailer, nil
			case 231: // Latch to Base 256 encodation
				return Mode_BASE256_ENCODE, result, resultTrailer, nil
			case 232: // FNC1
				fnc1positions.add(len(result))
				result = append(result, 29) // translate as ASCII 29
				break
			case 233, 234: // Structured Append, Reader Programming
				// Ignore these symbols for now
				//throw ReaderException.getInstance();
				break
			case 235: // Upper Shift (shift to Extended ASCII)
				upperShift = true
				break
			case 236: // 05 Macro
				result = append(result, []byte("[)>\u001E05\u001D")...)
				resultTrailer = append([]byte("\u001E\u0004"), resultTrailer...)
				break
			case 237: // 06 Macro
				result = append(result, []byte("[)>\u001E06\u001D")...)
				resultTrailer = append([]byte("\u001E\u0004"), resultTrailer...)
				break
			case 238: // Latch to ANSI X12 encodation
				return Mode_ANSIX12_ENCODE, result, resultTrailer, nil
			case 239: // Latch to Text encodation
				return Mode_TEXT_ENCODE, result, resultTrailer, nil
			case 240: // Latch to EDIFACT encodation
				return Mode_EDIFACT_ENCODE, result, resultTrailer, nil
			case 241: // ECI Character
				return Mode_ECI_ENCODE, result, resultTrailer, nil
			default:
				// Not to be used in ASCII encodation
				// but work around encoders that end with 254, latch back to ASCII
				if oneByte != 254 || bits.Available() != 0 {
					return Mode_ASCII_ENCODE, result, resultTrailer, gozxing.NewFormatException(
						"oneByte=%v, bits.Available()=%v", oneByte, bits.Available())
				}
				break
			}
		}
	}
	return Mode_ASCII_ENCODE, result, resultTrailer, nil
}

// decodeC40Segment See ISO 16022:2006, 5.2.5 and Annex C, Table C.1
func decodeC40Segment(bits *common.BitSource, result []byte, fnc1positions intSet) ([]byte, error) {
	// Three C40 values are encoded in a 16-bit value as
	// (1600 * C1) + (40 * C2) + C3 + 1
	// TODO(bbrown): The Upper Shift with C40 doesn't work in the 4 value scenario all the time
	upperShift := false

	cValues := make([]int, 3)
	shift := 0

	for bits.Available() > 0 {
		// If there is only one byte left then it will be encoded as ASCII
		if bits.Available() == 8 {
			return result, nil
		}
		firstByte, _ := bits.ReadBits(8)
		if firstByte == 254 { // Unlatch codeword
			return result, nil
		}

		secondByte, _ := bits.ReadBits(8)
		parseTwoBytes(firstByte, secondByte, cValues)

		for i := 0; i < 3; i++ {
			cValue := cValues[i]
			switch shift {
			case 0:
				if cValue < 3 {
					shift = cValue + 1
				} else if cValue < len(C40_BASIC_SET_CHARS) {
					c40char := C40_BASIC_SET_CHARS[cValue]
					if upperShift {
						result = append(result, c40char+128)
						upperShift = false
					} else {
						result = append(result, c40char)
					}
				} else {
					return result, gozxing.NewFormatException("cValue = %v", cValue)
				}
				break
			case 1:
				if upperShift {
					result = append(result, byte(cValue+128))
					upperShift = false
				} else {
					result = append(result, byte(cValue))
				}
				shift = 0
				break
			case 2:
				if cValue < len(C40_SHIFT2_SET_CHARS) {
					c40char := C40_SHIFT2_SET_CHARS[cValue]
					if upperShift {
						result = append(result, c40char+128)
						upperShift = false
					} else {
						result = append(result, c40char)
					}
				} else {
					switch cValue {
					case 27: // FNC1
						fnc1positions.add(len(result))
						result = append(result, 29) // translate as ASCII 29
						break
					case 30: // Upper Shift
						upperShift = true
						break
					default:
						return result, gozxing.NewFormatException("cValue = %v", cValue)
					}
				}
				shift = 0
				break
			case 3:
				if upperShift {
					result = append(result, byte(cValue+224))
					upperShift = false
				} else {
					result = append(result, byte(cValue+96))
				}
				shift = 0
				break
			default:
				return result, gozxing.NewFormatException("cValue = %v", cValue)
			}
		}
	}
	return result, nil
}

// decodeTextSegment See ISO 16022:2006, 5.2.6 and Annex C, Table C.2
func decodeTextSegment(bits *common.BitSource, result []byte, fnc1positions intSet) ([]byte, error) {
	// Three Text values are encoded in a 16-bit value as
	// (1600 * C1) + (40 * C2) + C3 + 1
	// TODO(bbrown): The Upper Shift with Text doesn't work in the 4 value scenario all the time
	upperShift := false

	cValues := make([]int, 3)
	shift := 0
	for bits.Available() > 0 {
		// If there is only one byte left then it will be encoded as ASCII
		if bits.Available() == 8 {
			return result, nil
		}
		firstByte, _ := bits.ReadBits(8)
		if firstByte == 254 { // Unlatch codeword
			return result, nil
		}

		secondByte, _ := bits.ReadBits(8)
		parseTwoBytes(firstByte, secondByte, cValues)

		for i := 0; i < 3; i++ {
			cValue := cValues[i]
			switch shift {
			case 0:
				if cValue < 3 {
					shift = cValue + 1
				} else if cValue < len(TEXT_BASIC_SET_CHARS) {
					textChar := TEXT_BASIC_SET_CHARS[cValue]
					if upperShift {
						result = append(result, textChar+128)
						upperShift = false
					} else {
						result = append(result, textChar)
					}
				} else {
					return result, gozxing.NewFormatException("cValue = %v", cValue)
				}
				break
			case 1:
				if upperShift {
					result = append(result, byte(cValue+128))
					upperShift = false
				} else {
					result = append(result, byte(cValue))
				}
				shift = 0
				break
			case 2:
				// Shift 2 for Text is the same encoding as C40
				if cValue < len(TEXT_SHIFT2_SET_CHARS) {
					textChar := TEXT_SHIFT2_SET_CHARS[cValue]
					if upperShift {
						result = append(result, textChar+128)
						upperShift = false
					} else {
						result = append(result, textChar)
					}
				} else {
					switch cValue {
					case 27: // FNC1
						fnc1positions.add(len(result))
						result = append(result, 29) // translate as ASCII 29
						break
					case 30: // Upper Shift
						upperShift = true
						break
					default:
						return result, gozxing.NewFormatException("cValue = %v", cValue)
					}
				}
				shift = 0
				break
			case 3:
				if cValue < len(TEXT_SHIFT3_SET_CHARS) {
					textChar := TEXT_SHIFT3_SET_CHARS[cValue]
					if upperShift {
						result = append(result, textChar+128)
						upperShift = false
					} else {
						result = append(result, textChar)
					}
					shift = 0
				} else {
					return result, gozxing.NewFormatException("cValue = %v", cValue)
				}
				break
			default:
				return result, gozxing.NewFormatException("shift = %v", shift)
			}
		}
	}
	return result, nil
}

// decodeAnsiX12Segment See ISO 16022:2006, 5.2.7
func decodeAnsiX12Segment(bits *common.BitSource, result []byte) ([]byte, error) {
	// Three ANSI X12 values are encoded in a 16-bit value as
	// (1600 * C1) + (40 * C2) + C3 + 1

	cValues := make([]int, 3)
	for bits.Available() > 0 {
		// If there is only one byte left then it will be encoded as ASCII
		if bits.Available() == 8 {
			return result, nil
		}
		firstByte, _ := bits.ReadBits(8)
		if firstByte == 254 { // Unlatch codeword
			return result, nil
		}

		secondByte, _ := bits.ReadBits(8)
		parseTwoBytes(firstByte, secondByte, cValues)

		for i := 0; i < 3; i++ {
			cValue := cValues[i]
			switch cValue {
			case 0: // X12 segment terminator <CR>
				result = append(result, '\r')
				break
			case 1: // X12 segment separator *
				result = append(result, '*')
				break
			case 2: // X12 sub-element separator >
				result = append(result, '>')
				break
			case 3: // space
				result = append(result, ' ')
				break
			default:
				if cValue < 14 { // 0 - 9
					result = append(result, byte(cValue+44))
				} else if cValue < 40 { // A - Z
					result = append(result, byte(cValue+51))
				} else {
					return result, gozxing.NewFormatException("cValue = %v", cValue)
				}
				break
			}
		}
	}
	return result, nil
}

func parseTwoBytes(firstByte, secondByte int, result []int) {
	fullBitValue := (firstByte << 8) + secondByte - 1
	temp := fullBitValue / 1600
	result[0] = temp
	fullBitValue -= temp * 1600
	temp = fullBitValue / 40
	result[1] = temp
	result[2] = fullBitValue - temp*40
}

// decodeEdifactSegment See ISO 16022:2006, 5.2.8 and Annex C Table C.3
func decodeEdifactSegment(bits *common.BitSource, result []byte) []byte {
	for bits.Available() > 0 {
		// If there is only two or less bytes left then it will be encoded as ASCII
		if bits.Available() <= 16 {
			return result
		}

		for i := 0; i < 4; i++ {
			edifactValue, _ := bits.ReadBits(6)

			// Check for the unlatch character
			if edifactValue == 0x1F { // 011111
				// Read rest of byte, which should be 0, and stop
				bitsLeft := 8 - bits.GetBitOffset()
				if bitsLeft != 8 {
					bits.ReadBits(bitsLeft)
				}
				return result
			}

			if (edifactValue & 0x20) == 0 { // no 1 in the leading (6th) bit
				edifactValue |= 0x40 // Add a leading 01 to the 6 bit binary value
			}
			result = append(result, byte(edifactValue))
		}
	}
	return result
}

// decodeBase256Segment See ISO 16022:2006, 5.2.9 and Annex B, B.2
func decodeBase256Segment(bits *common.BitSource, result []byte, byteSegments [][]byte) ([]byte, [][]byte, error) {
	// Figure out how long the Base 256 Segment is.
	codewordPosition := 1 + bits.GetByteOffset() // position is 1-indexed
	b, _ := bits.ReadBits(8)
	d1 := unrandomize255State(b, codewordPosition)
	codewordPosition++
	var count int
	if d1 == 0 { // Read the remainder of the symbol
		count = bits.Available() / 8
	} else if d1 < 250 {
		count = d1
	} else {
		b, _ := bits.ReadBits(8)
		count = 250*(d1-249) + unrandomize255State(b, codewordPosition)
		codewordPosition++
	}

	// We're seeing NegativeArraySizeException errors from users.
	if count < 0 {
		return result, byteSegments, gozxing.NewFormatException("count = %v", count)
	}
	bytes := make([]byte, count)
	for i := 0; i < count; i++ {
		// Have seen this particular error in the wild, such as at
		// http://www.bcgen.com/demo/IDAutomationStreamingDataMatrix.aspx?MODE=3&D=Fred&PFMT=3&PT=F&X=0.3&O=0&LM=0.2
		if bits.Available() < 8 {
			return result, byteSegments, gozxing.NewFormatException("bits.Available = %v", bits.Available())
		}
		b, _ := bits.ReadBits(8)
		bytes[i] = byte(unrandomize255State(b, codewordPosition))
		codewordPosition++
	}
	byteSegments = append(byteSegments, bytes)

	str, e := charmap.ISO8859_1.NewDecoder().Bytes(bytes)
	if e != nil {
		return result, byteSegments, e
	}
	result = append(result, str...)

	return result, byteSegments, nil
}

// unrandomize255State See ISO 16022:2006, Annex B, B.2
func unrandomize255State(randomizedBase256Codeword, base256CodewordPosition int) int {
	pseudoRandomNumber := ((149 * base256CodewordPosition) % 255) + 1
	tempVariable := randomizedBase256Codeword - pseudoRandomNumber
	if tempVariable >= 0 {
		return tempVariable
	}
	return tempVariable + 256
}

func (m Mode) String() string {
	switch m {
	case Mode_PDA_ENCODE:
		return "PAD_ENCODE"
	case Mode_ASCII_ENCODE:
		return "ASCII_ENCODE"
	case Mode_C40_ENCODE:
		return "C40_ENCODE"
	case Mode_TEXT_ENCODE:
		return "TEXT_ENCODE"
	case Mode_ANSIX12_ENCODE:
		return "ANSIX12_ENCODE"
	case Mode_EDIFACT_ENCODE:
		return "EDIFACT_ENCODE"
	case Mode_BASE256_ENCODE:
		return "BASE256_ENCODE"
	case Mode_ECI_ENCODE:
		return "ECI_ENCODE"
	}
	return ""
}
