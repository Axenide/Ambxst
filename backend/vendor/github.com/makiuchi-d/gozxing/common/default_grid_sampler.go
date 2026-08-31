package common

import (
	"github.com/makiuchi-d/gozxing"
)

type DefaultGridSampler struct{}

func NewDefaultGridSampler() GridSampler {
	return DefaultGridSampler{}
}

func (s DefaultGridSampler) SampleGrid(image *gozxing.BitMatrix, dimensionX, dimensionY int,
	p1ToX, p1ToY, p2ToX, p2ToY, p3ToX, p3ToY, p4ToX, p4ToY float64,
	p1FromX, p1FromY, p2FromX, p2FromY, p3FromX, p3FromY, p4FromX, p4FromY float64) (*gozxing.BitMatrix, error) {

	transform := PerspectiveTransform_QuadrilateralToQuadrilateral(
		p1ToX, p1ToY, p2ToX, p2ToY, p3ToX, p3ToY, p4ToX, p4ToY,
		p1FromX, p1FromY, p2FromX, p2FromY, p3FromX, p3FromY, p4FromX, p4FromY)

	return s.SampleGridWithTransform(image, dimensionX, dimensionY, transform)
}

func (s DefaultGridSampler) SampleGridWithTransform(image *gozxing.BitMatrix,
	dimensionX, dimensionY int, transform *PerspectiveTransform) (*gozxing.BitMatrix, error) {

	if dimensionX <= 0 || dimensionY <= 0 {
		return nil, gozxing.NewNotFoundException("dimensions X, Y = %v, %v", dimensionX, dimensionY)
	}
	bits, _ := gozxing.NewBitMatrix(dimensionX, dimensionY) // always success
	points := make([]float64, 2*dimensionX)
	for y := 0; y < dimensionY; y++ {
		max := len(points)
		iValue := float64(y) + 0.5
		for x := 0; x < max; x += 2 {
			points[x] = float64(x/2) + 0.5
			points[x+1] = iValue
		}
		transform.TransformPoints(points)
		// Quick check to see if points transformed to something inside the image;
		// sufficient to check the endpoints
		e := GridSampler_checkAndNudgePoints(image, points)
		if e != nil {
			return nil, gozxing.WrapNotFoundException(e)
		}
		for x := 0; x < max; x += 2 {
			px := int(points[x])
			py := int(points[x+1])

			if px >= image.GetWidth() || py >= image.GetHeight() {
				// cause of ArrayIndexOutOfBoundsException in image.Get(px, py)

				// This feels wrong, but, sometimes if the finder patterns are misidentified, the resulting
				// transform gets "twisted" such that it maps a straight line of points to a set of points
				// whose endpoints are in bounds, but others are not. There is probably some mathematical
				// way to detect this about the transformation that I don't know yet.
				// This results in an ugly runtime exception despite our clever checks above -- can't have
				// that. We could check each point's coordinates but that feels duplicative. We settle for
				// catching and wrapping ArrayIndexOutOfBoundsException.
				return nil, gozxing.NewNotFoundException()
			}

			if image.Get(px, py) {
				// Black(-ish) pixel
				bits.Set(x/2, y)
			}
		}
	}
	return bits, nil
}
