package oned

import (
	"strings"

	"github.com/makiuchi-d/gozxing"
)

type code93Encoder struct{}

func NewCode93Writer() gozxing.Writer {
	return NewOneDimensionalCodeWriter(code93Encoder{})
}

func (code93Encoder) getSupportedWriteFormats() gozxing.BarcodeFormats {
	return gozxing.BarcodeFormats{gozxing.BarcodeFormat_CODE_93}
}

func (e code93Encoder) encode(contents string) ([]bool, error) {
	return e.encodeWithHints(contents, nil)
}

// @param contents barcode contents to encode. It should not be encoded for extended characters.
// @return a {@code boolean[]} of horizontal pixels (false = white, true = black)
func (code93Encoder) encodeWithHints(contents string, hints map[gozxing.EncodeHintType]interface{}) ([]bool, error) {
	var e error
	contents, e = code93ConvertToExtended(contents)
	if e != nil {
		return nil, e
	}
	length := len(contents)
	if length > 80 {
		return nil, gozxing.NewWriterException("IllegalArgumentException: "+
			"Requested contents should be less than 80 digits long "+
			"after converting to extended encoding, but got %v", length)
	}

	//length of code + 2 start/stop characters + 2 checksums, each of 9 bits, plus a termination bar
	codeWidth := (len(contents)+2+2)*9 + 1

	result := make([]bool, codeWidth)

	//start character (*)
	pos := code93AppendPattern(result, 0, code93AsteriskEncoding)

	for i := 0; i < length; i++ {
		indexInString := strings.Index(code93AlphabetString, string(contents[i]))
		pos += code93AppendPattern(result, pos, code93CharacterEncodings[indexInString])
	}

	//add two checksums
	check1 := code93ComputeChecksumIndex(contents, 20)
	pos += code93AppendPattern(result, pos, code93CharacterEncodings[check1])

	//append the contents to reflect the first checksum added
	contents += string(code93AlphabetString[check1])

	check2 := code93ComputeChecksumIndex(contents, 15)
	pos += code93AppendPattern(result, pos, code93CharacterEncodings[check2])

	//end character (*)
	pos += code93AppendPattern(result, pos, code93AsteriskEncoding)

	//termination bar (single black bar)
	result[pos] = true

	return result, nil
}

// protected static int appendPattern(boolean[] target, int pos, int[] pattern, boolean startColor)

func code93AppendPattern(target []bool, pos, a int) int {
	for i := 0; i < 9; i++ {
		temp := a & (1 << uint(8-i))
		target[pos+i] = temp != 0
	}
	return 9
}

func code93ComputeChecksumIndex(contents string, maxWeight int) int {
	weight := 1
	total := 0

	for i := len(contents) - 1; i >= 0; i-- {
		indexInString := strings.Index(code93AlphabetString, string(contents[i]))
		total += indexInString * weight
		weight++
		if weight > maxWeight {
			weight = 1
		}
	}
	return total % 47
}

func code93ConvertToExtended(contents string) (string, error) {
	length := len(contents)
	extendedContent := make([]byte, 0, length*2)
	for i := 0; i < length; i++ {
		character := contents[i]
		// ($)=a, (%)=b, (/)=c, (+)=d. see code93AlphabetString
		if character == 0 {
			// NUL: (%)U
			extendedContent = append(extendedContent, []byte("bU")...)
		} else if character <= 26 {
			// SOH - SUB: ($)A - ($)Z
			extendedContent = append(extendedContent, 'a')
			extendedContent = append(extendedContent, 'A'+character-1)
		} else if character <= 31 {
			// ESC - US: (%)A - (%)E
			extendedContent = append(extendedContent, 'b')
			extendedContent = append(extendedContent, 'A'+character-27)
		} else if character == ' ' || character == '$' || character == '%' || character == '+' {
			// space $ % +
			extendedContent = append(extendedContent, character)
		} else if character <= ',' {
			// ! " # & ' ( ) * ,: (/)A - (/)L
			extendedContent = append(extendedContent, 'c')
			extendedContent = append(extendedContent, 'A'+character-'!')
		} else if character <= '9' {
			extendedContent = append(extendedContent, character)
		} else if character == ':' {
			// :: (/)Z
			extendedContent = append(extendedContent, []byte("cZ")...)
		} else if character <= '?' {
			// ; - ?: (%)F - (%)J
			extendedContent = append(extendedContent, 'b')
			extendedContent = append(extendedContent, 'F'+character-';')
		} else if character == '@' {
			// @: (%)V
			extendedContent = append(extendedContent, []byte("bV")...)
		} else if character <= 'Z' {
			// A - Z
			extendedContent = append(extendedContent, character)
		} else if character <= '_' {
			// [ - _: (%)K - (%)O
			extendedContent = append(extendedContent, 'b')
			extendedContent = append(extendedContent, 'K'+character-'[')
		} else if character == '`' {
			// `: (%)W
			extendedContent = append(extendedContent, []byte("bW")...)
		} else if character <= 'z' {
			// a - z: (*)A - (*)Z
			extendedContent = append(extendedContent, 'd')
			extendedContent = append(extendedContent, 'A'+character-'a')
		} else if character <= 127 {
			// { - DEL: (%)P - (%)T
			extendedContent = append(extendedContent, 'b')
			extendedContent = append(extendedContent, 'P'+character-'{')
		} else {
			return string(extendedContent), gozxing.NewWriterException("IllegalArgumentException: "+
				"Requested content contains a non-encodable character: '%v'", character)
		}
	}
	return string(extendedContent), nil
}
