package encoder

import (
	"github.com/makiuchi-d/gozxing"
)

type C40Encoder struct {
	encodingMode int
	encodeChar   func(byte, []byte) (int, []byte)
}

func NewC40Encoder() Encoder {
	return &C40Encoder{
		HighLevelEncoder_C40_ENCODATION,
		c40EncodeChar,
	}
}

func (this *C40Encoder) getEncodingMode() int {
	return this.encodingMode
}

func (this *C40Encoder) encode(context *EncoderContext) error {
	//step C
	buffer := make([]byte, 0)
	for context.HasMoreCharacters() {
		c := context.GetCurrentChar()
		context.pos++

		var lastCharSize int
		lastCharSize, buffer = this.encodeChar(c, buffer)

		unwritten := (len(buffer) / 3) * 2

		curCodewordCount := context.GetCodewordCount() + unwritten
		e := context.UpdateSymbolInfoByLength(curCodewordCount)
		if e != nil {
			return gozxing.WrapWriterException(e)
		}
		available := context.GetSymbolInfo().GetDataCapacity() - curCodewordCount

		if !context.HasMoreCharacters() {
			//Avoid having a single C40 value in the last triplet
			removed := make([]byte, 0)
			if (len(buffer)%3) == 2 && available != 2 {
				lastCharSize, buffer, removed = this.backtrackOneCharacter(context, buffer, removed, lastCharSize)
			}
			for (len(buffer)%3) == 1 && (lastCharSize > 3 || available != 1) {
				lastCharSize, buffer, removed = this.backtrackOneCharacter(context, buffer, removed, lastCharSize)
			}
			break
		}

		count := len(buffer)
		if (count % 3) == 0 {
			newMode := HighLevelEncoder_lookAheadTest(context.GetMessage(), context.pos, this.getEncodingMode())
			if newMode != this.getEncodingMode() {
				// Return to ASCII encodation, which will actually handle latch to new mode
				context.SignalEncoderChange(HighLevelEncoder_ASCII_ENCODATION)
				break
			}
		}
	}

	return c40HandleEOD(context, buffer)
}

func (this *C40Encoder) backtrackOneCharacter(context *EncoderContext,
	buffer, removed []byte, lastCharSize int) (int, []byte, []byte) {

	count := len(buffer)
	buffer = buffer[:count-lastCharSize]
	context.pos--
	c := context.GetCurrentChar()
	lastCharSize, removed = this.encodeChar(c, removed)
	context.ResetSymbolInfo() //Deal with possible reduction in symbol size
	return lastCharSize, buffer, removed
}

func c40WriteNextTriplet(context *EncoderContext, buffer []byte) []byte {
	context.WriteCodewords(c40EncodeToCodewords(buffer))
	return buffer[3:]
}

// HandleEOD Handle "end of data" situations
//
// @param context the encoder context
// @param buffer  the buffer with the remaining encoded characters
//
func c40HandleEOD(context *EncoderContext, buffer []byte) error {
	unwritten := (len(buffer) / 3) * 2
	rest := len(buffer) % 3

	curCodewordCount := context.GetCodewordCount() + unwritten
	e := context.UpdateSymbolInfoByLength(curCodewordCount)
	if e != nil {
		return gozxing.WrapWriterException(e)
	}
	available := context.GetSymbolInfo().GetDataCapacity() - curCodewordCount

	if rest == 2 {
		buffer = append(buffer, 0) //Shift 1
		for len(buffer) >= 3 {
			buffer = c40WriteNextTriplet(context, buffer)
		}
		if context.HasMoreCharacters() {
			context.WriteCodeword(HighLevelEncoder_C40_UNLATCH)
		}
	} else if available == 1 && rest == 1 {
		for len(buffer) >= 3 {
			buffer = c40WriteNextTriplet(context, buffer)
		}
		if context.HasMoreCharacters() {
			context.WriteCodeword(HighLevelEncoder_C40_UNLATCH)
		}
		// else no unlatch
		context.pos--
	} else if rest == 0 {
		for len(buffer) >= 3 {
			buffer = c40WriteNextTriplet(context, buffer)
		}
		if available > 0 || context.HasMoreCharacters() {
			context.WriteCodeword(HighLevelEncoder_C40_UNLATCH)
		}
	} else {
		return gozxing.NewWriterException("IllegalStateException: Unexpected case. Please report!")
	}
	context.SignalEncoderChange(HighLevelEncoder_ASCII_ENCODATION)
	return nil
}

func c40EncodeChar(c byte, sb []byte) (int, []byte) {
	if c == ' ' {
		sb = append(sb, 3)
		return 1, sb
	}
	if c >= '0' && c <= '9' {
		sb = append(sb, c-48+4)
		return 1, sb
	}
	if c >= 'A' && c <= 'Z' {
		sb = append(sb, c-65+14)
		return 1, sb
	}
	if c < ' ' {
		sb = append(sb, 0) //Shift 1 Set
		sb = append(sb, c)
		return 2, sb
	}
	if c <= '/' {
		sb = append(sb, '\x01') //Shift 2 Set
		sb = append(sb, c-33)
		return 2, sb
	}
	if c <= '@' {
		sb = append(sb, 1) //Shift 2 Set
		sb = append(sb, c-58+15)
		return 2, sb
	}
	if c <= '_' {
		sb = append(sb, 1) //Shift 2 Set
		sb = append(sb, c-91+22)
		return 2, sb
	}
	if c <= 127 {
		sb = append(sb, 2) //Shift 3 Set
		sb = append(sb, c-96)
		return 2, sb
	}
	sb = append(sb, []byte{1, 0x1e}...) //Shift 2, Upper Shift
	len, sb := c40EncodeChar(c-128, sb)
	return len + 2, sb
}

func c40EncodeToCodewords(sb []byte) []byte {
	v := (1600 * int(sb[0])) + (40 * int(sb[1])) + int(sb[2]) + 1
	cw1 := byte(v / 256)
	cw2 := byte(v % 256)
	return []byte{cw1, cw2}
}
