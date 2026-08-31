package oned

import (
	"strings"

	"github.com/makiuchi-d/gozxing"
)

type code39Encoder struct{}

func NewCode39Writer() gozxing.Writer {
	return NewOneDimensionalCodeWriter(code39Encoder{})
}

func (code39Encoder) getSupportedWriteFormats() gozxing.BarcodeFormats {
	return gozxing.BarcodeFormats{gozxing.BarcodeFormat_CODE_39}
}

func (e code39Encoder) encode(contents string) ([]bool, error) {
	return e.encodeWithHints(contents, nil)
}

func (code39Encoder) encodeWithHints(contents string, hints map[gozxing.EncodeHintType]interface{}) ([]bool, error) {
	length := len(contents)
	if length > 80 {
		return nil, gozxing.NewWriterException("IllegalArgumentException: "+
			"Requested contents should be less than 80 digits long, but got %v", length)
	}
	for i := 0; i < length; i++ {
		indexInString := strings.Index(code39AlphabetString, string(contents[i]))
		if indexInString < 0 {
			var e error
			contents, e = code39TryToConvertToExtendedMode(contents)
			if e != nil {
				return nil, e
			}
			length = len(contents)
			if length > 80 {
				return nil, gozxing.NewWriterException("IllegalArgumentException: "+
					"Requested contents should be less than 80 digits long, but got %v (extended full ASCII mode)", length)
			}
			break
		}
	}

	widths := make([]int, 9)
	codeWidth := 24 + 1 + (13 * length)
	result := make([]bool, codeWidth)
	code39ToIntArray(code39AsteriskEncoding, widths)
	pos := onedWriter_appendPattern(result, 0, widths, true)
	narrowWhite := []int{1}
	pos += onedWriter_appendPattern(result, pos, narrowWhite, false)
	//append next character to byte matrix
	for i := 0; i < length; i++ {
		indexInString := strings.Index(code39AlphabetString, string(contents[i]))
		code39ToIntArray(code39CharacterEncodings[indexInString], widths)
		pos += onedWriter_appendPattern(result, pos, widths, true)
		pos += onedWriter_appendPattern(result, pos, narrowWhite, false)
	}
	code39ToIntArray(code39AsteriskEncoding, widths)
	onedWriter_appendPattern(result, pos, widths, true)
	return result, nil
}

func code39ToIntArray(a int, toReturn []int) {
	for i := 0; i < 9; i++ {
		temp := a & (1 << uint(8-i))
		if temp == 0 {
			toReturn[i] = 1
		} else {
			toReturn[i] = 2
		}
	}
}

func code39TryToConvertToExtendedMode(contents string) (string, error) {
	length := len(contents)
	extendedContent := make([]byte, 0)
	for i := 0; i < length; i++ {
		character := contents[i]
		switch character {
		case '\u0000':
			extendedContent = append(extendedContent, []byte("%U")...)
			break
		case ' ', '-', '.':
			extendedContent = append(extendedContent, character)
			break
		case '@':
			extendedContent = append(extendedContent, []byte("%V")...)
			break
		case '`':
			extendedContent = append(extendedContent, []byte("%W")...)
			break
		default:
			if character <= 26 {
				extendedContent = append(extendedContent, '$')
				extendedContent = append(extendedContent, 'A'+(character-1))
			} else if character < ' ' {
				extendedContent = append(extendedContent, '%')
				extendedContent = append(extendedContent, 'A'+(character-27))
			} else if character <= ',' || character == '/' || character == ':' {
				extendedContent = append(extendedContent, '/')
				extendedContent = append(extendedContent, 'A'+(character-33))
			} else if character <= '9' {
				extendedContent = append(extendedContent, '0'+(character-48))
			} else if character <= '?' {
				extendedContent = append(extendedContent, '%')
				extendedContent = append(extendedContent, 'F'+(character-59))
			} else if character <= 'Z' {
				extendedContent = append(extendedContent, 'A'+(character-65))
			} else if character <= '_' {
				extendedContent = append(extendedContent, '%')
				extendedContent = append(extendedContent, 'K'+(character-91))
			} else if character <= 'z' {
				extendedContent = append(extendedContent, '+')
				extendedContent = append(extendedContent, 'A'+(character-97))
			} else if character <= 127 {
				extendedContent = append(extendedContent, '%')
				extendedContent = append(extendedContent, 'P'+(character-123))
			} else {
				return string(extendedContent), gozxing.NewWriterException(
					"IllegalArgumentException: Requested content contains a non-encodable character: '%v'", contents[i])
			}
			break
		}
	}

	return string(extendedContent), nil
}
