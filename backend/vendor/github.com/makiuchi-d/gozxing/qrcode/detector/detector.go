package detector

import (
	"math"

	"github.com/makiuchi-d/gozxing"
	"github.com/makiuchi-d/gozxing/common"
	"github.com/makiuchi-d/gozxing/common/util"
	"github.com/makiuchi-d/gozxing/qrcode/decoder"
)

type Detector struct {
	image               *gozxing.BitMatrix
	resultPointCallback gozxing.ResultPointCallback
}

func NewDetector(image *gozxing.BitMatrix) *Detector {
	return &Detector{image, nil}
}

func (this *Detector) GetImage() *gozxing.BitMatrix {
	return this.image
}

func (this *Detector) GetResultPointCallback() gozxing.ResultPointCallback {
	return this.resultPointCallback
}

func (this *Detector) DetectWithoutHints() (*common.DetectorResult, error) {
	return this.Detect(nil)
}

func (this *Detector) Detect(hints map[gozxing.DecodeHintType]interface{}) (*common.DetectorResult, error) {
	if hints != nil {
		if cb, ok := hints[gozxing.DecodeHintType_NEED_RESULT_POINT_CALLBACK]; ok {
			this.resultPointCallback, _ = cb.(gozxing.ResultPointCallback)
		}
	}

	finder := NewFinderPatternFinder(this.image, this.resultPointCallback)
	info, e := finder.Find(hints)
	if e != nil {
		return nil, e
	}

	return this.ProcessFinderPatternInfo(info)
}

func (this *Detector) ProcessFinderPatternInfo(info *FinderPatternInfo) (*common.DetectorResult, error) {
	topLeft := info.GetTopLeft()
	topRight := info.GetTopRight()
	bottomLeft := info.GetBottomLeft()

	moduleSize := this.calculateModuleSize(topLeft, topRight, bottomLeft)
	if moduleSize < 1.0 {
		return nil, gozxing.NewNotFoundException("moduleSize = %v", moduleSize)
	}
	dimension, e := this.computeDimension(topLeft, topRight, bottomLeft, moduleSize)
	if e != nil {
		return nil, e
	}
	provisionalVersion, e := decoder.Version_GetProvisionalVersionForDimension(dimension)
	if e != nil {
		return nil, gozxing.WrapFormatException(e)
	}
	modulesBetweenFPCenters := provisionalVersion.GetDimensionForVersion() - 7

	var alignmentPattern *AlignmentPattern
	// Anything above version 1 has an alignment pattern
	if len(provisionalVersion.GetAlignmentPatternCenters()) > 0 {
		// Guess where a "bottom right" finder pattern would have been
		bottomRightX := topRight.GetX() - topLeft.GetX() + bottomLeft.GetX()
		bottomRightY := topRight.GetY() - topLeft.GetY() + bottomLeft.GetY()

		// Estimate that alignment pattern is closer by 3 modules
		// from "bottom right" to known top left location
		correctionToTopLeft := 1.0 - 3.0/float64(modulesBetweenFPCenters)
		estAlignmentX := int(topLeft.GetX() + correctionToTopLeft*(bottomRightX-topLeft.GetX()))
		estAlignmentY := int(topLeft.GetY() + correctionToTopLeft*(bottomRightY-topLeft.GetY()))

		// Kind of arbitrary -- expand search radius before giving up
		for i := 4; i <= 16; i <<= 1 {
			alignmentPattern, e = this.findAlignmentInRegion(moduleSize,
				estAlignmentX,
				estAlignmentY,
				float64(i))
			if e == nil {
				break
			} else if _, ok := e.(gozxing.NotFoundException); !ok {
				return nil, e
			}
		}
		// If we didn't find alignment pattern... well try anyway without it
	}

	transform := Detector_createTransform(topLeft, topRight, bottomLeft, alignmentPattern, dimension)

	bits, e := Detector_sampleGrid(this.image, transform, dimension)
	if e != nil {
		return nil, gozxing.WrapNotFoundException(e)
	}

	var points []gozxing.ResultPoint
	if alignmentPattern == nil {
		points = []gozxing.ResultPoint{bottomLeft, topLeft, topRight}
	} else {
		points = []gozxing.ResultPoint{bottomLeft, topLeft, topRight, alignmentPattern}
	}
	return common.NewDetectorResult(bits, points), nil
}

func Detector_createTransform(topLeft, topRight, bottomLeft gozxing.ResultPoint, alignmentPattern *AlignmentPattern, dimension int) *common.PerspectiveTransform {
	dimMinusThree := float64(dimension) - 3.5
	var bottomRightX float64
	var bottomRightY float64
	var sourceBottomRightX float64
	var sourceBottomRightY float64
	if alignmentPattern != nil {
		bottomRightX = alignmentPattern.GetX()
		bottomRightY = alignmentPattern.GetY()
		sourceBottomRightX = dimMinusThree - 3.0
		sourceBottomRightY = sourceBottomRightX
	} else {
		// Don't have an alignment pattern, just make up the bottom-right point
		bottomRightX = (topRight.GetX() - topLeft.GetX()) + bottomLeft.GetX()
		bottomRightY = (topRight.GetY() - topLeft.GetY()) + bottomLeft.GetY()
		sourceBottomRightX = dimMinusThree
		sourceBottomRightY = dimMinusThree
	}

	return common.PerspectiveTransform_QuadrilateralToQuadrilateral(
		3.5,
		3.5,
		dimMinusThree,
		3.5,
		sourceBottomRightX,
		sourceBottomRightY,
		3.5,
		dimMinusThree,
		topLeft.GetX(),
		topLeft.GetY(),
		topRight.GetX(),
		topRight.GetY(),
		bottomRightX,
		bottomRightY,
		bottomLeft.GetX(),
		bottomLeft.GetY())
}

func Detector_sampleGrid(image *gozxing.BitMatrix, transform *common.PerspectiveTransform, dimension int) (*gozxing.BitMatrix, error) {
	sampler := common.GridSampler_GetInstance()
	return sampler.SampleGridWithTransform(image, dimension, dimension, transform)
}

func (this *Detector) computeDimension(topLeft, topRight, bottomLeft gozxing.ResultPoint, moduleSize float64) (int, error) {
	tltrCentersDimension := util.MathUtils_Round(gozxing.ResultPoint_Distance(topLeft, topRight) / moduleSize)
	tlblCentersDimension := util.MathUtils_Round(gozxing.ResultPoint_Distance(topLeft, bottomLeft) / moduleSize)
	dimension := ((tltrCentersDimension + tlblCentersDimension) / 2) + 7
	switch dimension % 4 {
	default: // 1? do nothing
		break
	case 0:
		dimension++
		break
	case 2:
		dimension--
		break
	case 3:
		return 0, gozxing.NewNotFoundException("dimension = %v", dimension)
	}
	return dimension, nil
}

func (this *Detector) calculateModuleSize(topLeft, topRight, bottomLeft gozxing.ResultPoint) float64 {
	// Take the average
	return (this.calculateModuleSizeOneWay(topLeft, topRight) +
		this.calculateModuleSizeOneWay(topLeft, bottomLeft)) / 2
}

func (this *Detector) calculateModuleSizeOneWay(pattern, otherPattern gozxing.ResultPoint) float64 {
	moduleSizeEst1 := this.sizeOfBlackWhiteBlackRunBothWays(int(pattern.GetX()),
		int(pattern.GetY()),
		int(otherPattern.GetX()),
		int(otherPattern.GetY()))
	moduleSizeEst2 := this.sizeOfBlackWhiteBlackRunBothWays(int(otherPattern.GetX()),
		int(otherPattern.GetY()),
		int(pattern.GetX()),
		int(pattern.GetY()))
	if math.IsNaN(moduleSizeEst1) {
		return moduleSizeEst2 / 7.0
	}
	if math.IsNaN(moduleSizeEst2) {
		return moduleSizeEst1 / 7.0
	}
	// Average them, and divide by 7 since we've counted the width of 3 black modules,
	// and 1 white and 1 black module on either side. Ergo, divide sum by 14.
	return (moduleSizeEst1 + moduleSizeEst2) / 14.0
}

func (this *Detector) sizeOfBlackWhiteBlackRunBothWays(fromX, fromY, toX, toY int) float64 {

	result := this.sizeOfBlackWhiteBlackRun(fromX, fromY, toX, toY)

	// Now count other way -- don't run off image though of course
	scale := float64(1.0)
	otherToX := fromX - (toX - fromX)
	if otherToX < 0 {
		scale = float64(fromX) / float64(fromX-otherToX)
		otherToX = 0
	} else if otherToX >= this.image.GetWidth() {
		scale = float64(this.image.GetWidth()-1-fromX) / float64(otherToX-fromX)
		otherToX = this.image.GetWidth() - 1
	}
	otherToY := int(float64(fromY) - float64(toY-fromY)*scale)

	scale = 1.0
	if otherToY < 0 {
		scale = float64(fromY) / float64(fromY-otherToY)
		otherToY = 0
	} else if otherToY >= this.image.GetHeight() {
		scale = float64(this.image.GetHeight()-1-fromY) / float64(otherToY-fromY)
		otherToY = this.image.GetHeight() - 1
	}
	otherToX = int(float64(fromX) + float64(otherToX-fromX)*scale)

	result += this.sizeOfBlackWhiteBlackRun(fromX, fromY, otherToX, otherToY)

	// Middle pixel is double-counted this way; subtract 1
	return result - 1.0
}

func (this *Detector) sizeOfBlackWhiteBlackRun(fromX, fromY, toX, toY int) float64 {
	// Mild variant of Bresenham's algorithm;
	// see http://en.wikipedia.org/wiki/Bresenham's_line_algorithm
	steep := false
	dx := toX - fromX
	if dx < 0 {
		dx = -dx
	}
	dy := toY - fromY
	if dy < 0 {
		dy = -dy
	}
	if dy > dx {
		steep = true
		fromX, fromY = fromY, fromX
		toX, toY = toY, toX
		dx, dy = dy, dx
	}

	error := -dx / 2
	xstep := 1
	if fromX >= toX {
		xstep = -1
	}
	ystep := 1
	if fromY >= toY {
		ystep = -1
	}

	// In black pixels, looking for white, first or second time.
	state := 0
	// Loop up until x == toX, but not beyond
	xLimit := toX + xstep
	for x, y := fromX, fromY; x != xLimit; x += xstep {
		realX := x
		realY := y
		if steep {
			realX = y
			realY = x
		}

		// Does current pixel mean we have moved white to black or vice versa?
		// Scanning black in state 0,2 and white in state 1, so if we find the wrong
		// color, advance to next state or end if we are in state 2 already
		if (state == 1) == this.image.Get(realX, realY) {
			if state == 2 {
				return util.MathUtils_DistanceInt(x, y, fromX, fromY)
			}
			state++
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
	// Found black-white-black; give the benefit of the doubt that the next pixel outside the image
	// is "white" so this last point at (toX+xStep,toY) is the right ending. This is really a
	// small approximation; (toX+xStep,toY+yStep) might be really correct. Ignore this.
	if state == 2 {
		return util.MathUtils_DistanceInt(toX+xstep, toY, fromX, fromY)
	}
	// else we didn't find even black-white-black; no estimate is really possible
	return math.NaN()
}

func (this *Detector) findAlignmentInRegion(overallEstModuleSize float64, estAlignmentX, estAlignmentY int, allowanceFactor float64) (*AlignmentPattern, error) {
	// Look for an alignment pattern (3 modules in size) around where it
	// should be
	allowance := int(allowanceFactor * overallEstModuleSize)
	alignmentAreaLeftX := estAlignmentX - allowance
	if alignmentAreaLeftX < 0 {
		alignmentAreaLeftX = 0
	}
	alignmentAreaRightX := estAlignmentX + allowance
	if a := this.image.GetWidth() - 1; a < alignmentAreaRightX {
		alignmentAreaRightX = a
	}
	if x := float64(alignmentAreaRightX - alignmentAreaLeftX); x < overallEstModuleSize*3 {
		return nil, gozxing.NewNotFoundException("x = %v, moduleSize = %v", x, overallEstModuleSize)
	}

	alignmentAreaTopY := estAlignmentY - allowance
	if alignmentAreaTopY < 0 {
		alignmentAreaTopY = 0
	}
	alignmentAreaBottomY := estAlignmentY + allowance
	if a := this.image.GetHeight() - 1; a < alignmentAreaBottomY {
		alignmentAreaBottomY = a
	}

	if y := float64(alignmentAreaBottomY - alignmentAreaTopY); y < overallEstModuleSize*3 {
		return nil, gozxing.NewNotFoundException("y = %v, moduleSize = %v", y, overallEstModuleSize)
	}

	alignmentFinder := NewAlignmentPatternFinder(
		this.image,
		alignmentAreaLeftX,
		alignmentAreaTopY,
		alignmentAreaRightX-alignmentAreaLeftX,
		alignmentAreaBottomY-alignmentAreaTopY,
		overallEstModuleSize,
		this.resultPointCallback)
	return alignmentFinder.Find()
}
