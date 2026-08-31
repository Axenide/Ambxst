package common

import (
	"github.com/makiuchi-d/gozxing"
)

type DetectorResult struct {
	bits   *gozxing.BitMatrix
	points []gozxing.ResultPoint
}

func NewDetectorResult(bits *gozxing.BitMatrix, points []gozxing.ResultPoint) *DetectorResult {
	return &DetectorResult{bits, points}
}

func (d *DetectorResult) GetBits() *gozxing.BitMatrix {
	return d.bits
}

func (d *DetectorResult) GetPoints() []gozxing.ResultPoint {
	return d.points
}
