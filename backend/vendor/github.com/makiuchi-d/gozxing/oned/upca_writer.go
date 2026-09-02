package oned

import (
	"github.com/makiuchi-d/gozxing"
)

type upcAWriter struct {
	subWriter gozxing.Writer
}

func NewUPCAWriter() gozxing.Writer {
	return &upcAWriter{
		subWriter: NewEAN13Writer(),
	}
}

func (this *upcAWriter) EncodeWithoutHint(contents string, format gozxing.BarcodeFormat, width, height int) (*gozxing.BitMatrix, error) {
	return this.Encode(contents, format, width, height, nil)
}

func (this *upcAWriter) Encode(contents string, format gozxing.BarcodeFormat, width, height int, hints map[gozxing.EncodeHintType]interface{}) (*gozxing.BitMatrix, error) {
	if format != gozxing.BarcodeFormat_UPC_A {
		return nil, gozxing.NewWriterException(
			"IllegalArgumentException: Can only encode UPC-A, but got %v", format)
	}
	return this.subWriter.Encode("0"+contents, gozxing.BarcodeFormat_EAN_13, width, height, hints)
}
