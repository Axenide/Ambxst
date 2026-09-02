package oned

import (
	"strings"

	"github.com/makiuchi-d/gozxing"
)

// This class renders CodaBar as {@code boolean[]}.

var (
	codabarWriter_START_END_CHARS                               = []byte{'A', 'B', 'C', 'D'}
	codabarWriter_ALT_START_END_CHARS                           = []byte{'T', 'N', '*', 'E'}
	codabarWriter_CHARS_WHICH_ARE_TEN_LENGTH_EACH_AFTER_DECODED = []byte{'/', ':', '+', '.'}
	codabarWriter_DEFAULT_GUARD                                 = string(codabarWriter_START_END_CHARS[0])
)

type codabarEncoder struct{}

func NewCodaBarWriter() gozxing.Writer {
	return NewOneDimensionalCodeWriter(codabarEncoder{})
}

func (codabarEncoder) getSupportedWriteFormats() gozxing.BarcodeFormats {
	return gozxing.BarcodeFormats{gozxing.BarcodeFormat_CODABAR}
}

func (e codabarEncoder) encode(contents string) ([]bool, error) {
	return e.encodeWithHints(contents, nil)
}

func (codabarEncoder) encodeWithHints(contents string, hints map[gozxing.EncodeHintType]interface{}) ([]bool, error) {
	if len(contents) < 2 {
		// Can't have a start/end guard, so tentatively add default guards
		contents = codabarWriter_DEFAULT_GUARD + contents + codabarWriter_DEFAULT_GUARD
	} else {
		// Verify input and calculate decoded length.
		firstChar := byte(strings.ToUpper(contents[:1])[0])
		lastChar := byte(strings.ToUpper(contents[len(contents)-1:])[0])
		startsNormal := codabarReader_arrayContains(codabarWriter_START_END_CHARS, firstChar)
		endsNormal := codabarReader_arrayContains(codabarWriter_START_END_CHARS, lastChar)
		startsAlt := codabarReader_arrayContains(codabarWriter_ALT_START_END_CHARS, firstChar)
		endsAlt := codabarReader_arrayContains(codabarWriter_ALT_START_END_CHARS, lastChar)
		if startsNormal {
			if !endsNormal {
				return nil, gozxing.NewWriterException(
					"IllegalArgumentException: Invalid start/end guards: %s", contents)
			}
			// else already has valid start/end
		} else if startsAlt {
			if !endsAlt {
				return nil, gozxing.NewWriterException(
					"IllegalArgumentException: Invalid start/end guards: %s", contents)
			}
			// else already has valid start/end
		} else {
			// Doesn't start with a guard
			if endsNormal || endsAlt {
				return nil, gozxing.NewWriterException(
					"IllegalArgumentException: Invalid start/end guards: %s", contents)
			}
			// else doesn't end with guard either, so add a default
			contents = codabarWriter_DEFAULT_GUARD + contents + codabarWriter_DEFAULT_GUARD
		}
	}

	// The start character and the end character are decoded to 10 length each.
	resultLength := 20
	for i := 1; i < len(contents)-1; i++ {
		if (contents[i] >= '0' && contents[i] <= '9') || contents[i] == '-' || contents[i] == '$' {
			resultLength += 9
		} else if codabarReader_arrayContains(codabarWriter_CHARS_WHICH_ARE_TEN_LENGTH_EACH_AFTER_DECODED, contents[i]) {
			resultLength += 10
		} else {
			return nil, gozxing.NewWriterException(
				"IllegalArgumentException: Cannot encode : '%c'", contents[i])
		}
	}
	// A blank is placed between each character.
	resultLength += len(contents) - 1

	result := make([]bool, resultLength)
	position := 0
	for index := 0; index < len(contents); index++ {
		c := byte(strings.ToUpper(contents[index : index+1])[0])
		if index == 0 || index == len(contents)-1 {
			// The start/end chars are not in the CodaBarReader.ALPHABET.
			switch c {
			case 'T':
				c = 'A'
				break
			case 'N':
				c = 'B'
				break
			case '*':
				c = 'C'
				break
			case 'E':
				c = 'D'
				break
			}
		}
		code := 0
		for i := 0; i < len(codabarReader_ALPHABET); i++ {
			// Found any, because I checked above.
			if c == codabarReader_ALPHABET[i] {
				code = codabarReader_CHARACTER_ENCODINGS[i]
				break
			}
		}
		color := true
		counter := 0
		bit := 0
		for bit < 7 { // A character consists of 7 digit.
			result[position] = color
			position++
			if ((code>>uint(6-bit))&1) == 0 || counter == 1 {
				color = !color // Flip the color.
				bit++
				counter = 0
			} else {
				counter++
			}
		}
		if index < len(contents)-1 {
			result[position] = false
			position++
		}
	}
	return result, nil
}
