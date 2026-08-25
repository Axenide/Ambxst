package gozxing

import (
	"math/bits"
	"strings"

	errors "golang.org/x/xerrors"
)

type BitMatrix struct {
	width   int
	height  int
	rowSize int
	bits    []uint32
}

func NewSquareBitMatrix(dimension int) (*BitMatrix, error) {
	return NewBitMatrix(dimension, dimension)
}

func NewBitMatrix(width, height int) (*BitMatrix, error) {
	if width < 1 || height < 1 {
		return nil, errors.New("IllegalArgumentException: Both dimensions must be greater than 0")
	}
	rowSize := (width + 31) / 32
	bits := make([]uint32, rowSize*height)
	return &BitMatrix{width, height, rowSize, bits}, nil
}

func ParseBoolMapToBitMatrix(image [][]bool) (*BitMatrix, error) {
	var width, height int
	height = len(image)
	if height > 0 {
		width = len(image[0])
	}
	bits, e := NewBitMatrix(width, height)
	if e != nil {
		return nil, e
	}
	for i := 0; i < height; i++ {
		imageI := image[i]
		for j := 0; j < width; j++ {
			if imageI[j] {
				bits.Set(j, i)
			}
		}
	}
	return bits, nil
}

func ParseStringToBitMatrix(stringRepresentation, setString, unsetString string) (*BitMatrix, error) {
	if stringRepresentation == "" {
		return nil, errors.New("IllegalArgumentException")
	}

	bits := make([]bool, len(stringRepresentation))
	bitsPos := 0
	rowStartPos := 0
	rowLength := -1
	nRows := 0
	pos := 0
	for pos < len(stringRepresentation) {
		if c := stringRepresentation[pos]; c == '\n' || c == '\r' {
			if bitsPos > rowStartPos {
				if rowLength == -1 {
					rowLength = bitsPos - rowStartPos
				} else if bitsPos-rowStartPos != rowLength {
					return nil, errors.New("IllegalArgumentException: row length do not match")
				}
				rowStartPos = bitsPos
				nRows++
			}
			pos++
		} else if strings.HasPrefix(stringRepresentation[pos:], setString) {
			pos += len(setString)
			bits[bitsPos] = true
			bitsPos++
		} else if strings.HasPrefix(stringRepresentation[pos:], unsetString) {
			pos += len(unsetString)
			bits[bitsPos] = false
			bitsPos++
		} else {
			return nil, errors.New(
				"IllegalArgumentException: illegal character encountered: " + stringRepresentation[pos:])
		}
	}

	if bitsPos > rowStartPos {
		if rowLength == -1 {
			rowLength = bitsPos - rowStartPos
		} else if bitsPos-rowStartPos != rowLength {
			return nil, errors.New("IllegalArgumentException: row length do not match")
		}
		nRows++
	}
	matrix, e := NewBitMatrix(rowLength, nRows)
	if e != nil {
		return nil, e
	}
	for i := 0; i < bitsPos; i++ {
		if bits[i] {
			matrix.Set(i%rowLength, i/rowLength)
		}
	}
	return matrix, nil
}

func (b *BitMatrix) Get(x, y int) bool {
	if x < 0 || x >= b.width || y < 0 || y >= b.height {
		return false
	}
	offset := (y * b.rowSize) + (x / 32)
	return ((b.bits[offset] >> uint(x%32)) & 1) != 0
}

func (b *BitMatrix) Set(x, y int) {
	offset := (y * b.rowSize) + (x / 32)
	b.bits[offset] |= 1 << uint(x%32)
}

func (b *BitMatrix) Unset(x, y int) {
	offset := (y * b.rowSize) + (x / 32)
	b.bits[offset] &= ^(1 << uint(x%32))
}

func (b *BitMatrix) Flip(x, y int) {
	offset := (y * b.rowSize) + (x / 32)
	b.bits[offset] ^= 1 << uint(x%32)
}

func (b *BitMatrix) FlipAll() {
	max := len(b.bits)
	for i := 0; i < max; i++ {
		b.bits[i] = ^b.bits[i]
	}
}

func (b *BitMatrix) Xor(mask *BitMatrix) error {
	if b.width != mask.width || b.height != mask.height || b.rowSize != mask.rowSize {
		return errors.New("IllegalArgumentException: input matrix dimensions do not match")
	}
	for y := 0; y < b.height; y++ {
		bOffset := y * b.rowSize
		mOffset := y * mask.rowSize
		for x := 0; x < b.rowSize; x++ {
			b.bits[bOffset+x] ^= mask.bits[mOffset+x]
		}
	}

	return nil
}

func (b *BitMatrix) Clear() {
	max := len(b.bits)
	for i := 0; i < max; i++ {
		b.bits[i] = 0
	}
}

func (b *BitMatrix) SetRegion(left, top, width, height int) error {
	if top < 0 || left < 0 {
		return errors.New("IllegalArgumentException: Left and top must be nonnegative")
	}
	if height < 1 || width < 1 {
		return errors.New("IllegalArgumentException: Height and width must be at least 1")
	}
	right := left + width
	bottom := top + height
	if bottom > b.height || right > b.width {
		return errors.New("IllegalArgumentException: The region must fit inside the matrix")
	}
	for y := top; y < bottom; y++ {
		offset := y * b.rowSize
		for x := left; x < right; x++ {
			b.bits[offset+(x/32)] |= 1 << uint(x%32)
		}
	}
	return nil
}

func (b *BitMatrix) GetRow(y int, row *BitArray) *BitArray {
	if row == nil || row.GetSize() < b.width {
		row = NewBitArray(b.width)
	} else {
		row.Clear()
	}
	offset := y * b.rowSize
	for x := 0; x < b.rowSize; x++ {
		row.SetBulk(x*32, b.bits[offset+x])
	}
	return row
}

func (b *BitMatrix) SetRow(y int, row *BitArray) {
	offset := y * b.rowSize
	copy(b.bits[offset:offset+b.rowSize], row.bits)
}

func (b *BitMatrix) Rotate180() {
	height := b.height
	rowSize := b.rowSize
	for i := 0; i < height/2; i++ {
		topOffset := i * rowSize
		bottomOffset := (height-i)*rowSize - 1
		for j := 0; j < rowSize; j++ {
			top := topOffset + j
			bottom := bottomOffset - j
			b.bits[top], b.bits[bottom] = b.bits[bottom], b.bits[top]
		}
	}
	if height%2 != 0 {
		offset := rowSize * (height - 1) / 2
		for j := 0; j < rowSize/2; j++ {
			left := offset + j
			right := offset + rowSize - 1 - j
			b.bits[left], b.bits[right] = b.bits[right], b.bits[left]
		}
	}

	if shift := uint(b.width % 32); shift != 0 {
		for i := 0; i < height; i++ {
			offset := rowSize * i
			b.bits[offset] = bits.Reverse32(b.bits[offset]) >> uint(32-shift)
			for j := 1; j < rowSize; j++ {
				curbits := bits.Reverse32(b.bits[offset+j])
				b.bits[offset+j-1] |= curbits << shift
				b.bits[offset+j] = curbits >> uint(32-shift)
			}
		}
	}
}

func (b *BitMatrix) Rotate90() {
	newWidth := b.height
	newHeight := b.width
	newRowSize := (newWidth + 31) / 32
	newBits := make([]uint32, newRowSize*newHeight)

	for y := 0; y < b.height; y++ {
		for x := 0; x < b.width; x++ {
			offset := y*b.rowSize + (x / 32)
			if ((b.bits[offset] >> (x & 0x1f)) & 1) != 0 {
				newOffset := (newHeight-1-x)*newRowSize + (y / 32)
				newBits[newOffset] |= 1 << (y & 0x1f)
			}
		}
	}
	b.width = newWidth
	b.height = newHeight
	b.rowSize = newRowSize
	b.bits = newBits
}

func (b *BitMatrix) GetEnclosingRectangle() []int {
	left := b.width
	top := b.height
	right := -1
	bottom := -1

	for y := 0; y < b.height; y++ {
		for x32 := 0; x32 < b.rowSize; x32++ {
			theBits := b.bits[y*b.rowSize+x32]
			if theBits != 0 {
				if y < top {
					top = y
				}
				if y > bottom {
					bottom = y
				}
				if x32*32 < left {
					bit := 0
					for (theBits << uint(31-bit)) == 0 {
						bit++
					}
					if (x32*32 + bit) < left {
						left = x32*32 + bit
					}
				}
				if x32*32+31 > right {
					bit := 31
					for (theBits >> uint(bit)) == 0 {
						bit--
					}
					if (x32*32 + bit) > right {
						right = x32*32 + bit
					}
				}
			}
		}
	}

	if right < left || bottom < top {
		return nil
	}

	return []int{left, top, right - left + 1, bottom - top + 1}
}

func (b *BitMatrix) GetTopLeftOnBit() []int {
	bitsOffset := 0
	for bitsOffset < len(b.bits) && b.bits[bitsOffset] == 0 {
		bitsOffset++
	}
	if bitsOffset == len(b.bits) {
		return nil
	}
	y := bitsOffset / b.rowSize
	x := (bitsOffset % b.rowSize) * 32

	theBits := b.bits[bitsOffset]
	bit := uint(0)
	for (theBits << (31 - bit)) == 0 {
		bit++
	}
	x += int(bit)
	return []int{x, y}
}

func (b *BitMatrix) GetBottomRightOnBit() []int {
	bitsOffset := len(b.bits) - 1
	for bitsOffset >= 0 && b.bits[bitsOffset] == 0 {
		bitsOffset--
	}
	if bitsOffset < 0 {
		return nil
	}

	y := bitsOffset / b.rowSize
	x := (bitsOffset % b.rowSize) * 32

	theBits := b.bits[bitsOffset]
	bit := uint(31)
	for (theBits >> bit) == 0 {
		bit--
	}
	x += int(bit)

	return []int{x, y}
}

func (b *BitMatrix) GetWidth() int {
	return b.width
}

func (b *BitMatrix) GetHeight() int {
	return b.height
}

func (b *BitMatrix) GetRowSize() int {
	return b.rowSize
}

//  public boolean equals(Object o)
//  public int hashCode()

func (b *BitMatrix) String() string {
	return b.ToString("X ", "  ")
}

func (b *BitMatrix) ToString(setString, unsetString string) string {
	return b.ToStringWithLineSeparator(setString, unsetString, "\n")
}

func (b *BitMatrix) ToStringWithLineSeparator(setString, unsetString, lineSeparator string) string {
	setBytes := []byte(setString)
	unsetBytes := []byte(unsetString)
	lineSepBytes := []byte(lineSeparator)

	lineSize := len(lineSeparator)
	if len(setString) > len(unsetString) {
		lineSize += b.width * len(setString)
	} else {
		lineSize += b.width * len(unsetString)
	}
	result := make([]byte, 0, b.height*lineSize)

	for y := 0; y < b.height; y++ {
		for x := 0; x < b.width; x++ {
			var s []byte
			if b.Get(x, y) {
				s = setBytes
			} else {
				s = unsetBytes
			}
			result = append(result, s...)
		}
		result = append(result, lineSepBytes...)
	}
	return string(result)
}

//  public BitMatrix clone()
