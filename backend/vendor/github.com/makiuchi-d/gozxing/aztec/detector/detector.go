package detector

import (
	"fmt"
	"math"
	"math/bits"

	"github.com/makiuchi-d/gozxing"
	"github.com/makiuchi-d/gozxing/common"
	"github.com/makiuchi-d/gozxing/common/detector"
	"github.com/makiuchi-d/gozxing/common/reedsolomon"
	"github.com/makiuchi-d/gozxing/common/util"
)

var (
	EXPECTED_CORNER_BITS = []int{
		0xee0, // 07340  XXX .XX X.. ...
		0x1dc, // 00734  ... XXX .XX X..
		0x83b, // 04073  X.. ... XXX .XX
		0x707, // 03407 .XX X.. ... XXX
	}
)

// Detector : Encapsulates logic that can detect an Aztec Code in an image, even if the Aztec Code
// is rotated or skewed, or partially obscured.
//
type Detector struct {
	image *gozxing.BitMatrix

	compact        bool
	nbLayers       int
	nbDataBlocks   int
	nbCenterLayers int
	shift          int
}

func NewDetector(image *gozxing.BitMatrix) *Detector {
	return &Detector{
		image: image,
	}
}

func (this *Detector) DetectNoMirror() (*AztecDetectorResult, error) {
	return this.Detect(false)
}

// Detect Detects an Aztec Code in an image.
//
// @param isMirror if true, image is a mirror-image of original
// @return {@link AztecDetectorResult} encapsulating results of detecting an Aztec Code
// @throws NotFoundException if no Aztec Code can be found
//
func (this *Detector) Detect(isMirror bool) (*AztecDetectorResult, error) {

	// 1. Get the center of the aztec matrix
	pCenter := this.getMatrixCenter()

	// 2. Get the center points of the four diagonal points just outside the bull's eye
	//  [topRight, bottomRight, bottomLeft, topLeft]
	bullsEyeCorners, e := this.getBullsEyeCorners(pCenter)
	if e != nil {
		return nil, gozxing.WrapNotFoundException(e)
	}

	if isMirror {
		bullsEyeCorners[0], bullsEyeCorners[2] = bullsEyeCorners[2], bullsEyeCorners[0]
	}

	// 3. Get the size of the matrix and other parameters from the bull's eye
	e = this.extractParameters(bullsEyeCorners)
	if e != nil {
		return nil, gozxing.WrapNotFoundException(e)
	}

	// 4. Sample the grid
	bits, e := this.sampleGrid(this.image,
		bullsEyeCorners[this.shift%4],
		bullsEyeCorners[(this.shift+1)%4],
		bullsEyeCorners[(this.shift+2)%4],
		bullsEyeCorners[(this.shift+3)%4])
	if e != nil {
		return nil, gozxing.WrapNotFoundException(e)
	}

	// 5. Get the corners of the matrix.
	corners := this.getMatrixCornerPoints(bullsEyeCorners)

	return NewAztecDetectorResult(bits, corners, this.compact, this.nbDataBlocks, this.nbLayers), nil
}

// extractParameters Extracts the number of data layers and data blocks from the layer around the bull's eye.
//
// @param bullsEyeCorners the array of bull's eye corners
// @throws NotFoundException in case of too many errors or invalid parameters
//
func (this *Detector) extractParameters(bullsEyeCorners []gozxing.ResultPoint) (e error) {
	if !this.isValidPoint(bullsEyeCorners[0]) || !this.isValidPoint(bullsEyeCorners[1]) ||
		!this.isValidPoint(bullsEyeCorners[2]) || !this.isValidPoint(bullsEyeCorners[3]) {
		return gozxing.NewNotFoundException("invalid bulls eye enters: %v", bullsEyeCorners)
	}
	length := 2 * this.nbCenterLayers
	// Get the bits around the bull's eye
	sides := []int{
		this.sampleLine(bullsEyeCorners[0], bullsEyeCorners[1], length), // Right side
		this.sampleLine(bullsEyeCorners[1], bullsEyeCorners[2], length), // Bottom
		this.sampleLine(bullsEyeCorners[2], bullsEyeCorners[3], length), // Left side
		this.sampleLine(bullsEyeCorners[3], bullsEyeCorners[0], length), // Top
	}

	// bullsEyeCorners[shift] is the corner of the bulls'eye that has three
	// orientation marks.
	// sides[shift] is the row/column that goes from the corner with three
	// orientation marks to the corner with two.
	this.shift, e = getRotation(sides, length)
	if e != nil {
		return gozxing.WrapNotFoundException(e)
	}

	// Flatten the parameter bits into a single 28- or 40-bit long
	parameterData := int64(0)
	for i := 0; i < 4; i++ {
		side := int64(sides[(this.shift+i)%4])
		if this.compact {
			// Each side of the form ..XXXXXXX. where Xs are parameter data
			parameterData <<= 7
			parameterData += (side >> 1) & 0x7F
		} else {
			// Each side of the form ..XXXXX.XXXXX. where Xs are parameter data
			parameterData <<= 10
			parameterData += ((side >> 2) & (0x1f << 5)) + ((side >> 1) & 0x1F)
		}
	}

	// Corrects parameter data using RS.  Returns just the data portion
	// without the error correction.
	correctedData, err := this.getCorrectedParameterData(parameterData, this.compact)
	if err != nil {
		return err
	}

	if this.compact {
		// 8 bits:  2 bits layers and 6 bits data blocks
		this.nbLayers = (correctedData >> 6) + 1
		this.nbDataBlocks = (correctedData & 0x3F) + 1
	} else {
		// 16 bits:  5 bits layers and 11 bits data blocks
		this.nbLayers = (correctedData >> 11) + 1
		this.nbDataBlocks = (correctedData & 0x7FF) + 1
	}
	return nil
}

func getRotation(sides []int, length int) (int, error) {
	// In a normal pattern, we expect to See
	//   **    .*             D       A
	//   *      *
	//
	//   .      *
	//   ..    ..             C       B
	//
	// Grab the 3 bits from each of the sides the form the locator pattern and concatenate
	// into a 12-bit integer.  Start with the bit at A
	cornerBits := 0
	for _, side := range sides {
		// XX......X where X's are orientation marks
		t := ((side >> (length - 2)) << 1) + (side & 1)
		cornerBits = (cornerBits << 3) + t
	}
	// Mov the bottom bit to the top, so that the three bits of the locator pattern at A are
	// together.  cornerBits is now:
	//  3 orientation bits at A || 3 orientation bits at B || ... || 3 orientation bits at D
	cornerBits = ((cornerBits & 1) << 11) + (cornerBits >> 1)
	// The result shift indicates which element of BullsEyeCorners[] goes into the top-left
	// corner. Since the four rotation values have a Hamming distance of 8, we
	// can easily tolerate two errors.
	for shift := 0; shift < 4; shift++ {
		if bits.OnesCount16(uint16(cornerBits^EXPECTED_CORNER_BITS[shift])) <= 2 {
			return shift, nil
		}
	}
	return 0, gozxing.NewNotFoundException("rotation not found")
}

// getCorrectedParameterData Corrects the parameter bits using Reed-Solomon algorithm.
//
// @param parameterData parameter bits
// @param compact true if this is a compact Aztec code
// @throws NotFoundException if the array contains too many errors
//
func (this *Detector) getCorrectedParameterData(parameterData int64, compact bool) (int, error) {
	var numCodewords int
	var numDataCodewords int

	if this.compact {
		numCodewords = 7
		numDataCodewords = 2
	} else {
		numCodewords = 10
		numDataCodewords = 4
	}

	numECCodewords := numCodewords - numDataCodewords
	parameterWords := make([]int, numCodewords)
	for i := numCodewords - 1; i >= 0; i-- {
		parameterWords[i] = int(parameterData) & 0xF
		parameterData >>= 4
	}

	rsDecoder := reedsolomon.NewReedSolomonDecoder(reedsolomon.GenericGF_AZTEC_PARAM)
	if err := rsDecoder.Decode(parameterWords, numECCodewords); err != nil {
		return 0, gozxing.WrapNotFoundException(err)
	}
	// Toss the error correction.  Just return the data as an integer
	result := 0
	for i := 0; i < numDataCodewords; i++ {
		result = (result << 4) + parameterWords[i]
	}
	return result, nil
}

// getBullsEyeCorners Finds the corners of a bull-eye centered on the passed point.
// This returns the centers of the diagonal points just outside the bull's eye
// Returns [topRight, bottomRight, bottomLeft, topLeft]
//
// @param pCenter Center point
// @return The corners of the bull-eye
// @throws NotFoundException If no valid bull-eye can be found
//
func (this *Detector) getBullsEyeCorners(pCenter Point) ([]gozxing.ResultPoint, error) {

	pina := pCenter
	pinb := pCenter
	pinc := pCenter
	pind := pCenter

	color := true

	for this.nbCenterLayers = 1; this.nbCenterLayers < 9; this.nbCenterLayers++ {
		pouta := this.getFirstDifferent(pina, color, 1, -1)
		poutb := this.getFirstDifferent(pinb, color, 1, 1)
		poutc := this.getFirstDifferent(pinc, color, -1, 1)
		poutd := this.getFirstDifferent(pind, color, -1, -1)

		//d      a
		//
		//c      b

		if this.nbCenterLayers > 2 {
			q := distanceP(poutd, pouta) * float64(this.nbCenterLayers) / (distanceP(pind, pina) * float64(this.nbCenterLayers+2))
			if q < 0.75 || q > 1.25 || !this.isWhiteOrBlackRectangle(pouta, poutb, poutc, poutd) {
				break
			}
		}

		pina = pouta
		pinb = poutb
		pinc = poutc
		pind = poutd

		color = !color
	}

	if this.nbCenterLayers != 5 && this.nbCenterLayers != 7 {
		return nil, gozxing.NewNotFoundException("nbCenterLayers = %v", this.nbCenterLayers)
	}

	this.compact = this.nbCenterLayers == 5

	// Expand the square by .5 pixel in each direction so that we're on the border
	// between the white square and the black square
	pinax := gozxing.NewResultPoint(float64(pina.getX())+0.5, float64(pina.getY())-0.5)
	pinbx := gozxing.NewResultPoint(float64(pinb.getX())+0.5, float64(pinb.getY())+0.5)
	pincx := gozxing.NewResultPoint(float64(pinc.getX())-0.5, float64(pinc.getY())+0.5)
	pindx := gozxing.NewResultPoint(float64(pind.getX())-0.5, float64(pind.getY())-0.5)

	// Expand the square so that its corners are the centers of the points
	// just outside the bull's eye.
	return expandSquare([]gozxing.ResultPoint{pinax, pinbx, pincx, pindx},
		2*this.nbCenterLayers-3,
		2*this.nbCenterLayers), nil
}

// getMatrixCenter Finds a candidate center point of an Aztec code from an image
//
// @return the center point
//
func (this *Detector) getMatrixCenter() Point {

	var pointA gozxing.ResultPoint
	var pointB gozxing.ResultPoint
	var pointC gozxing.ResultPoint
	var pointD gozxing.ResultPoint

	//Get a white rectangle that can be the border of the matrix in center bull's eye or
	d, e := detector.NewWhiteRectangleDetectorFromImage(this.image)
	if e == nil {
		if cornerPoints, err := d.Detect(); err != nil {
			e = err
		} else {
			pointA = cornerPoints[0]
			pointB = cornerPoints[1]
			pointC = cornerPoints[2]
			pointD = cornerPoints[3]
		}
	}
	if e != nil {
		// This exception can be in case the initial rectangle is white
		// In that case, surely in the bull's eye, we try to expand the rectangle.
		cx := this.image.GetWidth() / 2
		cy := this.image.GetHeight() / 2
		pointA = this.getFirstDifferent(newPoint(cx+7, cy-7), false, 1, -1).toResultPoint()
		pointB = this.getFirstDifferent(newPoint(cx+7, cy+7), false, 1, 1).toResultPoint()
		pointC = this.getFirstDifferent(newPoint(cx-7, cy+7), false, -1, 1).toResultPoint()
		pointD = this.getFirstDifferent(newPoint(cx-7, cy-7), false, -1, -1).toResultPoint()
	}

	//Compute the center of the rectangle
	cx := util.MathUtils_Round((pointA.GetX() + pointD.GetX() + pointB.GetX() + pointC.GetX()) / 4.0)
	cy := util.MathUtils_Round((pointA.GetY() + pointD.GetY() + pointB.GetY() + pointC.GetY()) / 4.0)

	// Redetermine the white rectangle starting from previously computed center.
	// This will ensure that we end up with a white rectangle in center bull's eye
	// in order to compute a more accurate center.
	d, e = detector.NewWhiteRectangleDetector(this.image, 15, cx, cy)
	if e == nil {
		if cornerPoints, err := d.Detect(); err != nil {
			e = err
		} else {
			pointA = cornerPoints[0]
			pointB = cornerPoints[1]
			pointC = cornerPoints[2]
			pointD = cornerPoints[3]
		}
	}
	if e != nil {
		// This exception can be in case the initial rectangle is white
		// In that case we try to expand the rectangle.
		pointA = this.getFirstDifferent(newPoint(cx+7, cy-7), false, 1, -1).toResultPoint()
		pointB = this.getFirstDifferent(newPoint(cx+7, cy+7), false, 1, 1).toResultPoint()
		pointC = this.getFirstDifferent(newPoint(cx-7, cy+7), false, -1, 1).toResultPoint()
		pointD = this.getFirstDifferent(newPoint(cx-7, cy-7), false, -1, -1).toResultPoint()
	}

	// Recompute the center of the rectangle
	cx = util.MathUtils_Round((pointA.GetX() + pointD.GetX() + pointB.GetX() + pointC.GetX()) / 4.0)
	cy = util.MathUtils_Round((pointA.GetY() + pointD.GetY() + pointB.GetY() + pointC.GetY()) / 4.0)

	return newPoint(cx, cy)
}

// getMatrixCornerPoints Gets the Aztec code corners from the bull's eye corners and the parameters.
//
// @param bullsEyeCorners the array of bull's eye corners
// @return the array of aztec code corners
//
func (this *Detector) getMatrixCornerPoints(bullsEyeCorners []gozxing.ResultPoint) []gozxing.ResultPoint {
	return expandSquare(bullsEyeCorners, 2*this.nbCenterLayers, this.getDimension())
}

// sampleGrid Creates a BitMatrix by sampling the provided image.
// topLeft, topRight, bottomRight, and bottomLeft are the centers of the squares on the
// diagonal just outside the bull's eye.
//
func (this *Detector) sampleGrid(
	image *gozxing.BitMatrix,
	topLeft, topRight, bottomRight, bottomLeft gozxing.ResultPoint) (*gozxing.BitMatrix, error) {

	sampler := common.GridSampler_GetInstance()
	dimension := this.getDimension()

	low := float64(dimension)/2.0 - float64(this.nbCenterLayers)
	high := float64(dimension)/2.0 + float64(this.nbCenterLayers)

	return sampler.SampleGrid(
		image,
		dimension,
		dimension,
		low, low, // topleft
		high, low, // topright
		high, high, // bottomright
		low, high, // bottomleft
		topLeft.GetX(), topLeft.GetY(),
		topRight.GetX(), topRight.GetY(),
		bottomRight.GetX(), bottomRight.GetY(),
		bottomLeft.GetX(), bottomLeft.GetY())
}

// sampleLine Samples a line.
//
// @param p1   start point (inclusive)
// @param p2   end point (exclusive)
// @param size number of bits
// @return the array of bits as an int (first bit is high-order bit of result)
//
func (this *Detector) sampleLine(p1, p2 gozxing.ResultPoint, size int) int {
	result := 0

	d := distanceRP(p1, p2)
	moduleSize := d / float64(size)

	px := p1.GetX()
	py := p1.GetY()
	dx := moduleSize * (p2.GetX() - p1.GetX()) / d
	dy := moduleSize * (p2.GetY() - p1.GetY()) / d
	for i := 0; i < size; i++ {
		if this.image.Get(util.MathUtils_Round(px+float64(i)*dx), util.MathUtils_Round(py+float64(i)*dy)) {
			result |= 1 << (size - i - 1)
		}
	}
	return result
}

// isWhiteOrBlackRectangle @return true if the border of the rectangle passed in parameter is compound of white points only or black points only
//
func (this *Detector) isWhiteOrBlackRectangle(p1, p2, p3, p4 Point) bool {

	corr := 3

	p1 = newPoint(max(0, p1.getX()-corr), min(this.image.GetHeight()-1, p1.getY()+corr))
	p2 = newPoint(max(0, p2.getX()-corr), max(0, p2.getY()-corr))
	p3 = newPoint(min(this.image.GetWidth()-1, p3.getX()+corr),
		max(0, min(this.image.GetHeight()-1, p3.getY()-corr)))
	p4 = newPoint(min(this.image.GetWidth()-1, p4.getX()+corr),
		min(this.image.GetHeight()-1, p4.getY()+corr))

	cInit := this.getColor(p4, p1)

	if cInit == 0 {
		return false
	}

	c := this.getColor(p1, p2)

	if c != cInit {
		return false
	}

	c = this.getColor(p2, p3)

	if c != cInit {
		return false
	}

	c = this.getColor(p3, p4)

	return c == cInit
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

// getColor Gets the color of a segment
//
// @return 1 if segment more than 90% black, -1 if segment is more than 90% white, 0 else
//
func (this *Detector) getColor(p1, p2 Point) int {
	d := distanceP(p1, p2)
	if d == 0.0 {
		return 0
	}
	dx := float64(p2.getX()-p1.getX()) / d
	dy := float64(p2.getY()-p1.getY()) / d
	err := 0

	px := float64(p1.getX())
	py := float64(p1.getY())

	colorModel := this.image.Get(p1.getX(), p1.getY())

	iMax := int(math.Floor(d))
	for i := 0; i < iMax; i++ {
		if this.image.Get(util.MathUtils_Round(px), util.MathUtils_Round(py)) != colorModel {
			err++
		}
		px += dx
		py += dy
	}

	errRatio := float64(err) / d

	if errRatio > 0.1 && errRatio < 0.9 {
		return 0
	}

	if errRatio <= 0.1 == colorModel {
		return 1
	}
	return -1
}

// getFirstDifferent Gets the coordinate of the first point with a different color in the given direction
//
func (this *Detector) getFirstDifferent(init Point, color bool, dx, dy int) Point {
	x := init.getX() + dx
	y := init.getY() + dy

	for this.isValid(x, y) && this.image.Get(x, y) == color {
		x += dx
		y += dy
	}

	x -= dx
	y -= dy

	for this.isValid(x, y) && this.image.Get(x, y) == color {
		x += dx
	}
	x -= dx

	for this.isValid(x, y) && this.image.Get(x, y) == color {
		y += dy
	}
	y -= dy

	return newPoint(x, y)
}

// expandSquare Expand the square represented by the corner points by pushing out equally in all directions
//
// @param cornerPoints the corners of the square, which has the bull's eye at its center
// @param oldSide the original length of the side of the square in the target bit matrix
// @param newSide the new length of the size of the square in the target bit matrix
// @return the corners of the expanded square
//
func expandSquare(cornerPoints []gozxing.ResultPoint, oldSide, newSide int) []gozxing.ResultPoint {
	ratio := float64(newSide) / float64(2*oldSide)
	dx := cornerPoints[0].GetX() - cornerPoints[2].GetX()
	dy := cornerPoints[0].GetY() - cornerPoints[2].GetY()
	centerx := (cornerPoints[0].GetX() + cornerPoints[2].GetX()) / 2.0
	centery := (cornerPoints[0].GetY() + cornerPoints[2].GetY()) / 2.0

	result0 := gozxing.NewResultPoint(centerx+ratio*dx, centery+ratio*dy)
	result2 := gozxing.NewResultPoint(centerx-ratio*dx, centery-ratio*dy)

	dx = cornerPoints[1].GetX() - cornerPoints[3].GetX()
	dy = cornerPoints[1].GetY() - cornerPoints[3].GetY()
	centerx = (cornerPoints[1].GetX() + cornerPoints[3].GetX()) / 2.0
	centery = (cornerPoints[1].GetY() + cornerPoints[3].GetY()) / 2.0
	result1 := gozxing.NewResultPoint(centerx+ratio*dx, centery+ratio*dy)
	result3 := gozxing.NewResultPoint(centerx-ratio*dx, centery-ratio*dy)

	return []gozxing.ResultPoint{result0, result1, result2, result3}
}

func (this *Detector) isValid(x, y int) bool {
	return x >= 0 && x < this.image.GetWidth() && y >= 0 && y < this.image.GetHeight()
}

func (this *Detector) isValidPoint(point gozxing.ResultPoint) bool {
	x := util.MathUtils_Round(point.GetX())
	y := util.MathUtils_Round(point.GetY())
	return this.isValid(x, y)
}

func distanceP(a, b Point) float64 {
	return util.MathUtils_DistanceInt(a.getX(), a.getY(), b.getX(), b.getY())
}

func distanceRP(a, b gozxing.ResultPoint) float64 {
	return util.MathUtils_DistanceFloat(a.GetX(), a.GetY(), b.GetX(), b.GetY())
}

func (this *Detector) getDimension() int {
	if this.compact {
		return 4*this.nbLayers + 11
	}
	return 4*this.nbLayers + 2*((2*this.nbLayers+6)/15) + 15
}

type Point struct {
	x, y int
}

func (p Point) toResultPoint() gozxing.ResultPoint {
	return gozxing.NewResultPoint(float64(p.x), float64(p.y))
}

func newPoint(x, y int) Point {
	return Point{x: x, y: y}
}

func (p Point) getX() int {
	return p.x
}

func (p Point) getY() int {
	return p.y
}

func (p Point) String() string {
	return fmt.Sprintf("<%d %d>", p.x, p.y)
}
