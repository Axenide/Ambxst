package encoder

import (
	"github.com/makiuchi-d/gozxing"
)

type ASCIIEncoder struct{}

func NewASCIIEncoder() Encoder {
	return ASCIIEncoder{}
}

func (this ASCIIEncoder) getEncodingMode() int {
	return HighLevelEncoder_ASCII_ENCODATION
}

func (this ASCIIEncoder) encode(context *EncoderContext) error {
	//step B
	n := HighLevelEncoder_determineConsecutiveDigitCount(context.GetMessage(), context.pos)
	if n >= 2 {
		digits, _ := encodeASCIIDigits(
			context.GetMessage()[context.pos],
			context.GetMessage()[context.pos+1])
		context.WriteCodeword(digits)
		context.pos += 2
	} else {
		c := context.GetCurrentChar()
		newMode := HighLevelEncoder_lookAheadTest(context.GetMessage(), context.pos, this.getEncodingMode())
		if newMode != this.getEncodingMode() {
			switch newMode {
			case HighLevelEncoder_BASE256_ENCODATION:
				context.WriteCodeword(HighLevelEncoder_LATCH_TO_BASE256)
				context.SignalEncoderChange(HighLevelEncoder_BASE256_ENCODATION)
				return nil
			case HighLevelEncoder_C40_ENCODATION:
				context.WriteCodeword(HighLevelEncoder_LATCH_TO_C40)
				context.SignalEncoderChange(HighLevelEncoder_C40_ENCODATION)
				return nil
			case HighLevelEncoder_X12_ENCODATION:
				context.WriteCodeword(HighLevelEncoder_LATCH_TO_ANSIX12)
				context.SignalEncoderChange(HighLevelEncoder_X12_ENCODATION)
				break
			case HighLevelEncoder_TEXT_ENCODATION:
				context.WriteCodeword(HighLevelEncoder_LATCH_TO_TEXT)
				context.SignalEncoderChange(HighLevelEncoder_TEXT_ENCODATION)
				break
			case HighLevelEncoder_EDIFACT_ENCODATION:
				context.WriteCodeword(HighLevelEncoder_LATCH_TO_EDIFACT)
				context.SignalEncoderChange(HighLevelEncoder_EDIFACT_ENCODATION)
				break
			default:
				return gozxing.NewWriterException("IllegalStateException: Illegal mode: %v", newMode)
			}
		} else if HighLevelEncoder_isExtendedASCII(c) {
			context.WriteCodeword(HighLevelEncoder_UPPER_SHIFT)
			context.WriteCodeword(byte(c - 128 + 1))
			context.pos++
		} else {
			context.WriteCodeword(byte(c + 1))
			context.pos++
		}
	}
	return nil
}

func encodeASCIIDigits(digit1, digit2 byte) (byte, error) {
	if HighLevelEncoder_isDigit(digit1) && HighLevelEncoder_isDigit(digit2) {
		num := (digit1-48)*10 + (digit2 - 48)
		return byte(num + 130), nil
	}
	return 0, gozxing.NewWriterException("IllegalArgumentException: not digits: %c%c", digit1, digit2)
}
