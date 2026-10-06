package decoder

import (
	"golang.org/x/text/encoding"
	"golang.org/x/text/transform"

	"github.com/makiuchi-d/gozxing"
	"github.com/makiuchi-d/gozxing/common"
)

const GB2312_SUBSET = 1

var ALPHANUMERIC_CHARS = []byte("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:")

func DecodedBitStreamParser_Decode(
	bytes []byte, version *Version, ecLevel ErrorCorrectionLevel,
	hints map[gozxing.DecodeHintType]interface{}) (*common.DecoderResult, error) {

	bits := common.NewBitSource(bytes)
	result := make([]byte, 0, 50)
	byteSegments := make([][]byte, 0, 1)
	symbolSequence := -1
	parityData := -1
	symbologyModifier := 0

	var currentCharacterSetECI *common.CharacterSetECI
	fc1InEffect := false
	hasFNC1first := false
	hasFNC1second := false
	var mode *Mode
	var e error

	for {
		// While still another segment to read...
		if bits.Available() < 4 {
			// OK, assume we're done. Really, a TERMINATOR mode should have been recorded here
			mode = Mode_TERMINATOR
		} else {
			bit4, _ := bits.ReadBits(4) // mode is encoded by 4 bits
			mode, e = ModeForBits(bit4)
			if e != nil {
				return nil, gozxing.WrapFormatException(e)
			}
		}
		switch mode {
		case Mode_TERMINATOR:
		case Mode_FNC1_FIRST_POSITION:
			hasFNC1first = true // symbology detection
			// We do little with FNC1 except alter the parsed result a bit according to the spec
			fc1InEffect = true
		case Mode_FNC1_SECOND_POSITION:
			hasFNC1second = true // symbology detection
			// We do little with FNC1 except alter the parsed result a bit according to the spec
			fc1InEffect = true
		case Mode_STRUCTURED_APPEND:
			// sequence number and parity is added later to the result metadata
			// Read next 8 bits (symbol sequence #) and 8 bits (parity data), then continue
			symbolSequence, e = bits.ReadBits(8)
			if e != nil {
				return nil, gozxing.WrapFormatException(e)
			}
			parityData, e = bits.ReadBits(8)
			if e != nil {
				return nil, gozxing.WrapFormatException(e)
			}
		case Mode_ECI:
			// Count doesn't apply to ECI
			value, e := DecodedBitStreamParser_parseECIValue(bits)
			if e != nil {
				return nil, e
			}
			currentCharacterSetECI, e = common.GetCharacterSetECIByValue(value)
			if e != nil || currentCharacterSetECI == nil {
				return nil, gozxing.WrapFormatException(e)
			}
		case Mode_HANZI:
			// First handle Hanzi mode which does not start with character count
			// Chinese mode contains a sub set indicator right after mode indicator
			subset, e := bits.ReadBits(4)
			if e != nil {
				return nil, gozxing.WrapFormatException(e)
			}
			countHanzi, e := bits.ReadBits(mode.GetCharacterCountBits(version))
			if e != nil {
				return nil, gozxing.WrapFormatException(e)
			}
			if subset == GB2312_SUBSET {
				result, e = DecodedBitStreamParser_decodeHanziSegment(bits, result, countHanzi)
				if e != nil {
					return nil, e
				}
			}
		default:
			// "Normal" QR code modes:
			// How many characters will follow, encoded in this mode?
			count, e := bits.ReadBits(mode.GetCharacterCountBits(version))
			if e != nil {
				return nil, gozxing.WrapFormatException(e)
			}
			switch mode {
			case Mode_NUMERIC:
				result, e = DecodedBitStreamParser_decodeNumericSegment(bits, result, count)
				if e != nil {
					return nil, e
				}
			case Mode_ALPHANUMERIC:
				result, e = DecodedBitStreamParser_decodeAlphanumericSegment(bits, result, count, fc1InEffect)
				if e != nil {
					return nil, e
				}
			case Mode_BYTE:
				result, byteSegments, e = DecodedBitStreamParser_decodeByteSegment(bits, result, count, currentCharacterSetECI, byteSegments, hints)
				if e != nil {
					return nil, e
				}
			case Mode_KANJI:
				result, e = DecodedBitStreamParser_decodeKanjiSegment(bits, result, count)
				if e != nil {
					return nil, e
				}
			default:
				return nil, gozxing.NewFormatException("Unknown mode")
			}
			break
		}

		if mode == Mode_TERMINATOR {
			break
		}
	}

	if currentCharacterSetECI != nil {
		if hasFNC1first {
			symbologyModifier = 4
		} else if hasFNC1second {
			symbologyModifier = 6
		} else {
			symbologyModifier = 2
		}
	} else {
		if hasFNC1first {
			symbologyModifier = 3
		} else if hasFNC1second {
			symbologyModifier = 5
		} else {
			symbologyModifier = 1
		}
	}

	if len(byteSegments) == 0 {
		byteSegments = nil
	}
	return common.NewDecoderResultWithParams(bytes,
		string(result),
		byteSegments,
		ecLevel.String(),
		symbolSequence,
		parityData,
		symbologyModifier), nil
}

func DecodedBitStreamParser_decodeHanziSegment(bits *common.BitSource, result []byte, count int) ([]byte, error) {
	// Don't crash trying to read more bits than we have available.
	if count*13 > bits.Available() {
		return result, gozxing.NewFormatException("bits.Available() = %v", bits.Available())
	}

	// Each character will require 2 bytes. Read the characters as 2-byte pairs
	// and decode as GB2312 afterwards
	buffer := make([]byte, 2*count)
	offset := 0
	for count > 0 {
		// Each 13 bits encodes a 2-byte character
		twoBytes, _ := bits.ReadBits(13)
		assembledTwoBytes := ((twoBytes / 0x060) << 8) | (twoBytes % 0x060)
		if assembledTwoBytes < 0x00a00 {
			// In the 0xA1A1 to 0xAAFE range
			assembledTwoBytes += 0x0A1A1
		} else {
			// In the 0xB0A1 to 0xFAFE range
			assembledTwoBytes += 0x0A6A1
		}
		buffer[offset] = (byte)((assembledTwoBytes >> 8) & 0xFF)
		buffer[offset+1] = (byte)(assembledTwoBytes & 0xFF)
		offset += 2
		count--
	}

	dec := common.StringUtils_GB2312_CHARSET.NewDecoder()
	result, _, e := transform.Append(dec, result, buffer[:offset])
	if e != nil {
		return result, gozxing.WrapFormatException(e)
	}
	return result, nil
}

func DecodedBitStreamParser_decodeKanjiSegment(bits *common.BitSource, result []byte, count int) ([]byte, error) {
	// Don't crash trying to read more bits than we have available.
	if count*13 > bits.Available() {
		return result, gozxing.NewFormatException("bits.Available() = %v", bits.Available())
	}

	// Each character will require 2 bytes. Read the characters as 2-byte pairs
	// and decode as Shift_JIS afterwards
	buffer := make([]byte, 2*count)
	offset := 0
	for count > 0 {
		// Each 13 bits encodes a 2-byte character
		twoBytes, _ := bits.ReadBits(13)
		assembledTwoBytes := ((twoBytes / 0x0C0) << 8) | (twoBytes % 0x0C0)
		if assembledTwoBytes < 0x01F00 {
			// In the 0x8140 to 0x9FFC range
			assembledTwoBytes += 0x08140
		} else {
			// In the 0xE040 to 0xEBBF range
			assembledTwoBytes += 0x0C140
		}
		buffer[offset] = byte(assembledTwoBytes >> 8)
		buffer[offset+1] = byte(assembledTwoBytes)
		offset += 2
		count--
	}

	// Shift_JIS may not be supported in some environments:
	dec := common.StringUtils_SHIFT_JIS_CHARSET.NewDecoder()
	result, _, e := transform.Append(dec, result, buffer[:offset])
	if e != nil {
		return result, gozxing.WrapFormatException(e)
	}
	return result, nil
}

func DecodedBitStreamParser_decodeByteSegment(bits *common.BitSource,
	result []byte, count int, currentCharacterSetECI *common.CharacterSetECI,
	byteSegments [][]byte, hints map[gozxing.DecodeHintType]interface{}) ([]byte, [][]byte, error) {

	// Don't crash trying to read more bits than we have available.
	if 8*count > bits.Available() {
		return result, byteSegments, gozxing.NewFormatException("bits.Available = %v", bits.Available())
	}

	readBytes := make([]byte, count)
	for i := 0; i < count; i++ {
		b, _ := bits.ReadBits(8)
		readBytes[i] = byte(b)
	}

	var encoding encoding.Encoding
	if currentCharacterSetECI == nil {
		// The spec isn't clear on this mode; see
		// section 6.4.5: t does not say which encoding to assuming
		// upon decoding. I have seen ISO-8859-1 used as well as
		// Shift_JIS -- without anything like an ECI designator to
		// give a hint.
		var err error
		encoding, err = common.StringUtils_guessCharset(readBytes, hints)
		if err != nil {
			return nil, nil, gozxing.WrapFormatException(err)
		}
	} else {
		encoding = currentCharacterSetECI.GetCharset()
	}

	dec := encoding.NewDecoder()
	result, _, e := transform.Append(dec, result, readBytes)
	if e != nil {
		return result, byteSegments, gozxing.WrapFormatException(e)
	}

	byteSegments = append(byteSegments, readBytes)
	return result, byteSegments, nil
}

func toAlphaNumericChar(value int) (byte, error) {
	if value >= len(ALPHANUMERIC_CHARS) {
		return 0, gozxing.NewFormatException("%v >= len(ALPHANUMERIC_CHARS)", value)
	}
	return ALPHANUMERIC_CHARS[value], nil
}

func DecodedBitStreamParser_decodeAlphanumericSegment(bits *common.BitSource, result []byte, count int, fc1InEffect bool) ([]byte, error) {
	// Read two characters at a time
	start := len(result)
	for count > 1 {
		nextTwoCharsBits, e := bits.ReadBits(11)
		if e != nil {
			return result, gozxing.WrapFormatException(e)
		}
		char, e := toAlphaNumericChar(nextTwoCharsBits / 45)
		if e != nil {
			return result, gozxing.WrapFormatException(e)
		}
		result = append(result, char)
		char, _ = toAlphaNumericChar(nextTwoCharsBits % 45)
		result = append(result, char)
		count -= 2
	}
	if count == 1 {
		// special case: one character left
		nextCharBits, e := bits.ReadBits(6)
		if e != nil {
			return result, gozxing.WrapFormatException(e)
		}
		char, e := toAlphaNumericChar(nextCharBits)
		if e != nil {
			return result, gozxing.WrapFormatException(e)
		}
		result = append(result, char)
	}
	// See section 6.4.8.1, 6.4.8.2
	if fc1InEffect {
		// We need to massage the result a bit if in an FNC1 mode:
		for i := start; i < len(result); i++ {
			if result[i] == '%' {
				if i < len(result)-1 && result[i+1] == '%' {
					// %% is rendered as %
					result = append(result[:i], result[i+1:]...)
				} else {
					// In alpha mode, % should be converted to FNC1 separator 0x1D
					result[i] = byte(0x1D)
				}
			}
		}
	}
	return result, nil
}

func DecodedBitStreamParser_decodeNumericSegment(bits *common.BitSource, result []byte, count int) ([]byte, error) {
	// Read three digits at a time
	for count >= 3 {
		// Each 10 bits encodes three digits
		threeDigitsBits, e := bits.ReadBits(10)
		if e != nil {
			return result, gozxing.WrapFormatException(e)
		}
		if threeDigitsBits >= 1000 {
			return result, gozxing.NewFormatException("threeDigitalBits = %v", threeDigitsBits)
		}
		result = append(result, byte('0'+(threeDigitsBits/100)))
		result = append(result, byte('0'+((threeDigitsBits/10)%10)))
		result = append(result, byte('0'+(threeDigitsBits%10)))
		count -= 3
	}
	if count == 2 {
		// Two digits left over to read, encoded in 7 bits
		twoDigitsBits, e := bits.ReadBits(7)
		if e != nil {
			return result, gozxing.WrapFormatException(e)
		}
		if twoDigitsBits >= 100 {
			return result, gozxing.NewFormatException("twoDigitsBits = %v", twoDigitsBits)
		}
		result = append(result, byte('0'+(twoDigitsBits/10)))
		result = append(result, byte('0'+(twoDigitsBits%10)))
	} else if count == 1 {
		// One digit left over to read
		digitBits, e := bits.ReadBits(4)
		if e != nil {
			return result, gozxing.WrapFormatException(e)
		}
		if digitBits >= 10 {
			return result, gozxing.NewFormatException("digitBits = %v", digitBits)
		}
		result = append(result, byte('0'+digitBits))
	}
	return result, nil
}

func DecodedBitStreamParser_parseECIValue(bits *common.BitSource) (int, error) {
	firstByte, e := bits.ReadBits(8)
	if e != nil {
		return -1, gozxing.WrapFormatException(e)
	}
	if (firstByte & 0x80) == 0 {
		// just one byte
		return firstByte & 0x7F, nil
	}
	if (firstByte & 0xC0) == 0x80 {
		// two bytes
		secondByte, e := bits.ReadBits(8)
		if e != nil {
			return -1, gozxing.WrapFormatException(e)
		}
		return ((firstByte & 0x3F) << 8) | secondByte, nil
	}
	if (firstByte & 0xE0) == 0xC0 {
		// three bytes
		secondThirdBytes, e := bits.ReadBits(16)
		if e != nil {
			return -1, gozxing.WrapFormatException(e)
		}
		return ((firstByte & 0x1F) << 16) | secondThirdBytes, nil
	}
	return -1, gozxing.NewFormatException()
}
