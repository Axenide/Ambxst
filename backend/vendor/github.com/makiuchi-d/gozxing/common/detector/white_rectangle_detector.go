package detector

import (
	"github.com/makiuchi-d/gozxing"
	"github.com/makiuchi-d/gozxing/common/util"
)

const (
	whiteRectangleDetector_INIT_SIZE = 10
	whiteRectangleDetector_CORR      = 1
)

// WhiteRectangleDetector Detects a candidate barcode-like rectangular region within an image.
// It starts around the center of the image, increases the size of the candidate
// region until it finds a white rectangular region. By keeping track of the
// last black points it encountered, it determines the corners of the barcode.
type WhiteRectangleDetector struct {
	image     *gozxing.BitMatrix
	height    int
	width     int
	leftInit  int
	rightInit int
	downInit  int
	upInit    int
}

func NewWhiteRectangleDetectorFromImage(image *gozxing.BitMatrix) (*WhiteRectangleDetector, error) {
	return NewWhiteRectangleDetector(
		image, whiteRectangleDetector_INIT_SIZE, image.GetWidth()/2, image.GetHeight()/2)
}

// NewWhiteRectangleDetector new WhiteRectangleDetector
// @param image barcode image to find a rectangle in
// @param initSize initial size of search area around center
// @param x x position of search center
// @param y y position of search center
// @throws NotFoundException if image is too small to accommodate {@code initSize}
func NewWhiteRectangleDetector(image *gozxing.BitMatrix, initSize, x, y int) (*WhiteRectangleDetector, error) {
	halfsize := initSize / 2
	d := &WhiteRectangleDetector{
		image:     image,
		height:    image.GetHeight(),
		width:     image.GetWidth(),
		leftInit:  x - halfsize,
		rightInit: x + halfsize,
		upInit:    y - halfsize,
		downInit:  y + halfsize,
	}
	if d.upInit < 0 || d.leftInit < 0 || d.downInit >= d.height || d.rightInit >= d.width {
		return nil, gozxing.NewNotFoundException()
	}
	return d, nil
}

// Detect Detects a candidate barcode-like rectangular region within an image.
// It starts around the center of the image, increases the size of the candidate
// region until it finds a white rectangular region.
//
// @return {@link ResultPoint}[] describing the corners of the rectangular
//         region. The first and last points are opposed on the diagonal, as
//         are the second and third. The first point will be the topmost
//         point and the last, the bottommost. The second point will be
//         leftmost and the third, the rightmost
// @throws NotFoundException if no Data Matrix Code can be found
//
func (this *WhiteRectangleDetector) Detect() ([]gozxing.ResultPoint, error) {
	left := this.leftInit
	right := this.rightInit
	up := this.upInit
	down := this.downInit
	sizeExceeded := false
	aBlackPointFoundOnBorder := true

	atLeastOneBlackPointFoundOnRight := false
	atLeastOneBlackPointFoundOnBottom := false
	atLeastOneBlackPointFoundOnLeft := false
	atLeastOneBlackPointFoundOnTop := false

	for aBlackPointFoundOnBorder {

		aBlackPointFoundOnBorder = false

		// .....
		// .   |
		// .....
		rightBorderNotWhite := true
		for (rightBorderNotWhite || !atLeastOneBlackPointFoundOnRight) && right < this.width {
			rightBorderNotWhite = this.containsBlackPoint(up, down, right, false)
			if rightBorderNotWhite {
				right++
				aBlackPointFoundOnBorder = true
				atLeastOneBlackPointFoundOnRight = true
			} else if !atLeastOneBlackPointFoundOnRight {
				right++
			}
		}

		if right >= this.width {
			sizeExceeded = true
			break
		}

		// .....
		// .   .
		// .___.
		bottomBorderNotWhite := true
		for (bottomBorderNotWhite || !atLeastOneBlackPointFoundOnBottom) && down < this.height {
			bottomBorderNotWhite = this.containsBlackPoint(left, right, down, true)
			if bottomBorderNotWhite {
				down++
				aBlackPointFoundOnBorder = true
				atLeastOneBlackPointFoundOnBottom = true
			} else if !atLeastOneBlackPointFoundOnBottom {
				down++
			}
		}

		if down >= this.height {
			sizeExceeded = true
			break
		}

		// .....
		// |   .
		// .....
		leftBorderNotWhite := true
		for (leftBorderNotWhite || !atLeastOneBlackPointFoundOnLeft) && left >= 0 {
			leftBorderNotWhite = this.containsBlackPoint(up, down, left, false)
			if leftBorderNotWhite {
				left--
				aBlackPointFoundOnBorder = true
				atLeastOneBlackPointFoundOnLeft = true
			} else if !atLeastOneBlackPointFoundOnLeft {
				left--
			}
		}

		if left < 0 {
			sizeExceeded = true
			break
		}

		// .___.
		// .   .
		// .....
		topBorderNotWhite := true
		for (topBorderNotWhite || !atLeastOneBlackPointFoundOnTop) && up >= 0 {
			topBorderNotWhite = this.containsBlackPoint(left, right, up, true)
			if topBorderNotWhite {
				up--
				aBlackPointFoundOnBorder = true
				atLeastOneBlackPointFoundOnTop = true
			} else if !atLeastOneBlackPointFoundOnTop {
				up--
			}
		}

		if up < 0 {
			sizeExceeded = true
			break
		}

	}

	if !sizeExceeded {

		maxSize := right - left

		var z gozxing.ResultPoint
		for i := 1; z == nil && i < maxSize; i++ {
			z = this.getBlackPointOnSegment(left, down-i, left+i, down)
		}

		if z == nil {
			return nil, gozxing.NewNotFoundException("no black point on left-down")
		}

		var t gozxing.ResultPoint
		//go down right
		for i := 1; t == nil && i < maxSize; i++ {
			t = this.getBlackPointOnSegment(left, up+i, left+i, up)
		}

		if t == nil {
			return nil, gozxing.NewNotFoundException("no black point on left-up")
		}

		var x gozxing.ResultPoint
		//go down left
		for i := 1; x == nil && i < maxSize; i++ {
			x = this.getBlackPointOnSegment(right, up+i, right-i, up)
		}

		if x == nil {
			return nil, gozxing.NewNotFoundException("no black point on right-up")
		}

		var y gozxing.ResultPoint
		//go up left
		for i := 1; y == nil && i < maxSize; i++ {
			y = this.getBlackPointOnSegment(right, down-i, right-i, down)
		}

		if y == nil {
			return nil, gozxing.NewNotFoundException("no black point on right-down")
		}

		return this.centerEdges(y, z, x, t), nil
	}

	return nil, gozxing.NewNotFoundException()
}

func (this *WhiteRectangleDetector) getBlackPointOnSegment(aX, aY, bX, bY int) gozxing.ResultPoint {
	dist := util.MathUtils_Round(util.MathUtils_DistanceInt(aX, aY, bX, bY))
	xStep := float64(bX-aX) / float64(dist)
	yStep := float64(bY-aY) / float64(dist)

	for i := 0; i < dist; i++ {
		x := util.MathUtils_Round(float64(aX) + float64(i)*xStep)
		y := util.MathUtils_Round(float64(aY) + float64(i)*yStep)
		if this.image.Get(x, y) {
			return gozxing.NewResultPoint(float64(x), float64(y))
		}
	}
	return nil
}

// centerEdges recenters the points of a constant distance towards the center
//
// @param y bottom most point
// @param z left most point
// @param x right most point
// @param t top most point
// @return {@link ResultPoint}[] describing the corners of the rectangular
//         region. The first and last points are opposed on the diagonal, as
//         are the second and third. The first point will be the topmost
//         point and the last, the bottommost. The second point will be
//         leftmost and the third, the rightmost
//
func (this *WhiteRectangleDetector) centerEdges(y, z, x, t gozxing.ResultPoint) []gozxing.ResultPoint {

	//
	//       t            t
	//  z                      x
	//        x    OR    z
	//   y                    y
	//

	yi := y.GetX()
	yj := y.GetY()
	zi := z.GetX()
	zj := z.GetY()
	xi := x.GetX()
	xj := x.GetY()
	ti := t.GetX()
	tj := t.GetY()

	if yi < float64(this.width)/2.0 {
		return []gozxing.ResultPoint{
			gozxing.NewResultPoint(ti-whiteRectangleDetector_CORR, tj+whiteRectangleDetector_CORR),
			gozxing.NewResultPoint(zi+whiteRectangleDetector_CORR, zj+whiteRectangleDetector_CORR),
			gozxing.NewResultPoint(xi-whiteRectangleDetector_CORR, xj-whiteRectangleDetector_CORR),
			gozxing.NewResultPoint(yi+whiteRectangleDetector_CORR, yj-whiteRectangleDetector_CORR),
		}
	} else {
		return []gozxing.ResultPoint{
			gozxing.NewResultPoint(ti+whiteRectangleDetector_CORR, tj+whiteRectangleDetector_CORR),
			gozxing.NewResultPoint(zi+whiteRectangleDetector_CORR, zj-whiteRectangleDetector_CORR),
			gozxing.NewResultPoint(xi-whiteRectangleDetector_CORR, xj+whiteRectangleDetector_CORR),
			gozxing.NewResultPoint(yi-whiteRectangleDetector_CORR, yj-whiteRectangleDetector_CORR),
		}
	}
}

// containsBlackPoint Determines whether a segment contains a black point
//
// @param a          min value of the scanned coordinate
// @param b          max value of the scanned coordinate
// @param fixed      value of fixed coordinate
// @param horizontal set to true if scan must be horizontal, false if vertical
// @return true if a black point has been found, else false.
//
func (this *WhiteRectangleDetector) containsBlackPoint(a, b, fixed int, horizontal bool) bool {

	if horizontal {
		for x := a; x <= b; x++ {
			if this.image.Get(x, fixed) {
				return true
			}
		}
	} else {
		for y := a; y <= b; y++ {
			if this.image.Get(fixed, y) {
				return true
			}
		}
	}

	return false
}
