package decoder

import (
	errors "golang.org/x/xerrors"
)

type Mode struct {
	characterCountBitsForVersions []int
	bits                          int
}

var (
	Mode_TERMINATOR           = NewMode([]int{0, 0, 0}, 0x00) // Not really a mode...
	Mode_NUMERIC              = NewMode([]int{10, 12, 14}, 0x01)
	Mode_ALPHANUMERIC         = NewMode([]int{9, 11, 13}, 0x02)
	Mode_STRUCTURED_APPEND    = NewMode([]int{0, 0, 0}, 0x03) // Not supported
	Mode_BYTE                 = NewMode([]int{8, 16, 16}, 0x04)
	Mode_ECI                  = NewMode([]int{0, 0, 0}, 0x07) // character counts don't apply
	Mode_KANJI                = NewMode([]int{8, 10, 12}, 0x08)
	Mode_FNC1_FIRST_POSITION  = NewMode([]int{0, 0, 0}, 0x05)
	Mode_FNC1_SECOND_POSITION = NewMode([]int{0, 0, 0}, 0x09)
	/** See GBT 18284-2000; "Hanzi" is a transliteration of this mode name. */
	Mode_HANZI = NewMode([]int{8, 10, 12}, 0x0D)
)

func NewMode(characterCountBitsForVersions []int, bits int) *Mode {
	return &Mode{characterCountBitsForVersions, bits}
}

func ModeForBits(bits int) (*Mode, error) {
	switch bits {
	case 0x0:
		return Mode_TERMINATOR, nil
	case 0x1:
		return Mode_NUMERIC, nil
	case 0x2:
		return Mode_ALPHANUMERIC, nil
	case 0x3:
		return Mode_STRUCTURED_APPEND, nil
	case 0x4:
		return Mode_BYTE, nil
	case 0x5:
		return Mode_FNC1_FIRST_POSITION, nil
	case 0x7:
		return Mode_ECI, nil
	case 0x8:
		return Mode_KANJI, nil
	case 0x9:
		return Mode_FNC1_SECOND_POSITION, nil
	case 0xD:
		// 0xD is defined in GBT 18284-2000, may not be supported in foreign country
		return Mode_HANZI, nil
	default:
		return nil, errors.New("IllegalArgumentException")
	}
}

func (this *Mode) GetCharacterCountBits(version *Version) int {
	number := version.GetVersionNumber()
	var offset int
	if number <= 9 {
		offset = 0
	} else if number <= 26 {
		offset = 1
	} else {
		offset = 2
	}
	return this.characterCountBitsForVersions[offset]
}

func (this *Mode) GetBits() int {
	return this.bits
}

func (this *Mode) String() string {
	switch this {
	case Mode_TERMINATOR:
		return "TERMINATOR"
	case Mode_NUMERIC:
		return "NUMERIC"
	case Mode_ALPHANUMERIC:
		return "ALPHANUMERIC"
	case Mode_STRUCTURED_APPEND:
		return "STRUCTURED_APPEND"
	case Mode_BYTE:
		return "BYTE"
	case Mode_ECI:
		return "ECI"
	case Mode_KANJI:
		return "KANJI"
	case Mode_FNC1_FIRST_POSITION:
		return "FNC1_FIRST_POSITION"
	case Mode_FNC1_SECOND_POSITION:
		return "FNC1_SECOND_POSITION"
	case Mode_HANZI:
		return "HANZI"
	default:
		return ""
	}
}
