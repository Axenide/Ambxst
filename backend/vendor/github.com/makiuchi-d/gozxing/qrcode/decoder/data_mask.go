package decoder

import (
	"github.com/makiuchi-d/gozxing"
)

var DataMaskValues = []DataMask{

	// See ISO 18004:2006 6.8.1

	/**
	 * 000: mask bits for which (x + y) mod 2 == 0
	 */
	{ // DATA_MASK_000
		func(i, j int) bool {
			return ((i + j) & 0x01) == 0
		},
	},

	/**
	 * 001: mask bits for which x mod 2 == 0
	 */
	{ // DATA_MASK_001
		func(i, j int) bool {
			return (i & 0x01) == 0
		},
	},

	/**
	 * 010: mask bits for which y mod 3 == 0
	 */
	{ // DATA_MASK_010
		func(i, j int) bool {
			return j%3 == 0
		},
	},

	/**
	 * 011: mask bits for which (x + y) mod 3 == 0
	 */
	{ // DATA_MASK_011
		func(i, j int) bool {
			return (i+j)%3 == 0
		},
	},

	/**
	 * 100: mask bits for which (x/2 + y/3) mod 2 == 0
	 */
	{ // DATA_MASK_100
		func(i, j int) bool {
			return (((i / 2) + (j / 3)) & 0x01) == 0
		},
	},

	/**
	 * 101: mask bits for which xy mod 2 + xy mod 3 == 0
	 * equivalently, such that xy mod 6 == 0
	 */
	{ // DATA_MASK_101
		func(i, j int) bool {
			return (i*j)%6 == 0
		},
	},

	/**
	 * 110: mask bits for which (xy mod 2 + xy mod 3) mod 2 == 0
	 * equivalently, such that xy mod 6 < 3
	 */
	{ // DATA_MASK_110
		func(i, j int) bool {
			return ((i * j) % 6) < 3
		},
	},

	/**
	 * 111: mask bits for which ((x+y)mod 2 + xy mod 3) mod 2 == 0
	 * equivalently, such that (x + y + xy mod 3) mod 2 == 0
	 */
	{ // DATA_MASK_111
		func(i, j int) bool {
			return ((i + j + ((i * j) % 3)) & 0x01) == 0
		},
	},
}

type DataMask struct {
	isMasked func(i, j int) bool
}

func (this DataMask) UnmaskBitMatrix(bits *gozxing.BitMatrix, dimension int) {
	for i := 0; i < dimension; i++ {
		for j := 0; j < dimension; j++ {
			if this.isMasked(i, j) {
				bits.Flip(j, i)
			}
		}
	}
}
