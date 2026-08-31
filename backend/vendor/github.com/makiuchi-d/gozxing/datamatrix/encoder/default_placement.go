package encoder

type DefaultPlacement struct {
	codewords []byte
	numrows   int
	numcols   int
	bits      []int8
}

func NewDefaultPlacement(codewords []byte, numcols, numrows int) *DefaultPlacement {
	p := &DefaultPlacement{
		codewords: codewords,
		numcols:   numcols,
		numrows:   numrows,
		bits:      make([]int8, numcols*numrows),
	}
	for i := range p.bits {
		p.bits[i] = -1
	}
	return p
}

func (this *DefaultPlacement) getNumrows() int {
	return this.numrows
}

func (this *DefaultPlacement) getNumcols() int {
	return this.numcols
}

func (this *DefaultPlacement) getBits() []int8 {
	return this.bits
}

func (this *DefaultPlacement) GetBit(col, row int) bool {
	return this.bits[row*this.numcols+col] == 1
}

func (this *DefaultPlacement) setBit(col, row int, bit bool) {
	b := int8(0)
	if bit {
		b = 1
	}
	this.bits[row*this.numcols+col] = b
}

func (this *DefaultPlacement) hasBit(col, row int) bool {
	return this.bits[row*this.numcols+col] >= 0
}

func (this *DefaultPlacement) Place() {
	pos := 0
	row := 4
	col := 0

	for {
		// repeatedly first check for one of the special corner cases, then...
		if (row == this.numrows) && (col == 0) {
			this.corner1(pos)
			pos++
		}
		if (row == this.numrows-2) && (col == 0) && ((this.numcols % 4) != 0) {
			this.corner2(pos)
			pos++
		}
		if (row == this.numrows-2) && (col == 0) && (this.numcols%8 == 4) {
			this.corner3(pos)
			pos++
		}
		if (row == this.numrows+4) && (col == 2) && ((this.numcols % 8) == 0) {
			this.corner4(pos)
			pos++
		}
		// sweep upward diagonally, inserting successive characters...
		for {
			if (row < this.numrows) && (col >= 0) && !this.hasBit(col, row) {
				this.utah(row, col, pos)
				pos++
			}
			row -= 2
			col += 2
			if row < 0 || (col >= this.numcols) {
				break
			}
		}
		row++
		col += 3

		// and then sweep downward diagonally, inserting successive characters, ...
		for {
			if (row >= 0) && (col < this.numcols) && !this.hasBit(col, row) {
				this.utah(row, col, pos)
				pos++
			}
			row += 2
			col -= 2
			if row >= this.numrows || col < 0 {
				break
			}
		}
		row += 3
		col++

		// ...until the entire array is scanned
		if row >= this.numrows && col >= this.numcols {
			break
		}
	}

	// Lastly, if the lower righthand corner is untouched, fill in fixed pattern
	if !this.hasBit(this.numcols-1, this.numrows-1) {
		this.setBit(this.numcols-1, this.numrows-1, true)
		this.setBit(this.numcols-2, this.numrows-2, true)
	}
}

func (this *DefaultPlacement) module(row, col, pos, bit int) {
	if row < 0 {
		row += this.numrows
		col += 4 - ((this.numrows + 4) % 8)
	}
	if col < 0 {
		col += this.numcols
		row += 4 - ((this.numcols + 4) % 8)
	}
	// Note the conversion:
	v := this.codewords[pos]
	v &= 1 << uint(8-bit)
	this.setBit(col, row, v != 0)
}

// utah Places the 8 bits of a utah-shaped symbol character in ECC200.
//
// @param row the row
// @param col the column
// @param pos character position
func (this *DefaultPlacement) utah(row, col, pos int) {
	this.module(row-2, col-2, pos, 1)
	this.module(row-2, col-1, pos, 2)
	this.module(row-1, col-2, pos, 3)
	this.module(row-1, col-1, pos, 4)
	this.module(row-1, col, pos, 5)
	this.module(row, col-2, pos, 6)
	this.module(row, col-1, pos, 7)
	this.module(row, col, pos, 8)
}

func (this *DefaultPlacement) corner1(pos int) {
	this.module(this.numrows-1, 0, pos, 1)
	this.module(this.numrows-1, 1, pos, 2)
	this.module(this.numrows-1, 2, pos, 3)
	this.module(0, this.numcols-2, pos, 4)
	this.module(0, this.numcols-1, pos, 5)
	this.module(1, this.numcols-1, pos, 6)
	this.module(2, this.numcols-1, pos, 7)
	this.module(3, this.numcols-1, pos, 8)
}

func (this *DefaultPlacement) corner2(pos int) {
	this.module(this.numrows-3, 0, pos, 1)
	this.module(this.numrows-2, 0, pos, 2)
	this.module(this.numrows-1, 0, pos, 3)
	this.module(0, this.numcols-4, pos, 4)
	this.module(0, this.numcols-3, pos, 5)
	this.module(0, this.numcols-2, pos, 6)
	this.module(0, this.numcols-1, pos, 7)
	this.module(1, this.numcols-1, pos, 8)
}

func (this *DefaultPlacement) corner3(pos int) {
	this.module(this.numrows-3, 0, pos, 1)
	this.module(this.numrows-2, 0, pos, 2)
	this.module(this.numrows-1, 0, pos, 3)
	this.module(0, this.numcols-2, pos, 4)
	this.module(0, this.numcols-1, pos, 5)
	this.module(1, this.numcols-1, pos, 6)
	this.module(2, this.numcols-1, pos, 7)
	this.module(3, this.numcols-1, pos, 8)
}

func (this *DefaultPlacement) corner4(pos int) {
	this.module(this.numrows-1, 0, pos, 1)
	this.module(this.numrows-1, this.numcols-1, pos, 2)
	this.module(0, this.numcols-3, pos, 3)
	this.module(0, this.numcols-2, pos, 4)
	this.module(0, this.numcols-1, pos, 5)
	this.module(1, this.numcols-3, pos, 6)
	this.module(1, this.numcols-2, pos, 7)
	this.module(1, this.numcols-1, pos, 8)
}
