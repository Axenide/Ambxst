package detector

import (
	"github.com/makiuchi-d/gozxing"
	"github.com/makiuchi-d/gozxing/common"
	cdetector "github.com/makiuchi-d/gozxing/common/detector"
)

type Detector struct {
	image             *gozxing.BitMatrix
	rectangleDetector *cdetector.WhiteRectangleDetector
}

func NewDetector(image *gozxing.BitMatrix) (*Detector, error) {
	rectangleDetector, e := cdetector.NewWhiteRectangleDetectorFromImage(image)
	if e != nil {
		return nil, e
	}
	return &Detector{image, rectangleDetector}, nil
}

// Detect Detects a Data Matrix Code in an image.
//
// @return {@link DetectorResult} encapsulating results of detecting a Data Matrix Code
// @throws NotFoundException if no Data Matrix Code can be found
//
func (this *Detector) Detect() (*common.DetectorResult, error) {

	cornerPoints, e := this.rectangleDetector.Detect()
	if e != nil {
		return nil, e
	}

	points := this.detectSolid1(cornerPoints)
	points = this.detectSolid2(points)
	points[3] = this.correctTopRight(points)
	if points[3] == nil {
		return nil, gozxing.NewNotFoundException("incorrect top-right, %v", points)
	}
	points = this.shiftToModuleCenter(points)

	topLeft := points[0]
	bottomLeft := points[1]
	bottomRight := points[2]
	topRight := points[3]

	dimensionTop := this.transitionsBetween(topLeft, topRight) + 1
	dimensionRight := this.transitionsBetween(bottomRight, topRight) + 1
	if (dimensionTop & 0x01) == 1 {
		dimensionTop += 1
	}
	if (dimensionRight & 0x01) == 1 {
		dimensionRight += 1
	}

	if 4*dimensionTop < 6*dimensionRight && 4*dimensionRight < 6*dimensionTop {
		// The matrix is square
		dimensionTop = max(dimensionTop, dimensionRight)
		dimensionRight = dimensionTop
	}

	bits, e := sampleGrid(
		this.image,
		topLeft,
		bottomLeft,
		bottomRight,
		topRight,
		dimensionTop,
		dimensionRight)
	if e != nil {
		return nil, e
	}

	return common.NewDetectorResult(bits, []gozxing.ResultPoint{topLeft, bottomLeft, bottomRight, topRight}), nil
}

func shiftPoint(point, to gozxing.ResultPoint, div int) gozxing.ResultPoint {
	x := (to.GetX() - point.GetX()) / float64(div+1)
	y := (to.GetY() - point.GetY()) / float64(div+1)
	return gozxing.NewResultPoint(point.GetX()+x, point.GetY()+y)
}

func moveAway(point gozxing.ResultPoint, fromX, fromY float64) gozxing.ResultPoint {
	x := point.GetX()
	y := point.GetY()

	if x < fromX {
		x -= 1
	} else {
		x += 1
	}

	if y < fromY {
		y -= 1
	} else {
		y += 1
	}

	return gozxing.NewResultPoint(x, y)
}

// detectSolid1 Detect a solid side which has minimum transition.
func (this *Detector) detectSolid1(cornerPoints []gozxing.ResultPoint) []gozxing.ResultPoint {
	// 0  2
	// 1  3
	pointA := cornerPoints[0]
	pointB := cornerPoints[1]
	pointC := cornerPoints[3]
	pointD := cornerPoints[2]

	trAB := this.transitionsBetween(pointA, pointB)
	trBC := this.transitionsBetween(pointB, pointC)
	trCD := this.transitionsBetween(pointC, pointD)
	trDA := this.transitionsBetween(pointD, pointA)

	// 0..3
	// :  :
	// 1--2
	min := trAB
	points := []gozxing.ResultPoint{pointD, pointA, pointB, pointC}
	if min > trBC {
		min = trBC
		points[0] = pointA
		points[1] = pointB
		points[2] = pointC
		points[3] = pointD
	}
	if min > trCD {
		min = trCD
		points[0] = pointB
		points[1] = pointC
		points[2] = pointD
		points[3] = pointA
	}
	if min > trDA {
		points[0] = pointC
		points[1] = pointD
		points[2] = pointA
		points[3] = pointB
	}

	return points
}

// detectSolid2 Detect a second solid side next to first solid side.
func (this *Detector) detectSolid2(points []gozxing.ResultPoint) []gozxing.ResultPoint {
	// A..D
	// :  :
	// B--C
	pointA := points[0]
	pointB := points[1]
	pointC := points[2]
	pointD := points[3]

	// Transition detection on the edge is not stable.
	// To safely detect, shift the points to the module center.
	tr := this.transitionsBetween(pointA, pointD)
	pointBs := shiftPoint(pointB, pointC, (tr+1)*4)
	pointCs := shiftPoint(pointC, pointB, (tr+1)*4)
	trBA := this.transitionsBetween(pointBs, pointA)
	trCD := this.transitionsBetween(pointCs, pointD)

	// 0..3
	// |  :
	// 1--2
	if trBA < trCD {
		// solid sides: A-B-C
		points[0] = pointA
		points[1] = pointB
		points[2] = pointC
		points[3] = pointD
	} else {
		// solid sides: B-C-D
		points[0] = pointB
		points[1] = pointC
		points[2] = pointD
		points[3] = pointA
	}

	return points
}

// correctTopRight Calculates the corner position of the white top right module.
func (this *Detector) correctTopRight(points []gozxing.ResultPoint) gozxing.ResultPoint {
	// A..D
	// |  :
	// B--C
	pointA := points[0]
	pointB := points[1]
	pointC := points[2]
	pointD := points[3]

	// shift points for safe transition detection.
	trTop := this.transitionsBetween(pointA, pointD)
	trRight := this.transitionsBetween(pointB, pointD)
	pointAs := shiftPoint(pointA, pointB, (trRight+1)*4)
	pointCs := shiftPoint(pointC, pointB, (trTop+1)*4)

	trTop = this.transitionsBetween(pointAs, pointD)
	trRight = this.transitionsBetween(pointCs, pointD)

	candidate1 := gozxing.NewResultPoint(
		pointD.GetX()+(pointC.GetX()-pointB.GetX())/float64(trTop+1),
		pointD.GetY()+(pointC.GetY()-pointB.GetY())/float64(trTop+1))
	candidate2 := gozxing.NewResultPoint(
		pointD.GetX()+(pointA.GetX()-pointB.GetX())/float64(trRight+1),
		pointD.GetY()+(pointA.GetY()-pointB.GetY())/float64(trRight+1))

	if !this.isValid(candidate1) {
		if this.isValid(candidate2) {
			return candidate2
		}
		return nil
	}
	if !this.isValid(candidate2) {
		return candidate1
	}

	sumc1 := this.transitionsBetween(pointAs, candidate1) + this.transitionsBetween(pointCs, candidate1)
	sumc2 := this.transitionsBetween(pointAs, candidate2) + this.transitionsBetween(pointCs, candidate2)

	if sumc1 > sumc2 {
		return candidate1
	} else {
		return candidate2
	}
}

// shiftToModuleCenter Shift the edge points to the module center.
func (this *Detector) shiftToModuleCenter(points []gozxing.ResultPoint) []gozxing.ResultPoint {
	// A..D
	// |  :
	// B--C
	pointA := points[0]
	pointB := points[1]
	pointC := points[2]
	pointD := points[3]

	// calculate pseudo dimensions
	dimH := this.transitionsBetween(pointA, pointD) + 1
	dimV := this.transitionsBetween(pointC, pointD) + 1

	// shift points for safe dimension detection
	pointAs := shiftPoint(pointA, pointB, dimV*4)
	pointCs := shiftPoint(pointC, pointB, dimH*4)

	//  calculate more precise dimensions
	dimH = this.transitionsBetween(pointAs, pointD) + 1
	dimV = this.transitionsBetween(pointCs, pointD) + 1
	if (dimH & 0x01) == 1 {
		dimH += 1
	}
	if (dimV & 0x01) == 1 {
		dimV += 1
	}

	// WhiteRectangleDetector returns points inside of the rectangle.
	// I want points on the edges.
	centerX := (pointA.GetX() + pointB.GetX() + pointC.GetX() + pointD.GetX()) / 4
	centerY := (pointA.GetY() + pointB.GetY() + pointC.GetY() + pointD.GetY()) / 4
	pointA = moveAway(pointA, centerX, centerY)
	pointB = moveAway(pointB, centerX, centerY)
	pointC = moveAway(pointC, centerX, centerY)
	pointD = moveAway(pointD, centerX, centerY)

	var pointBs gozxing.ResultPoint
	var pointDs gozxing.ResultPoint

	// shift points to the center of each modules
	pointAs = shiftPoint(pointA, pointB, dimV*4)
	pointAs = shiftPoint(pointAs, pointD, dimH*4)
	pointBs = shiftPoint(pointB, pointA, dimV*4)
	pointBs = shiftPoint(pointBs, pointC, dimH*4)
	pointCs = shiftPoint(pointC, pointD, dimV*4)
	pointCs = shiftPoint(pointCs, pointB, dimH*4)
	pointDs = shiftPoint(pointD, pointC, dimV*4)
	pointDs = shiftPoint(pointDs, pointA, dimH*4)

	return []gozxing.ResultPoint{pointAs, pointBs, pointCs, pointDs}
}

func (this *Detector) isValid(p gozxing.ResultPoint) bool {
	return p.GetX() >= 0 && p.GetX() < float64(this.image.GetWidth()) &&
		p.GetY() > 0 && p.GetY() < float64(this.image.GetHeight())
}

func sampleGrid(image *gozxing.BitMatrix,
	topLeft, bottomLeft, bottomRight, topRight gozxing.ResultPoint,
	dimensionX, dimensionY int) (*gozxing.BitMatrix, error) {

	sampler := common.GridSampler_GetInstance()

	return sampler.SampleGrid(
		image,
		dimensionX,
		dimensionY,
		0.5,
		0.5,
		float64(dimensionX)-0.5,
		0.5,
		float64(dimensionX)-0.5,
		float64(dimensionY)-0.5,
		0.5,
		float64(dimensionY)-0.5,
		topLeft.GetX(),
		topLeft.GetY(),
		topRight.GetX(),
		topRight.GetY(),
		bottomRight.GetX(),
		bottomRight.GetY(),
		bottomLeft.GetX(),
		bottomLeft.GetY())
}

// transitionsBetween Counts the number of black/white transitions between two points,
// using something like Bresenham's algorithm.
func (this *Detector) transitionsBetween(from, to gozxing.ResultPoint) int {
	// See QR Code Detector, sizeOfBlackWhiteBlackRun()
	fromX := int(from.GetX())
	fromY := int(from.GetY())
	toX := int(to.GetX())
	toY := min(this.image.GetHeight()-1, int(to.GetY()))

	steep := abs(toY-fromY) > abs(toX-fromX)
	if steep {
		fromX, fromY = fromY, fromX
		toX, toY = toY, toX
	}

	dx := abs(toX - fromX)
	dy := abs(toY - fromY)
	error := -dx / 2
	ystep := 1
	if !(fromY < toY) {
		ystep = -1
	}
	xstep := 1
	if !(fromX < toX) {
		xstep = -1
	}
	transitions := 0
	var inBlack bool
	if steep {
		inBlack = this.image.Get(fromY, fromX)
	} else {
		inBlack = this.image.Get(fromX, fromY)
	}
	for x, y := fromX, fromY; x != toX; x += xstep {
		var isBlack bool
		if steep {
			isBlack = this.image.Get(y, x)
		} else {
			isBlack = this.image.Get(x, y)
		}
		if isBlack != inBlack {
			transitions++
			inBlack = isBlack
		}
		error += dy
		if error > 0 {
			if y == toY {
				break
			}
			y += ystep
			error -= dx
		}
	}
	return transitions
}

func abs(a int) int {
	if a < 0 {
		return -a
	}
	return a
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
