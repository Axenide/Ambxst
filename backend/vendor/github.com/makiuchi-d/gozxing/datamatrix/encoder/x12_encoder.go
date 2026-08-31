package encoder

import (
	"github.com/makiuchi-d/gozxing"
)

type X12Encoder struct{}

func NewX12Encoder() Encoder {
	return X12Encoder{}
}

func (this X12Encoder) getEncodingMode() int {
	return HighLevelEncoder_X12_ENCODATION
}

func (this X12Encoder) encode(context *EncoderContext) error {
	//step C
	buffer := make([]byte, 0)
	for context.HasMoreCharacters() {
		c := context.GetCurrentChar()
		context.pos++

		var e error
		buffer, e = x12EncodeChar(c, buffer)
		if e != nil {
			return e
		}

		count := len(buffer)
		if (count % 3) == 0 {
			buffer = c40WriteNextTriplet(context, buffer)

			newMode := HighLevelEncoder_lookAheadTest(context.GetMessage(), context.pos, this.getEncodingMode())
			if newMode != this.getEncodingMode() {
				// Return to ASCII encodation, which will actually handle latch to new mode
				context.SignalEncoderChange(HighLevelEncoder_ASCII_ENCODATION)
				break
			}
		}
	}
	return x12HandleEOD(context, buffer)
}

func x12EncodeChar(c byte, sb []byte) ([]byte, error) {
	switch c {
	case '\r':
		sb = append(sb, 0)
	case '*':
		sb = append(sb, 1)
	case '>':
		sb = append(sb, 2)
	case ' ':
		sb = append(sb, 3)
	default:
		if c >= '0' && c <= '9' {
			sb = append(sb, c-48+4)
		} else if c >= 'A' && c <= 'Z' {
			sb = append(sb, c-65+14)
		} else {
			return sb, gozxing.NewWriterException("Illegal character: %v (0x%04x)", c, c)
		}
	}
	return sb, nil
}

func x12HandleEOD(context *EncoderContext, buffer []byte) error {
	e := context.UpdateSymbolInfo()
	if e != nil {
		return gozxing.WrapWriterException(e)
	}
	available := context.GetSymbolInfo().GetDataCapacity() - context.GetCodewordCount()
	count := len(buffer)
	context.pos -= count
	if context.GetRemainingCharacters() > 1 || available > 1 ||
		context.GetRemainingCharacters() != available {
		context.WriteCodeword(HighLevelEncoder_X12_UNLATCH)
	}
	if context.GetNewEncoding() < 0 {
		context.SignalEncoderChange(HighLevelEncoder_ASCII_ENCODATION)
	}
	return nil
}
