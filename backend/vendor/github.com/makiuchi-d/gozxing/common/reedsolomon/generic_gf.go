package reedsolomon

import (
	"fmt"

	errors "golang.org/x/xerrors"
)

var (
	GenericGF_AZTEC_DATA_12         = NewGenericGF(0x1069, 4096, 1) // x^12 + x^6 + x^5 + x^3 + 1
	GenericGF_AZTEC_DATA_10         = NewGenericGF(0x409, 1024, 1)  // x^10 + x^3 + 1
	GenericGF_AZTEC_DATA_6          = NewGenericGF(0x43, 64, 1)     // x^6 + x + 1
	GenericGF_AZTEC_PARAM           = NewGenericGF(0x13, 16, 1)     // x^4 + x + 1
	GenericGF_QR_CODE_FIELD_256     = NewGenericGF(0x011D, 256, 0)  // x^8 + x^4 + x^3 + x^2 + 1
	GenericGF_DATA_MATRIX_FIELD_256 = NewGenericGF(0x012D, 256, 1)  // x^8 + x^5 + x^3 + x^2 + 1
	GenericGF_AZTEC_DATA_8          = GenericGF_DATA_MATRIX_FIELD_256
	GenericGF_MAXICODE_FIELD_64     = GenericGF_AZTEC_DATA_6
)

type GenericGF struct {
	expTable      []int
	logTable      []int
	zero          *GenericGFPoly
	one           *GenericGFPoly
	size          int
	primitive     int
	generatorBase int
}

func NewGenericGF(primitive, size, b int) *GenericGF {
	this := &GenericGF{
		primitive:     primitive,
		size:          size,
		generatorBase: b,
	}

	expTable := make([]int, size)
	logTable := make([]int, size)
	x := 1
	for i := 0; i < size; i++ {
		expTable[i] = x
		x *= 2 // we're assuming the generator alpha is 2
		if x >= size {
			x ^= primitive
			x &= size - 1
		}
	}
	for i := 0; i < size-1; i++ {
		logTable[expTable[i]] = i
	}
	this.expTable = expTable
	this.logTable = logTable
	// logTable[0] == 0 but this should never be used
	this.zero, _ = NewGenericGFPoly(this, []int{0})
	this.one, _ = NewGenericGFPoly(this, []int{1})

	return this
}

func (this *GenericGF) GetZero() *GenericGFPoly {
	return this.zero
}

func (this *GenericGF) GetOne() *GenericGFPoly {
	return this.one
}

func (this *GenericGF) BuildMonomial(degree, coefficient int) (*GenericGFPoly, error) {
	if degree < 0 {
		return nil, errors.New("IllegalArgumentException")
	}
	if coefficient == 0 {
		return this.zero, nil
	}

	coefficients := make([]int, degree+1)
	coefficients[0] = coefficient
	return NewGenericGFPoly(this, coefficients)
}

func GenericGF_addOrSubtract(a, b int) int {
	return a ^ b
}

func (this *GenericGF) Exp(a int) int {
	return this.expTable[a]
}

func (this *GenericGF) Log(a int) (int, error) {
	if a == 0 {
		return 0, errors.New("IllegalArgumentException")
	}
	return this.logTable[a], nil
}

func (this *GenericGF) Inverse(a int) (int, error) {
	if a == 0 {
		return 0, errors.New("IllegalArgumentException")
	}
	return this.expTable[this.size-this.logTable[a]-1], nil
}

func (this *GenericGF) Multiply(a, b int) int {
	if a == 0 || b == 0 {
		return 0
	}
	return this.expTable[(this.logTable[a]+this.logTable[b])%(this.size-1)]
}

func (this *GenericGF) GetSize() int {
	return this.size
}

func (this *GenericGF) GetGeneratorBase() int {
	return this.generatorBase
}

func (this *GenericGF) String() string {
	return fmt.Sprintf("GF(0x%x,%d)", this.primitive, this.size)
}
