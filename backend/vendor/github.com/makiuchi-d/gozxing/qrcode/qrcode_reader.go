package qrcode

import (
	"strconv"

	"github.com/makiuchi-d/gozxing"
	"github.com/makiuchi-d/gozxing/common"
	"github.com/makiuchi-d/gozxing/common/util"
	"github.com/makiuchi-d/gozxing/qrcode/decoder"
	"github.com/makiuchi-d/gozxing/qrcode/detector"
)

type QRCodeReader struct {
	decoder *decoder.Decoder
}

func NewQRCodeReader() gozxing.Reader {
	return &QRCodeReader{
		decoder.NewDecoder(),
	}
}

func (this *QRCodeReader) GetDecoder() *decoder.Decoder {
	return this.decoder
}

func (this *QRCodeReader) DecodeWithoutHints(image *gozxing.BinaryBitmap) (*gozxing.Result, error) {
	return this.Decode(image, nil)
}

func (this *QRCodeReader) Decode(image *gozxing.BinaryBitmap, hints map[gozxing.DecodeHintType]interface{}) (*gozxing.Result, error) {
	var decoderResult *common.DecoderResult
	var points []gozxing.ResultPoint

	blackMatrix, e := image.GetBlackMatrix()
	if e != nil {
		return nil, e
	}
	if _, ok := hints[gozxing.DecodeHintType_PURE_BARCODE]; ok {
		bits, e := this.extractPureBits(blackMatrix)
		if e != nil {
			return nil, e
		}
		decoderResult, e = this.decoder.Decode(bits, hints)
		if e != nil {
			return nil, e
		}
		points = []gozxing.ResultPoint{}
	} else {
		detectorResult, e := detector.NewDetector(blackMatrix).Detect(hints)
		if e != nil {
			return nil, e
		}
		decoderResult, e = this.decoder.Decode(detectorResult.GetBits(), hints)
		if e != nil {
			return nil, e
		}
		points = detectorResult.GetPoints()
	}

	// If the code was mirrored: swap the bottom-left and the top-right points.
	if metadata, ok := decoderResult.GetOther().(*decoder.QRCodeDecoderMetaData); ok {
		metadata.ApplyMirroredCorrection(points)
	}

	result := gozxing.NewResult(decoderResult.GetText(), decoderResult.GetRawBytes(), points, gozxing.BarcodeFormat_QR_CODE)
	byteSegments := decoderResult.GetByteSegments()
	if len(byteSegments) > 0 {
		result.PutMetadata(gozxing.ResultMetadataType_BYTE_SEGMENTS, byteSegments)
	}
	ecLevel := decoderResult.GetECLevel()
	if ecLevel != "" {
		result.PutMetadata(gozxing.ResultMetadataType_ERROR_CORRECTION_LEVEL, ecLevel)
	}
	if decoderResult.HasStructuredAppend() {
		result.PutMetadata(
			gozxing.ResultMetadataType_STRUCTURED_APPEND_SEQUENCE,
			decoderResult.GetStructuredAppendSequenceNumber())
		result.PutMetadata(
			gozxing.ResultMetadataType_STRUCTURED_APPEND_PARITY,
			decoderResult.GetStructuredAppendParity())
	}
	result.PutMetadata(
		gozxing.ResultMetadataType_SYMBOLOGY_IDENTIFIER, "]Q"+strconv.Itoa(decoderResult.GetSymbologyModifier()))
	return result, nil
}

func (this *QRCodeReader) Reset() {
	// do nothing
}

func (this *QRCodeReader) extractPureBits(image *gozxing.BitMatrix) (*gozxing.BitMatrix, error) {

	leftTopBlack := image.GetTopLeftOnBit()
	rightBottomBlack := image.GetBottomRightOnBit()
	if leftTopBlack == nil || rightBottomBlack == nil {
		return nil, gozxing.NewNotFoundException()
	}

	moduleSize, e := this.moduleSize(leftTopBlack, image)
	if e != nil {
		return nil, e
	}

	top := leftTopBlack[1]
	bottom := rightBottomBlack[1]
	left := leftTopBlack[0]
	right := rightBottomBlack[0]

	// Sanity check!
	if left >= right || top >= bottom {
		return nil, gozxing.NewNotFoundException(
			"(left,right)=(%v,%v), (top,bottom)=(%v,%v)", left, right, top, bottom)
	}

	if bottom-top != right-left {
		// Special case, where bottom-right module wasn't black so we found something else in the last row
		// Assume it's a square, so use height as the width
		right = left + (bottom - top)
		if right >= image.GetWidth() {
			// Abort if that would not make sense -- off image
			return nil, gozxing.NewNotFoundException("right = %v, width = %v", right, image.GetWidth())
		}
	}

	matrixWidth := util.MathUtils_Round(float64(right-left+1) / moduleSize)
	matrixHeight := util.MathUtils_Round(float64(bottom-top+1) / moduleSize)
	if matrixWidth <= 0 || matrixHeight <= 0 {
		return nil, gozxing.NewNotFoundException("matrixWidth/Height = %v, %v", matrixWidth, matrixHeight)
	}
	if matrixHeight != matrixWidth {
		// Only possibly decode square regions
		return nil, gozxing.NewNotFoundException("matrixWidth/Height = %v, %v", matrixWidth, matrixHeight)
	}

	// Push in the "border" by half the module width so that we start
	// sampling in the middle of the module. Just in case the image is a
	// little off, this will help recover.
	nudge := int(moduleSize / 2.0)
	top += nudge
	left += nudge

	// But careful that this does not sample off the edge
	// "right" is the farthest-right valid pixel location -- right+1 is not necessarily
	// This is positive by how much the inner x loop below would be too large
	nudgedTooFarRight := left + int(float64(matrixWidth-1)*moduleSize) - right
	if nudgedTooFarRight > 0 {
		if nudgedTooFarRight > nudge {
			// Neither way fits; abort
			return nil, gozxing.NewNotFoundException("Neither way fits")
		}
		left -= nudgedTooFarRight
	}
	// See logic above
	nudgedTooFarDown := top + int(float64(matrixHeight-1)*moduleSize) - bottom
	if nudgedTooFarDown > 0 {
		if nudgedTooFarDown > nudge {
			// Neither way fits; abort
			return nil, gozxing.NewNotFoundException("Neither way fits")
		}
		top -= nudgedTooFarDown
	}

	// Now just read off the bits
	bits, _ := gozxing.NewBitMatrix(matrixWidth, matrixHeight)
	for y := 0; y < matrixHeight; y++ {
		iOffset := top + int(float64(y)*moduleSize)
		for x := 0; x < matrixWidth; x++ {
			if image.Get(left+int(float64(x)*moduleSize), iOffset) {
				bits.Set(x, y)
			}
		}
	}
	return bits, nil
}

func (this *QRCodeReader) moduleSize(leftTopBlack []int, image *gozxing.BitMatrix) (float64, error) {
	height := image.GetHeight()
	width := image.GetWidth()
	x := leftTopBlack[0]
	y := leftTopBlack[1]
	inBlack := true
	transitions := 0
	for x < width && y < height {
		if inBlack != image.Get(x, y) {
			transitions++
			if transitions == 5 {
				break
			}
			inBlack = !inBlack
		}
		x++
		y++
	}
	if x == width || y == height {
		return 0, gozxing.NewNotFoundException()
	}
	return float64(x-leftTopBlack[0]) / 7.0, nil
}
