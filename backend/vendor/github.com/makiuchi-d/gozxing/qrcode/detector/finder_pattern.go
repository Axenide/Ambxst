package detector

import (
	"math"

	"github.com/makiuchi-d/gozxing"
)

type FinderPattern struct {
	gozxing.ResultPoint
	estimatedModuleSize float64
	count               int
}

func NewFinderPattern1(posX, posY, estimatedModuleSize float64) *FinderPattern {
	return NewFinderPattern(posX, posY, estimatedModuleSize, 1)
}

func NewFinderPattern(posX, posY, estimatedModuleSize float64, count int) *FinderPattern {
	return &FinderPattern{
		gozxing.NewResultPoint(posX, posY),
		estimatedModuleSize,
		count,
	}
}

func (f *FinderPattern) GetEstimatedModuleSize() float64 {
	return f.estimatedModuleSize
}

func (f *FinderPattern) GetCount() int {
	return f.count
}

func (f *FinderPattern) AboutEquals(moduleSize, i, j float64) bool {
	if math.Abs(i-f.GetY()) <= moduleSize && math.Abs(j-f.GetX()) <= moduleSize {
		moduleSizeDiff := math.Abs(moduleSize - f.estimatedModuleSize)
		return moduleSizeDiff <= 1.0 || moduleSizeDiff <= f.estimatedModuleSize
	}
	return false
}

func (f *FinderPattern) CombineEstimate(i, j, newModuleSize float64) *FinderPattern {
	combinedCount := float64(f.count + 1)
	combinedX := (float64(f.count)*f.GetX() + j) / combinedCount
	combinedY := (float64(f.count)*f.GetY() + i) / combinedCount
	combinedModuleSize := (float64(f.count)*f.estimatedModuleSize + newModuleSize) / combinedCount
	return NewFinderPattern(combinedX, combinedY, combinedModuleSize, int(combinedCount))
}
