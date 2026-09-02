package detector

import (
	"math"

	"github.com/makiuchi-d/gozxing"
)

type AlignmentPattern struct {
	gozxing.ResultPoint
	estimatedModuleSize float64
}

func NewAlignmentPattern(posX, posY, estimatedModuleSize float64) *AlignmentPattern {
	return &AlignmentPattern{
		gozxing.NewResultPoint(posX, posY),
		estimatedModuleSize,
	}
}

func (a *AlignmentPattern) AboutEquals(moduleSize, i, j float64) bool {
	if math.Abs(i-a.GetY()) <= moduleSize && math.Abs(j-a.GetX()) <= moduleSize {
		moduleSizeDiff := math.Abs(moduleSize - a.estimatedModuleSize)
		return moduleSizeDiff <= 1.0 || moduleSizeDiff <= a.estimatedModuleSize
	}
	return false
}

func (a *AlignmentPattern) CombineEstimate(i, j, newModuleSize float64) *AlignmentPattern {
	combinedX := (a.GetX() + j) / 2
	combinedY := (a.GetY() + i) / 2
	combinedModuleSize := (a.estimatedModuleSize + newModuleSize) / 2
	return NewAlignmentPattern(combinedX, combinedY, combinedModuleSize)
}
