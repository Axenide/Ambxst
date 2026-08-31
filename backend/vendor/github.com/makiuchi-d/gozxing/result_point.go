package gozxing

import (
	"github.com/makiuchi-d/gozxing/common/util"
)

type ResultPoint interface {
	GetX() float64
	GetY() float64
}

type ResultPointBase struct {
	x float64
	y float64
}

func NewResultPoint(x, y float64) ResultPoint {
	return ResultPointBase{x, y}
}

func (rp ResultPointBase) GetX() float64 {
	return rp.x
}

func (rp ResultPointBase) GetY() float64 {
	return rp.y
}

// Orders an array of three ResultPoints in an order [A,B,C] such that AB is less than AC
// and BC is less than AC, and the angle between BC and BA is less than 180 degrees.
// @param patterns array of three {@code ResultPoint} to order
func ResultPoint_OrderBestPatterns(pattern0, pattern1, pattern2 ResultPoint) (pointA, pointB, pointC ResultPoint) {
	// Find distances between pattern centers
	zeroOneDistance := ResultPoint_Distance(pattern0, pattern1)
	oneTwoDistance := ResultPoint_Distance(pattern1, pattern2)
	zeroTwoDistance := ResultPoint_Distance(pattern0, pattern2)

	// Assume one closest to other two is B; A and C will just be guesses at first
	if oneTwoDistance >= zeroOneDistance && oneTwoDistance >= zeroTwoDistance {
		pointB = pattern0
		pointA = pattern1
		pointC = pattern2
	} else if zeroTwoDistance >= oneTwoDistance && zeroTwoDistance >= zeroOneDistance {
		pointB = pattern1
		pointA = pattern0
		pointC = pattern2
	} else {
		pointB = pattern2
		pointA = pattern0
		pointC = pattern1
	}

	// Use cross product to figure out whether A and C are correct or flipped.
	// This asks whether BC x BA has a positive z component, which is the arrangement
	// we want for A, B, C. If it's negative, then we've got it flipped around and
	// should swap A and C.
	if crossProductZ(pointA, pointB, pointC) < 0.0 {
		pointA, pointC = pointC, pointA
	}

	return pointA, pointB, pointC
}

func ResultPoint_Distance(pattern1, pattern2 ResultPoint) float64 {
	return util.MathUtils_DistanceFloat(pattern1.GetX(), pattern1.GetY(), pattern2.GetX(), pattern2.GetY())
}

func crossProductZ(pointA, pointB, pointC ResultPoint) float64 {
	bX := pointB.GetX()
	bY := pointB.GetY()
	return ((pointC.GetX() - bX) * (pointA.GetY() - bY)) - ((pointC.GetY() - bY) * (pointA.GetX() - bX))
}
