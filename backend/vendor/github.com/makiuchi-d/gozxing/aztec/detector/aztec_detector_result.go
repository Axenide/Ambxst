package detector

import (
	"github.com/makiuchi-d/gozxing"
	"github.com/makiuchi-d/gozxing/common"
)

// AztecDetectorResult Extends {@link DetectorResult} with more information specific to the Aztec format,
// like the number of layers and whether it's compact.
type AztecDetectorResult struct {
	*common.DetectorResult

	compact      bool
	nbDatablocks int
	nbLayers     int
}

func NewAztecDetectorResult(bits *gozxing.BitMatrix, points []gozxing.ResultPoint, compact bool, nbDatablocks, nbLayers int) *AztecDetectorResult {
	return &AztecDetectorResult{
		DetectorResult: common.NewDetectorResult(bits, points),
		compact:        compact,
		nbDatablocks:   nbDatablocks,
		nbLayers:       nbLayers,
	}
}

func (d *AztecDetectorResult) GetNbLayers() int {
	return d.nbLayers
}
func (d *AztecDetectorResult) GetNbDatablocks() int {
	return d.nbDatablocks
}

func (d *AztecDetectorResult) IsCompact() bool {
	return d.compact
}
