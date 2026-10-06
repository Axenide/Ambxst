package reedsolomon

import (
	errors "golang.org/x/xerrors"
)

type ReedSolomonEncoder struct {
	field            *GenericGF
	cachedGenerators []*GenericGFPoly
}

func NewReedSolomonEncoder(field *GenericGF) *ReedSolomonEncoder {
	gen, _ := NewGenericGFPoly(field, []int{1})
	return &ReedSolomonEncoder{
		field:            field,
		cachedGenerators: []*GenericGFPoly{gen},
	}
}

func (this *ReedSolomonEncoder) buildGenerator(degree int) *GenericGFPoly {
	size := len(this.cachedGenerators)
	if degree >= size {
		lastGenerator := this.cachedGenerators[size-1]
		for d := size; d <= degree; d++ {
			poly, _ := NewGenericGFPoly(
				this.field, []int{1, this.field.Exp(d - 1 + this.field.GetGeneratorBase())})
			nextGenerator, _ := lastGenerator.Multiply(poly)
			this.cachedGenerators = append(this.cachedGenerators, nextGenerator)
			lastGenerator = nextGenerator
		}
	}
	return this.cachedGenerators[degree]
}

func (this *ReedSolomonEncoder) Encode(toEncode []int, ecBytes int) error {
	if ecBytes <= 0 {
		return errors.New("(IllegalArgumentException: No error correction bytes")
	}
	dataBytes := len(toEncode) - ecBytes
	if dataBytes <= 0 {
		return errors.New("IllegalArgumentException: No data bytes provided")
	}
	generator := this.buildGenerator(ecBytes)
	infoCoefficients := make([]int, dataBytes)
	copy(infoCoefficients, toEncode)
	info, _ := NewGenericGFPoly(this.field, infoCoefficients)
	info, _ = info.MultiplyByMonomial(ecBytes, 1)
	_, remainder, e := info.Divide(generator)
	if e != nil {
		return e
	}
	coefficients := remainder.GetCoefficients()
	numZeroCoefficients := ecBytes - len(coefficients)
	for i := 0; i < numZeroCoefficients; i++ {
		toEncode[dataBytes+i] = 0
	}
	copy(toEncode[dataBytes+numZeroCoefficients:], coefficients)
	return nil
}
