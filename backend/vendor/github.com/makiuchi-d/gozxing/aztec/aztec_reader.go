package aztec

import (
	"strconv"
	"time"

	"github.com/makiuchi-d/gozxing"
	"github.com/makiuchi-d/gozxing/aztec/decoder"
	"github.com/makiuchi-d/gozxing/aztec/detector"
	"github.com/makiuchi-d/gozxing/common"
)

// AztecReader : This implementation can detect and decode Aztec codes in an image.
type AztecReader struct{}

var _ gozxing.Reader = &AztecReader{}

func NewAztecReader() *AztecReader {
	return &AztecReader{}
}

func (r *AztecReader) DecodeWithoutHints(image *gozxing.BinaryBitmap) (*gozxing.Result, error) {
	return r.Decode(image, nil)
}

// Decode : Locates and decodes a Data Matrix code in an image.
//
// @return a String representing the content encoded by the Data Matrix code
// @throws NotFoundException if a Data Matrix code cannot be found
// @throws FormatException if a Data Matrix code cannot be decoded
//
func (r *AztecReader) Decode(image *gozxing.BinaryBitmap, hints map[gozxing.DecodeHintType]interface{}) (*gozxing.Result, error) {

	var notFoundException error
	var formatException error
	bmp, err := image.GetBlackMatrix()
	if err != nil {
		return nil, gozxing.WrapReaderException(err)
	}
	detector := detector.NewDetector(bmp)
	var points []gozxing.ResultPoint
	var decoderResult *common.DecoderResult

	detectorResult, err := detector.Detect(false)
	if err != nil {
		notFoundException = gozxing.WrapNotFoundException(err)
	} else {
		points = detectorResult.GetPoints()
		decoderResult, err = decoder.NewDecoder().Decode(detectorResult)
		if err != nil {
			formatException = gozxing.WrapFormatException(err)
		}
	}
	if decoderResult == nil {
		detectorResult, err = detector.Detect(true)
		if err != nil {
			err = gozxing.WrapNotFoundException(err)
		} else {
			points = detectorResult.GetPoints()
			decoderResult, err = decoder.NewDecoder().Decode(detectorResult)
			if err != nil {
				err = gozxing.WrapFormatException(err)
			}
		}
	}
	if err != nil {
		if notFoundException != nil {
			return nil, notFoundException
		}
		if formatException != nil {
			return nil, formatException
		}
		return nil, gozxing.WrapReaderException(err)
	}

	if hints != nil {
		rpcb, ok := hints[gozxing.DecodeHintType_NEED_RESULT_POINT_CALLBACK].(gozxing.ResultPointCallback)
		if ok && rpcb != nil {
			for _, point := range points {
				rpcb(point)
			}
		}
	}

	result := gozxing.NewResultWithNumBits(
		decoderResult.GetText(),
		decoderResult.GetRawBytes(),
		decoderResult.GetNumBits(),
		points,
		gozxing.BarcodeFormat_AZTEC,
		time.Now().UnixNano()/int64(time.Millisecond))

	byteSegments := decoderResult.GetByteSegments()
	if byteSegments != nil {
		result.PutMetadata(gozxing.ResultMetadataType_BYTE_SEGMENTS, byteSegments)
	}
	ecLevel := decoderResult.GetECLevel()
	if ecLevel != "" {
		result.PutMetadata(gozxing.ResultMetadataType_ERROR_CORRECTION_LEVEL, ecLevel)
	}
	result.PutMetadata(gozxing.ResultMetadataType_SYMBOLOGY_IDENTIFIER, "]z"+strconv.Itoa(decoderResult.GetSymbologyModifier()))

	return result, nil
}

func (r *AztecReader) Reset() {
}
