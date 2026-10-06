package common

type PerspectiveTransform struct {
	a11, a21, a31 float64
	a12, a22, a32 float64
	a13, a23, a33 float64
}

func PerspectiveTransform_QuadrilateralToQuadrilateral(x0, y0, x1, y1, x2, y2, x3, y3,
	x0p, y0p, x1p, y1p, x2p, y2p, x3p, y3p float64) *PerspectiveTransform {

	qToS := PerspectiveTransform_QuadrilateralToSquare(x0, y0, x1, y1, x2, y2, x3, y3)
	sToQ := PerspectiveTransform_SquareToQuadrilateral(x0p, y0p, x1p, y1p, x2p, y2p, x3p, y3p)
	return sToQ.times(qToS)
}

func (p *PerspectiveTransform) TransformPoints(points []float64) {
	maxI := len(points) - 1 // points.length must be even
	for i := 0; i < maxI; i += 2 {
		x := points[i]
		y := points[i+1]
		denominator := p.a13*x + p.a23*y + p.a33
		points[i] = (p.a11*x + p.a21*y + p.a31) / denominator
		points[i+1] = (p.a12*x + p.a22*y + p.a32) / denominator
	}
}

func (p *PerspectiveTransform) TransformPointsXY(xValues, yValues []float64) {
	n := len(xValues)
	for i := 0; i < n; i++ {
		x := xValues[i]
		y := yValues[i]
		denominator := p.a13*x + p.a23*y + p.a33
		xValues[i] = (p.a11*x + p.a21*y + p.a31) / denominator
		yValues[i] = (p.a12*x + p.a22*y + p.a32) / denominator
	}
}

func PerspectiveTransform_SquareToQuadrilateral(x0, y0, x1, y1, x2, y2, x3, y3 float64) *PerspectiveTransform {
	dx3 := x0 - x1 + x2 - x3
	dy3 := y0 - y1 + y2 - y3
	if dx3 == 0.0 && dy3 == 0.0 {
		// Affine
		return &PerspectiveTransform{
			x1 - x0, x2 - x1, x0,
			y1 - y0, y2 - y1, y0,
			0.0, 0.0, 1.0}
	} else {
		dx1 := x1 - x2
		dx2 := x3 - x2
		dy1 := y1 - y2
		dy2 := y3 - y2
		denominator := dx1*dy2 - dx2*dy1
		a13 := (dx3*dy2 - dx2*dy3) / denominator
		a23 := (dx1*dy3 - dx3*dy1) / denominator
		return &PerspectiveTransform{
			x1 - x0 + a13*x1, x3 - x0 + a23*x3, x0,
			y1 - y0 + a13*y1, y3 - y0 + a23*y3, y0,
			a13, a23, 1.0}
	}
}

func PerspectiveTransform_QuadrilateralToSquare(x0, y0, x1, y1, x2, y2, x3, y3 float64) *PerspectiveTransform {
	// Here, the adjoint serves as the inverse:
	return PerspectiveTransform_SquareToQuadrilateral(x0, y0, x1, y1, x2, y2, x3, y3).buildAdjoint()
}

func (p *PerspectiveTransform) buildAdjoint() *PerspectiveTransform {
	// Adjoint is the transpose of the cofactor matrix:
	return &PerspectiveTransform{
		p.a22*p.a33 - p.a23*p.a32,
		p.a23*p.a31 - p.a21*p.a33,
		p.a21*p.a32 - p.a22*p.a31,
		p.a13*p.a32 - p.a12*p.a33,
		p.a11*p.a33 - p.a13*p.a31,
		p.a12*p.a31 - p.a11*p.a32,
		p.a12*p.a23 - p.a13*p.a22,
		p.a13*p.a21 - p.a11*p.a23,
		p.a11*p.a22 - p.a12*p.a21,
	}
}

func (p *PerspectiveTransform) times(other *PerspectiveTransform) *PerspectiveTransform {
	return &PerspectiveTransform{
		p.a11*other.a11 + p.a21*other.a12 + p.a31*other.a13,
		p.a11*other.a21 + p.a21*other.a22 + p.a31*other.a23,
		p.a11*other.a31 + p.a21*other.a32 + p.a31*other.a33,
		p.a12*other.a11 + p.a22*other.a12 + p.a32*other.a13,
		p.a12*other.a21 + p.a22*other.a22 + p.a32*other.a23,
		p.a12*other.a31 + p.a22*other.a32 + p.a32*other.a33,
		p.a13*other.a11 + p.a23*other.a12 + p.a33*other.a13,
		p.a13*other.a21 + p.a23*other.a22 + p.a33*other.a23,
		p.a13*other.a31 + p.a23*other.a32 + p.a33*other.a33,
	}
}
