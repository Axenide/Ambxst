package reedsolomon

import (
	"fmt"

	errors "golang.org/x/xerrors"
)

type GenericGFPoly struct {
	field        *GenericGF
	coefficients []int
}

func NewGenericGFPoly(field *GenericGF, coefficients []int) (*GenericGFPoly, error) {
	if len(coefficients) == 0 {
		return nil, errors.New("IllegalArgumentException")
	}
	this := &GenericGFPoly{field: field}

	coefficientsLength := len(coefficients)
	if coefficientsLength > 1 && coefficients[0] == 0 {
		// Leading term must be non-zero for anything except the constant polynomial "0"
		firstNonZero := 1
		for firstNonZero < coefficientsLength && coefficients[firstNonZero] == 0 {
			firstNonZero++
		}
		if firstNonZero == coefficientsLength {
			this.coefficients = []int{0}
		} else {
			this.coefficients = coefficients[firstNonZero:]
		}
	} else {
		this.coefficients = coefficients
	}

	return this, nil
}

func (this *GenericGFPoly) GetCoefficients() []int {
	return this.coefficients
}

func (this *GenericGFPoly) GetDegree() int {
	return len(this.coefficients) - 1
}

func (this *GenericGFPoly) IsZero() bool {
	return this.coefficients[0] == 0
}

func (this *GenericGFPoly) GetCoefficient(degree int) int {
	return this.coefficients[len(this.coefficients)-1-degree]
}

func (this *GenericGFPoly) EvaluateAt(a int) int {
	if a == 0 {
		// Just return the x^0 coefficient
		return this.GetCoefficient(0)
	}
	if a == 1 {
		// Just the sum of the coefficients
		result := 0
		for _, coefficient := range this.coefficients {
			result = GenericGF_addOrSubtract(result, coefficient)
		}
		return result
	}
	result := this.coefficients[0]
	size := len(this.coefficients)
	for i := 1; i < size; i++ {
		result = GenericGF_addOrSubtract(this.field.Multiply(a, result), this.coefficients[i])
	}
	return result
}

func (this *GenericGFPoly) AddOrSubtract(other *GenericGFPoly) (*GenericGFPoly, error) {
	if this.field != other.field {
		return nil, errors.New("IllegalArgumentException: GenericGFPolys do not have same GenericGF field")
	}
	if this.IsZero() {
		return other, nil
	}
	if other.IsZero() {
		return this, nil
	}

	smallerCoefficients := this.coefficients
	largerCoefficients := other.coefficients
	if len(smallerCoefficients) > len(largerCoefficients) {
		smallerCoefficients, largerCoefficients = largerCoefficients, smallerCoefficients
	}
	sumDiff := make([]int, len(largerCoefficients))
	lengthDiff := len(largerCoefficients) - len(smallerCoefficients)
	// Copy high-order terms only found in higher-degree polynomial's coefficients
	copy(sumDiff, largerCoefficients[:lengthDiff])
	for i := lengthDiff; i < len(largerCoefficients); i++ {
		sumDiff[i] = GenericGF_addOrSubtract(smallerCoefficients[i-lengthDiff], largerCoefficients[i])
	}

	return NewGenericGFPoly(this.field, sumDiff)
}

func (this *GenericGFPoly) Multiply(other *GenericGFPoly) (*GenericGFPoly, error) {
	if this.field != other.field {
		return nil, errors.New("IllegalArgumentException: GenericGFPolys do not have same GenericGF field")
	}
	if this.IsZero() || other.IsZero() {
		return this.field.GetZero(), nil
	}
	aCoefficients := this.coefficients
	aLength := len(aCoefficients)
	bCoefficients := other.coefficients
	bLength := len(bCoefficients)
	product := make([]int, aLength+bLength-1)
	for i := 0; i < aLength; i++ {
		aCoeff := aCoefficients[i]
		for j := 0; j < bLength; j++ {
			product[i+j] = GenericGF_addOrSubtract(product[i+j],
				this.field.Multiply(aCoeff, bCoefficients[j]))
		}
	}
	return NewGenericGFPoly(this.field, product)
}

func (this *GenericGFPoly) MultiplyBy(scalar int) *GenericGFPoly {
	if scalar == 0 {
		return this.field.GetZero()
	}
	if scalar == 1 {
		return this
	}
	size := len(this.coefficients)
	product := make([]int, size)
	for i := 0; i < size; i++ {
		product[i] = this.field.Multiply(this.coefficients[i], scalar)
	}
	ret, _ := NewGenericGFPoly(this.field, product)
	return ret
}

func (this *GenericGFPoly) MultiplyByMonomial(degree, coefficient int) (*GenericGFPoly, error) {
	if degree < 0 {
		return nil, errors.New("IllegalArgumentException")
	}
	if coefficient == 0 {
		return this.field.GetZero(), nil
	}
	size := len(this.coefficients)
	product := make([]int, size+degree)
	for i := 0; i < size; i++ {
		product[i] = this.field.Multiply(this.coefficients[i], coefficient)
	}
	return NewGenericGFPoly(this.field, product)
}

func (this *GenericGFPoly) Divide(other *GenericGFPoly) (quotient, remainder *GenericGFPoly, e error) {
	if this.field != other.field {
		return nil, nil, errors.New("IllegalArgumentException: GenericGFPolys do not have same GenericGF field")
	}
	if other.IsZero() {
		return nil, nil, errors.New("IllegalArgumentException: Divide by 0")
	}

	quotient = this.field.GetZero()
	remainder = this

	denominatorLeadingTerm := other.GetCoefficient(other.GetDegree())
	inverseDenominatorLeadingTerm, e := this.field.Inverse(denominatorLeadingTerm)
	if e != nil {
		return nil, nil, e
	}

	for remainder.GetDegree() >= other.GetDegree() && !remainder.IsZero() {
		degreeDifference := remainder.GetDegree() - other.GetDegree()
		scale := this.field.Multiply(remainder.GetCoefficient(remainder.GetDegree()), inverseDenominatorLeadingTerm)

		term, e := other.MultiplyByMonomial(degreeDifference, scale)
		if e != nil {
			return nil, nil, e
		}
		iterationQuotient, e := this.field.BuildMonomial(degreeDifference, scale)
		if e != nil {
			return nil, nil, e
		}
		quotient, e = quotient.AddOrSubtract(iterationQuotient)
		if e != nil {
			return nil, nil, e
		}
		remainder, e = remainder.AddOrSubtract(term)
		if e != nil {
			return nil, nil, e
		}
	}

	return quotient, remainder, nil
}

func (this *GenericGFPoly) String() string {
	if this.IsZero() {
		return "0"
	}
	result := make([]byte, 0, 8*this.GetDegree())
	for degree := this.GetDegree(); degree >= 0; degree-- {
		coefficient := this.GetCoefficient(degree)
		if coefficient != 0 {
			if coefficient < 0 {
				if degree == this.GetDegree() {
					result = append(result, '-')
				} else {
					result = append(result, []byte(" - ")...)
				}
				coefficient = -coefficient
			} else {
				if len(result) > 0 {
					result = append(result, []byte(" + ")...)
				}
			}
			if degree == 0 || coefficient != 1 {
				alphaPower, _ := this.field.Log(coefficient)
				if alphaPower == 0 {
					result = append(result, byte('1'))
				} else if alphaPower == 1 {
					result = append(result, byte('a'))
				} else {
					result = append(result, []byte(fmt.Sprintf("a^%d", alphaPower))...)
				}
			}
			if degree != 0 {
				if degree == 1 {
					result = append(result, byte('x'))
				} else {
					result = append(result, []byte(fmt.Sprintf("x^%d", degree))...)
				}
			}
		}
	}
	return string(result)
}
