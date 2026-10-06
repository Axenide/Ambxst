package util

import (
	"math"
)

func MathUtils_Round(d float64) int {
	if d < 0.0 {
		return int(d - 0.5)
	}
	return int(d + 0.5)
}

func MathUtils_DistanceFloat(aX, aY, bX, bY float64) float64 {
	xDiff := aX - bX
	yDiff := aY - bY
	return math.Sqrt(xDiff*xDiff + yDiff*yDiff)
}

func MathUtils_DistanceInt(aX, aY, bX, bY int) float64 {
	xDiff := aX - bX
	yDiff := aY - bY
	return math.Sqrt(float64(xDiff*xDiff + yDiff*yDiff))
}

func MathUtils_Sum(arr []int) int {
	count := 0
	for _, a := range arr {
		count += a
	}
	return count
}
