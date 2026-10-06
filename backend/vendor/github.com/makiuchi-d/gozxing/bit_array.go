package gozxing

import (
	"math/bits"

	errors "golang.org/x/xerrors"
)

type BitArray struct {
	bits []uint32
	size int
}

func NewEmptyBitArray() *BitArray {
	return &BitArray{makeArray(1), 0}
}

func NewBitArray(size int) *BitArray {
	return &BitArray{makeArray(size), size}
}

func (b *BitArray) GetSize() int {
	return b.size
}

func (b *BitArray) GetSizeInBytes() int {
	return (b.size + 7) / 8
}

func (b *BitArray) ensureCapacity(size int) {
	if size > len(b.bits)*32 {
		newBits := makeArray(size)
		copy(newBits, b.bits)
		b.bits = newBits
	}
}

func (b *BitArray) Get(i int) bool {
	return (b.bits[i/32] & (1 << uint(i%32))) != 0
}

func (b *BitArray) Set(i int) {
	b.bits[i/32] |= 1 << uint(i%32)
}

func (b *BitArray) Flip(i int) {
	b.bits[i/32] ^= 1 << uint(i%32)
}

func (b *BitArray) GetNextSet(from int) int {
	if from >= b.size {
		return b.size
	}
	bitsOffset := from / 32
	currentBits := b.bits[bitsOffset]
	currentBits &= -(1 << uint(from&0x1F))
	for currentBits == 0 {
		bitsOffset++
		if bitsOffset == len(b.bits) {
			return b.size
		}
		currentBits = b.bits[bitsOffset]
	}
	result := (bitsOffset * 32) + bits.TrailingZeros32(currentBits)
	if result > b.size {
		return b.size
	}
	return result
}

func (b *BitArray) GetNextUnset(from int) int {
	if from >= b.size {
		return b.size
	}
	bitsOffset := from / 32
	currentBits := ^b.bits[bitsOffset]
	currentBits &= -(1 << uint(from&0x1F))
	for currentBits == 0 {
		bitsOffset++
		if bitsOffset == len(b.bits) {
			return b.size
		}
		currentBits = ^b.bits[bitsOffset]
	}
	result := (bitsOffset * 32) + bits.TrailingZeros32(currentBits)
	if result > b.size {
		return b.size
	}
	return result
}

func (b *BitArray) SetBulk(i int, newBits uint32) {
	b.bits[i/32] = newBits
}

func (b *BitArray) SetRange(start, end int) error {
	if end < start || start < 0 || end > b.size {
		return errors.New("IllegalArgumentException")
	}
	if end == start {
		return nil
	}
	end--
	firstInt := start / 32
	lastInt := end / 32
	for i := firstInt; i <= lastInt; i++ {
		firstBit := 0
		lastBit := 31
		if i == firstInt {
			firstBit = start % 32
		}
		if i == lastInt {
			lastBit = end % 32
		}
		mask := (2 << uint(lastBit)) - (1 << uint(firstBit))
		b.bits[i] |= uint32(mask)
	}
	return nil
}

func (b *BitArray) Clear() {
	for i := range b.bits {
		b.bits[i] = 0
	}
}

func (b *BitArray) IsRange(start, end int, value bool) (bool, error) {
	if end < start || start < 0 || end > b.size {
		return false, errors.New("IllegalArgumentException")
	}
	if end == start {
		return true, nil
	}
	end--
	firstInt := start / 32
	lastInt := end / 32
	for i := firstInt; i <= lastInt; i++ {
		firstBit := 0
		lastBit := 31
		if i == firstInt {
			firstBit = start % 32
		}
		if i == lastInt {
			lastBit = end % 32
		}
		mask := uint32((2 << uint(lastBit)) - (1 << uint(firstBit)))
		expect := uint32(0)
		if value {
			expect = mask
		}
		if (b.bits[i] & mask) != expect {
			return false, nil
		}
	}
	return true, nil
}

func (b *BitArray) AppendBit(bit bool) {
	b.ensureCapacity(b.size + 1)
	if bit {
		b.bits[b.size/32] |= 1 << uint(b.size%32)
	}
	b.size++
}

func (b *BitArray) AppendBits(value int, numBits int) error {
	if numBits < 0 || numBits > 32 {
		return errors.New("IllegalArgumentException: Num bits must be between 0 and 32")
	}
	nextSize := b.size
	b.ensureCapacity(nextSize + numBits)
	for numBitsLeft := numBits - 1; numBitsLeft >= 0; numBitsLeft-- {
		if (value & (1 << numBitsLeft)) != 0 {
			b.bits[nextSize/32] |= 1 << (nextSize & 0x1F)
		}
		nextSize++
	}
	b.size = nextSize
	return nil
}

func (b *BitArray) AppendBitArray(other *BitArray) {
	otherSize := other.size
	b.ensureCapacity(b.size + otherSize)
	for i := 0; i < otherSize; i++ {
		b.AppendBit(other.Get(i))
	}
}

func (b *BitArray) Xor(other *BitArray) error {
	if b.size != other.size {
		return errors.New("IllegalArgumentException: Sizes don't match")
	}
	for i := 0; i < len(b.bits); i++ {
		b.bits[i] ^= other.bits[i]
	}
	return nil
}

func (b *BitArray) ToBytes(bitOffset int, array []byte, offset, numBytes int) {
	for i := 0; i < numBytes; i++ {
		theByte := byte(0)
		for j := 0; j < 8; j++ {
			if b.Get(bitOffset) {
				theByte |= 1 << uint(7-j)
			}
			bitOffset++
		}
		array[offset+i] = theByte
	}
}

func (b *BitArray) GetBitArray() []uint32 {
	return b.bits
}

func (b *BitArray) Reverse() {
	newBits := make([]uint32, len(b.bits))
	len := (b.size - 1) / 32
	oldBitsLen := len + 1
	for i := 0; i < oldBitsLen; i++ {
		newBits[len-i] = bits.Reverse32(b.bits[i])
	}
	if b.size != oldBitsLen*32 {
		leftOffset := uint(oldBitsLen*32 - b.size)
		currentInt := newBits[0] >> leftOffset
		for i := 1; i < oldBitsLen; i++ {
			nextInt := newBits[i]
			currentInt |= nextInt << uint(32-leftOffset)
			newBits[i-1] = currentInt
			currentInt = nextInt >> leftOffset
		}
		newBits[oldBitsLen-1] = currentInt
	}
	b.bits = newBits
}

func makeArray(size int) []uint32 {
	return make([]uint32, (size+31)/32)
}

// equals()
// hasCode()

func (b *BitArray) String() string {
	result := make([]byte, 0, b.size+(b.size/8)+1)
	for i := 0; i < b.size; i++ {
		if (i % 8) == 0 {
			result = append(result, ' ')
		}
		if b.Get(i) {
			result = append(result, 'X')
		} else {
			result = append(result, '.')
		}
	}
	return string(result)
}

// clone()
