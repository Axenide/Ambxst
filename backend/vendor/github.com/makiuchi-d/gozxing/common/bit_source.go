package common

import (
	errors "golang.org/x/xerrors"
)

type BitSource struct {
	bytes      []byte
	byteOffset int
	bitOffset  int
}

func NewBitSource(bytes []byte) *BitSource {
	return &BitSource{
		bytes: bytes,
	}
}

func (this *BitSource) GetBitOffset() int {
	return this.bitOffset
}

func (this *BitSource) GetByteOffset() int {
	return this.byteOffset
}

func (this *BitSource) ReadBits(numBits int) (int, error) {
	if numBits < 1 || numBits > 32 || numBits > this.Available() {
		return 0, errors.Errorf("IllegalArgumentException: %v", numBits)
	}

	result := 0

	// First, read remainder from current byte
	if this.bitOffset > 0 {
		bitsLeft := 8 - this.bitOffset
		toRead := bitsLeft
		if numBits < bitsLeft {
			toRead = numBits
		}
		bitsToNotRead := uint(bitsLeft - toRead)
		mask := byte((0xFF >> uint(8-toRead)) << bitsToNotRead)
		result = int(this.bytes[this.byteOffset]&mask) >> bitsToNotRead
		numBits -= toRead
		this.bitOffset += toRead
		if this.bitOffset == 8 {
			this.bitOffset = 0
			this.byteOffset++
		}
	}

	// Next read whole bytes
	if numBits > 0 {
		for numBits >= 8 {
			result = (result << 8) | int(this.bytes[this.byteOffset]&0xFF)
			this.byteOffset++
			numBits -= 8
		}

		// Finally read a partial byte
		if numBits > 0 {
			bitsToNotRead := uint(8 - numBits)
			mask := byte((0xFF >> bitsToNotRead) << bitsToNotRead)
			result = (result << uint(numBits)) | int((this.bytes[this.byteOffset]&mask)>>bitsToNotRead)
			this.bitOffset += numBits
		}
	}

	return result, nil
}

func (this *BitSource) Available() int {
	return 8*(len(this.bytes)-this.byteOffset) - this.bitOffset
}
