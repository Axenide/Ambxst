package datamatrix

import (
	"strconv"

	"github.com/makiuchi-d/gozxing"
	"github.com/makiuchi-d/gozxing/common"
	"github.com/makiuchi-d/gozxing/datamatrix/decoder"
	"github.com/makiuchi-d/gozxing/datamatrix/detector"
)

var (
	noPoints = []gozxing.ResultPoint{}
)

type DataMatrixReader struct {
	decoder *decoder.Decoder
}

func NewDataMatrixReader() *DataMatrixReader {
	return &DataMatrixReader{
		decoder: decoder.NewDecoder(),
	}
}

func (r *DataMatrixReader) DecodeWithoutHints(image *gozxing.BinaryBitmap) (*gozxing.Result, error) {
	return r.Decode(image, nil)
}

// Decode Locates and decodes a Data Matrix code in an image.
//
// @return a String representing the content encoded by the Data Matrix code
// @throws NotFoundException if a Data Matrix code cannot be found
// @throws FormatException if a Data Matrix code cannot be decoded
// @throws ChecksumException if error correction fails
//
func (r *DataMatrixReader) Decode(image *gozxing.BinaryBitmap, hints map[gozxing.DecodeHintType]interface{}) (*gozxing.Result, error) {
	var decoderResult *common.DecoderResult
	var points []gozxing.ResultPoint
	if _, ok := hints[gozxing.DecodeHintType_PURE_BARCODE]; ok {
		blackm, e := image.GetBlackMatrix()
		if e != nil {
			return nil, gozxing.WrapReaderException(e)
		}
		bits, e := extractPureBits(blackm)
		if e != nil {
			return nil, e
		}
		decoderResult, e = r.decoder.Decode(bits)
		if e != nil {
			return nil, e
		}
		points = noPoints
	} else {
		blackm, e := image.GetBlackMatrix()
		if e != nil {
			return nil, gozxing.WrapReaderException(e)
		}
		detector, e := detector.NewDetector(blackm)
		if e != nil {
			return nil, e
		}
		detectorResult, e := detector.Detect()
		if e != nil {
			return nil, e
		}
		decoderResult, e = r.decoder.Decode(detectorResult.GetBits())
		if e != nil {
			return nil, e
		}
		points = detectorResult.GetPoints()
	}
	result := gozxing.NewResult(decoderResult.GetText(), decoderResult.GetRawBytes(), points,
		gozxing.BarcodeFormat_DATA_MATRIX)
	byteSegments := decoderResult.GetByteSegments()
	if byteSegments != nil {
		result.PutMetadata(gozxing.ResultMetadataType_BYTE_SEGMENTS, byteSegments)
	}
	ecLevel := decoderResult.GetECLevel()
	if ecLevel != "" {
		result.PutMetadata(gozxing.ResultMetadataType_ERROR_CORRECTION_LEVEL, ecLevel)
	}
	result.PutMetadata(gozxing.ResultMetadataType_SYMBOLOGY_IDENTIFIER, "]d"+strconv.Itoa(decoderResult.GetSymbologyModifier()))
	return result, nil
}

func (r *DataMatrixReader) Reset() {
	// do nothing
}

// extractPureBits This method detects a code in a "pure" image -- that is, pure monochrome image
// which contains only an unrotated, unskewed, image of a code, with some white border
// around it. This is a specialized method that works exceptionally fast in this special case.
//
func extractPureBits(image *gozxing.BitMatrix) (*gozxing.BitMatrix, error) {

	leftTopBlack := image.GetTopLeftOnBit()
	rightBottomBlack := image.GetBottomRightOnBit()
	if leftTopBlack == nil || rightBottomBlack == nil {
		return nil, gozxing.NewNotFoundException(
			"leftTopBlack=%v, rightBottomBlack=%v", leftTopBlack, rightBottomBlack)
	}

	moduleSize, e := moduleSize(leftTopBlack, image)
	if e != nil {
		return nil, e
	}

	top := leftTopBlack[1]
	bottom := rightBottomBlack[1]
	left := leftTopBlack[0]
	right := rightBottomBlack[0]

	matrixWidth := (right - left + 1) / moduleSize
	matrixHeight := (bottom - top + 1) / moduleSize
	if matrixWidth <= 0 || matrixHeight <= 0 {
		return nil, gozxing.NewNotFoundException(
			"matrixWidth=%v, matrixHeight=%v", matrixWidth, matrixHeight)
	}

	// Push in the "border" by half the module width so that we start
	// sampling in the middle of the module. Just in case the image is a
	// little off, this will help recover.
	nudge := moduleSize / 2
	top += nudge
	left += nudge

	// Now just read off the bits
	bits, _ := gozxing.NewBitMatrix(matrixWidth, matrixHeight)
	for y := 0; y < matrixHeight; y++ {
		iOffset := top + y*moduleSize
		for x := 0; x < matrixWidth; x++ {
			if image.Get(left+x*moduleSize, iOffset) {
				bits.Set(x, y)
			}
		}
	}
	return bits, nil
}

func moduleSize(leftTopBlack []int, image *gozxing.BitMatrix) (int, error) {
	width := image.GetWidth()
	x := leftTopBlack[0]
	y := leftTopBlack[1]
	for x < width && image.Get(x, y) {
		x++
	}
	if x == width {
		return 0, gozxing.NewNotFoundException("x == width, %v", x)
	}

	moduleSize := x - leftTopBlack[0]
	if moduleSize == 0 {
		return 0, gozxing.NewNotFoundException("moduleSize == 0")
	}
	return moduleSize, nil
}
