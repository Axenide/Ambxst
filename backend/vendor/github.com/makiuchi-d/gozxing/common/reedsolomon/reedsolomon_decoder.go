package reedsolomon

import (
	errors "golang.org/x/xerrors"
)

type ReedSolomonDecoder struct {
	field *GenericGF
}

func NewReedSolomonDecoder(field *GenericGF) *ReedSolomonDecoder {
	return &ReedSolomonDecoder{field}
}

func (this *ReedSolomonDecoder) Decode(received []int, twoS int) ReedSolomonException {
	poly, e := NewGenericGFPoly(this.field, received)
	if e != nil {
		return WrapReedSolomonException(e)
	}
	syndromeCoefficients := make([]int, twoS)
	noError := true
	for i := 0; i < twoS; i++ {
		eval := poly.EvaluateAt(this.field.Exp(i + this.field.GetGeneratorBase()))
		syndromeCoefficients[len(syndromeCoefficients)-1-i] = eval
		if eval != 0 {
			noError = false
		}
	}
	if noError {
		return nil
	}
	syndrome, e := NewGenericGFPoly(this.field, syndromeCoefficients)
	if e != nil {
		return WrapReedSolomonException(e)
	}
	monomial, e := this.field.BuildMonomial(twoS, 1)
	if e != nil {
		return WrapReedSolomonException(e)
	}
	sigma, omega, e := this.runEuclideanAlgorithm(monomial, syndrome, twoS)
	if e != nil {
		return WrapReedSolomonException(e)
	}
	errorLocations, e := this.findErrorLocations(sigma)
	if e != nil {
		return WrapReedSolomonException(e)
	}
	errorMagnitudes, e := this.findErrorMagnitudes(omega, errorLocations)
	if e != nil {
		return WrapReedSolomonException(e)
	}
	for i := 0; i < len(errorLocations); i++ {
		log, e := this.field.Log(errorLocations[i])
		if e != nil {
			return WrapReedSolomonException(e)
		}
		position := len(received) - 1 - log
		if position < 0 {
			return NewReedSolomonException("Bad error location")
		}
		received[position] = GenericGF_addOrSubtract(received[position], errorMagnitudes[i])
	}
	return nil
}

func (this *ReedSolomonDecoder) runEuclideanAlgorithm(a, b *GenericGFPoly, R int) (sigma, omega *GenericGFPoly, e error) {
	// Assume a's degree is >= b's
	if a.GetDegree() < b.GetDegree() {
		a, b = b, a
	}

	rLast := a
	r := b
	tLast := this.field.GetZero()
	t := this.field.GetOne()

	// Run Euclidean algorithm until r's degree is less than R/2
	for 2*r.GetDegree() >= R {
		rLastLast := rLast
		tLastLast := tLast
		rLast = r
		tLast = t

		// Divide rLastLast by rLast, with quotient in q and remainder in r
		if rLast.IsZero() {
			// Oops, Euclidean algorithm already terminated?
			return nil, nil, NewReedSolomonException("r_{i-1} was zero")
		}
		r = rLastLast
		q := this.field.GetZero()
		denominatorLeadingTerm := rLast.GetCoefficient(rLast.GetDegree())
		dltInverse, e := this.field.Inverse(denominatorLeadingTerm)
		if e != nil {
			return nil, nil, e
		}
		for r.GetDegree() >= rLast.GetDegree() && !r.IsZero() {
			degreeDiff := r.GetDegree() - rLast.GetDegree()
			scale := this.field.Multiply(r.GetCoefficient(r.GetDegree()), dltInverse)
			monomial, e := this.field.BuildMonomial(degreeDiff, scale)
			if e != nil {
				return nil, nil, e
			}
			q, e = q.AddOrSubtract(monomial)
			if e != nil {
				return nil, nil, e
			}
			polynomial, e := rLast.MultiplyByMonomial(degreeDiff, scale)
			if e != nil {
				return nil, nil, e
			}
			r, e = r.AddOrSubtract(polynomial)
			if e != nil {
				return nil, nil, e
			}
		}

		q, e = q.Multiply(tLast)
		if e != nil {
			return nil, nil, e
		}
		t, e = q.AddOrSubtract(tLastLast)
		if e != nil {
			return nil, nil, e
		}

		if r.GetDegree() >= rLast.GetDegree() {
			return nil, nil, errors.Errorf(
				"IllegalStateException: Division algorithm failed to reduce polynomial? r: %v, rLast: %v", r, rLast)
		}
	}

	sigmaTildeAtZero := t.GetCoefficient(0)
	if sigmaTildeAtZero == 0 {
		return nil, nil, NewReedSolomonException("sigmaTilde(0) was zero")
	}

	inverse, e := this.field.Inverse(sigmaTildeAtZero)
	if e != nil {
		return nil, nil, e
	}

	return t.MultiplyBy(inverse), r.MultiplyBy(inverse), nil
}

func (this *ReedSolomonDecoder) findErrorLocations(errorLocator *GenericGFPoly) ([]int, error) {
	// This is a direct application of Chien's search
	numErrors := errorLocator.GetDegree()
	if numErrors == 1 { // shortcut
		return []int{errorLocator.GetCoefficient(1)}, nil
	}
	result := make([]int, numErrors)
	e := 0
	for i := 1; i < this.field.GetSize() && e < numErrors; i++ {
		if errorLocator.EvaluateAt(i) == 0 {
			var err error
			result[e], err = this.field.Inverse(i)
			if err != nil {
				return nil, err
			}
			e++
		}
	}
	if e != numErrors {
		return nil, NewReedSolomonException("Error locator degree does not match number of roots")
	}
	return result, nil
}

func (this *ReedSolomonDecoder) findErrorMagnitudes(errorEvaluator *GenericGFPoly, errorLocations []int) ([]int, error) {
	// This is directly applying Forney's Formula
	s := len(errorLocations)
	result := make([]int, s)
	for i := 0; i < s; i++ {
		xiInverse, e := this.field.Inverse(errorLocations[i])
		if e != nil {
			return nil, e
		}
		denominator := 1
		for j := 0; j < s; j++ {
			if i != j {
				//denominator = field.multiply(denominator,
				//    GenericGF.addOrSubtract(1, field.multiply(errorLocations[j], xiInverse)));
				// Above should work but fails on some Apple and Linux JDKs due to a Hotspot bug.
				// Below is a funny-looking workaround from Steven Parkes
				term := this.field.Multiply(errorLocations[j], xiInverse)
				var termPlus1 int
				if (term & 0x1) == 0 {
					termPlus1 = term | 1
				} else {
					termPlus1 = term & ^1
				}
				denominator = this.field.Multiply(denominator, termPlus1)
			}
		}
		inverse, e := this.field.Inverse(denominator)
		if e != nil {
			return nil, e
		}
		result[i] = this.field.Multiply(errorEvaluator.EvaluateAt(xiInverse), inverse)
		if this.field.GetGeneratorBase() != 0 {
			result[i] = this.field.Multiply(result[i], xiInverse)
		}
	}
	return result, nil
}
