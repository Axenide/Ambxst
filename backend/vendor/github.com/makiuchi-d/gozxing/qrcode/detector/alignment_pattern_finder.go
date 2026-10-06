package detector

import (
	"math"

	"github.com/makiuchi-d/gozxing"
)

type AlignmentPatternFinder struct {
	image                *gozxing.BitMatrix
	possibleCenters      []*AlignmentPattern
	startX               int
	startY               int
	width                int
	height               int
	moduleSize           float64
	crossCheckStateCount []int
	resultPointCallback  gozxing.ResultPointCallback
}

func NewAlignmentPatternFinder(image *gozxing.BitMatrix, startX, startY, width, height int, moduleSize float64, resultPointCallback gozxing.ResultPointCallback) *AlignmentPatternFinder {
	return &AlignmentPatternFinder{
		image:                image,
		possibleCenters:      make([]*AlignmentPattern, 0),
		startX:               startX,
		startY:               startY,
		width:                width,
		height:               height,
		moduleSize:           moduleSize,
		crossCheckStateCount: make([]int, 3),
		resultPointCallback:  resultPointCallback,
	}
}

func (this *AlignmentPatternFinder) Find() (*AlignmentPattern, gozxing.NotFoundException) {
	startX := this.startX
	height := this.height
	maxJ := startX + this.width
	middleI := this.startY + (this.height / 2)
	// We are looking for black/white/black modules in 1:1:1 ratio;
	// this tracks the number of black/white/black modules seen so far
	stateCount := make([]int, 3)
	for iGen := 0; iGen < height; iGen++ {
		// Search from middle outwards
		i := middleI
		if iGen&1 == 0 {
			i += (iGen + 1) / 2
		} else {
			i -= (iGen + 1) / 2
		}
		stateCount[0] = 0
		stateCount[1] = 0
		stateCount[2] = 0
		j := startX
		// Burn off leading white pixels before anything else; if we start in the middle of
		// a white run, it doesn't make sense to count its length, since we don't know if the
		// white run continued to the left of the start point
		for j < maxJ && !this.image.Get(j, i) {
			j++
		}
		currentState := 0
		for j < maxJ {
			if this.image.Get(j, i) {
				// Black pixel
				if currentState == 1 { // Counting black pixels
					stateCount[1]++
				} else { // Counting white pixels
					if currentState == 2 { // A winner?
						if this.foundPatternCross(stateCount) { // Yes
							confirmed := this.handlePossibleCenter(stateCount, i, j)
							if confirmed != nil {
								return confirmed, nil
							}
						}
						stateCount[0] = stateCount[2]
						stateCount[1] = 1
						stateCount[2] = 0
						currentState = 1
					} else {
						currentState++
						stateCount[currentState]++
					}
				}
			} else { // White pixel
				if currentState == 1 { // Counting black pixels
					currentState++
				}
				stateCount[currentState]++
			}
			j++
		}
		if this.foundPatternCross(stateCount) {
			confirmed := this.handlePossibleCenter(stateCount, i, maxJ)
			if confirmed != nil {
				return confirmed, nil
			}
		}

	}

	// Hmm, nothing we saw was observed and confirmed twice. If we had
	// any guess at all, return it.
	if len(this.possibleCenters) > 0 {
		return this.possibleCenters[0], nil
	}

	return nil, gozxing.NewNotFoundException()
}

func AlignmentPatternFinder_centerFromEnd(stateCount []int, end int) float64 {
	return float64(end-stateCount[2]) - float64(stateCount[1])/2.0
}

func (this *AlignmentPatternFinder) foundPatternCross(stateCount []int) bool {
	moduleSize := this.moduleSize
	maxVariance := moduleSize / 2
	for i := 0; i < 3; i++ {
		if math.Abs(moduleSize-float64(stateCount[i])) >= maxVariance {
			return false
		}
	}
	return true
}

func (this *AlignmentPatternFinder) crossCheckVertical(startI, centerJ, maxCount, originalStateCountTotal int) float64 {
	image := this.image

	maxI := image.GetHeight()
	stateCount := this.crossCheckStateCount
	stateCount[0] = 0
	stateCount[1] = 0
	stateCount[2] = 0

	// Start counting up from center
	i := startI
	for i >= 0 && image.Get(centerJ, i) && stateCount[1] <= maxCount {
		stateCount[1]++
		i--
	}
	// If already too many modules in this state or ran off the edge:
	if i < 0 || stateCount[1] > maxCount {
		return math.NaN()
	}
	for i >= 0 && !image.Get(centerJ, i) && stateCount[0] <= maxCount {
		stateCount[0]++
		i--
	}
	if stateCount[0] > maxCount {
		return math.NaN()
	}

	// Now also count down from center
	i = startI + 1
	for i < maxI && image.Get(centerJ, i) && stateCount[1] <= maxCount {
		stateCount[1]++
		i++
	}
	if i == maxI || stateCount[1] > maxCount {
		return math.NaN()
	}
	for i < maxI && !image.Get(centerJ, i) && stateCount[2] <= maxCount {
		stateCount[2]++
		i++
	}
	if stateCount[2] > maxCount {
		return math.NaN()
	}

	stateCountTotal := stateCount[0] + stateCount[1] + stateCount[2]
	abs := stateCountTotal - originalStateCountTotal
	if abs < 0 {
		abs = -abs
	}
	if 5*abs >= 2*originalStateCountTotal {
		return math.NaN()
	}

	if this.foundPatternCross(stateCount) {
		return AlignmentPatternFinder_centerFromEnd(stateCount, i)
	}
	return math.NaN()
}

func (this *AlignmentPatternFinder) handlePossibleCenter(stateCount []int, i, j int) *AlignmentPattern {
	stateCountTotal := stateCount[0] + stateCount[1] + stateCount[2]
	centerJ := AlignmentPatternFinder_centerFromEnd(stateCount, j)
	centerI := this.crossCheckVertical(i, int(centerJ), 2*stateCount[1], stateCountTotal)
	if !math.IsNaN(centerI) {
		estimatedModuleSize := float64(stateCount[0]+stateCount[1]+stateCount[2]) / 3
		for _, center := range this.possibleCenters {
			if center.AboutEquals(estimatedModuleSize, centerI, centerJ) {
				return center.CombineEstimate(centerI, centerJ, estimatedModuleSize)
			}
		}
		// Hadn't found this before; save it
		point := NewAlignmentPattern(centerJ, centerI, estimatedModuleSize)
		this.possibleCenters = append(this.possibleCenters, point)
		if this.resultPointCallback != nil {
			this.resultPointCallback(point)
		}
	}
	return nil
}
