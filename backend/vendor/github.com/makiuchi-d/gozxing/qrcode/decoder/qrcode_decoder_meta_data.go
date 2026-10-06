package decoder

import (
	"github.com/makiuchi-d/gozxing"
)

type QRCodeDecoderMetaData struct {
	mirrored bool
}

func NewQRCodeDecoderMetaData(mirrored bool) *QRCodeDecoderMetaData {
	return &QRCodeDecoderMetaData{mirrored}
}

func (this *QRCodeDecoderMetaData) IsMirrored() bool {
	return this.mirrored
}

func (this *QRCodeDecoderMetaData) ApplyMirroredCorrection(points []gozxing.ResultPoint) {
	if !this.mirrored || len(points) < 3 {
		return
	}
	points[0], points[2] = points[2], points[0]
}
