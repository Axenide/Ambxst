package encoder

func NewTextEncoder() Encoder {
	return &C40Encoder{
		HighLevelEncoder_TEXT_ENCODATION,
		textEncodeChar,
	}
}

func textEncodeChar(c byte, sb []byte) (int, []byte) {
	if c == ' ' {
		sb = append(sb, 3)
		return 1, sb
	}
	if c >= '0' && c <= '9' {
		sb = append(sb, c-48+4)
		return 1, sb
	}
	if c >= 'a' && c <= 'z' {
		sb = append(sb, c-97+14)
		return 1, sb
	}
	if c < ' ' {
		sb = append(sb, 0) //Shift 1 Set
		sb = append(sb, c)
		return 2, sb
	}
	if c <= '/' {
		sb = append(sb, 1) //Shift 2 Set
		sb = append(sb, c-33)
		return 2, sb
	}
	if c <= '@' {
		sb = append(sb, 1) //Shift 2 Set
		sb = append(sb, c-58+15)
		return 2, sb
	}
	if c >= '[' && c <= '_' {
		sb = append(sb, 1) //Shift 2 Set
		sb = append(sb, c-91+22)
		return 2, sb
	}
	if c == '`' {
		sb = append(sb, 2) //Shift 3 Set
		sb = append(sb, 0) // '`' - 96 == 0
		return 2, sb
	}
	if c <= 'Z' {
		sb = append(sb, 2) //Shift 3 Set
		sb = append(sb, c-65+1)
		return 2, sb
	}
	if c <= 127 {
		sb = append(sb, 2) //Shift 3 Set
		sb = append(sb, c-123+27)
		return 2, sb
	}
	sb = append(sb, []byte{1, 0x1e}...) //Shift 2, Upper Shift
	var len int
	len, sb = textEncodeChar(c-128, sb)
	len += 2
	return len, sb
}
