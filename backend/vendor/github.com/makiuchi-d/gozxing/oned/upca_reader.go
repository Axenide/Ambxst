package oned

import (
	"github.com/makiuchi-d/gozxing"
)

type upcAReader struct {
	*upceanReader
	ean13Reader *ean13Reader
}

func NewUPCAReader() gozxing.Reader {
	this := &upcAReader{
		ean13Reader: NewEAN13Reader().(*ean13Reader),
	}
	this.upceanReader = newUPCEANReader(this)
	return this
}

func (this *upcAReader) DecodeRow(rowNumber int, row *gozxing.BitArray, hints map[gozxing.DecodeHintType]interface{}) (*gozxing.Result, error) {
	return maybeReturnResult(this.ean13Reader.DecodeRow(rowNumber, row, hints))
}

func (this *upcAReader) decodeRowWithStartRange(
	rowNumber int, row *gozxing.BitArray, startGuardRange []int,
	hints map[gozxing.DecodeHintType]interface{}) (*gozxing.Result, error) {
	return maybeReturnResult(this.ean13Reader.decodeRowWithStartRange(rowNumber, row, startGuardRange, hints))
}

func (this *upcAReader) DecodeWithoutHints(image *gozxing.BinaryBitmap) (*gozxing.Result, error) {
	return maybeReturnResult(this.ean13Reader.DecodeWithoutHints(image))
}

func (this *upcAReader) Decode(image *gozxing.BinaryBitmap, hints map[gozxing.DecodeHintType]interface{}) (*gozxing.Result, error) {
	return maybeReturnResult(this.ean13Reader.Decode(image, hints))
}

func (this *upcAReader) getBarcodeFormat() gozxing.BarcodeFormat {
	return gozxing.BarcodeFormat_UPC_A
}

func maybeReturnResult(result *gozxing.Result, e error) (*gozxing.Result, error) {
	if e != nil {
		return nil, e
	}
	text := result.GetText()
	if text[0] == '0' {
		upcaResult := gozxing.NewResult(
			text[1:],
			nil,
			result.GetResultPoints(),
			gozxing.BarcodeFormat_UPC_A)
		if result.GetResultMetadata() != nil {
			upcaResult.PutAllMetadata(result.GetResultMetadata())
		}
		return upcaResult, nil
	} else {
		return nil, gozxing.NewFormatException()
	}
}
