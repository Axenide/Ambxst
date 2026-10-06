package decoder

import (
	"github.com/makiuchi-d/gozxing"
	"github.com/makiuchi-d/gozxing/common"
	"github.com/makiuchi-d/gozxing/common/reedsolomon"
)

type Decoder struct {
	rsDecoder *reedsolomon.ReedSolomonDecoder
}

func NewDecoder() *Decoder {
	return &Decoder{
		rsDecoder: reedsolomon.NewReedSolomonDecoder(reedsolomon.GenericGF_QR_CODE_FIELD_256),
	}
}

func (this *Decoder) DecodeBoolMapWithoutHint(image [][]bool) (*common.DecoderResult, error) {
	return this.DecodeBoolMap(image, nil)
}

func (this *Decoder) DecodeBoolMap(image [][]bool, hints map[gozxing.DecodeHintType]interface{}) (*common.DecoderResult, error) {
	bits, e := gozxing.ParseBoolMapToBitMatrix(image)
	if e != nil {
		return nil, e
	}
	return this.Decode(bits, hints)
}

func (this *Decoder) DecodeWithoutHint(bits *gozxing.BitMatrix) (*common.DecoderResult, error) {
	return this.Decode(bits, nil)
}

func (this *Decoder) Decode(bits *gozxing.BitMatrix, hints map[gozxing.DecodeHintType]interface{}) (*common.DecoderResult, error) {

	// Construct a parser and read version, error-correction level
	parser, e := NewBitMatrixParser(bits)
	if e != nil {
		return nil, gozxing.WrapFormatException(e)
	}
	var fece gozxing.ReaderException

	result, e := this.decode(parser, hints)
	if e == nil {
		return result, nil
	}

	switch e.(type) {
	case gozxing.FormatException, gozxing.ChecksumException:
		fece = e.(gozxing.ReaderException)
	}
	e = nil

	// Revert the bit matrix
	parser.Remask()

	// Will be attempting a mirrored reading of the version and format info.
	parser.SetMirror(true)

	if e == nil {
		// Preemptively read the version.
		_, e = parser.ReadVersion()
	}

	if e == nil {
		// Preemptively read the format information.
		_, e = parser.ReadFormatInformation()
	}

	if e == nil {
		/*
		 * Since we're here, this means we have successfully detected some kind
		 * of version and format information when mirrored. This is a good sign,
		 * that the QR code may be mirrored, and we should try once more with a
		 * mirrored content.
		 */
		// Prepare for a mirrored reading.
		parser.Mirror()
	}

	if e == nil {
		result, e = this.decode(parser, hints)
	}

	if e == nil {
		// Success! Notify the caller that the code was mirrored.
		result.SetOther(NewQRCodeDecoderMetaData(true))
		return result, nil
	}

	// `e` is not nil
	switch e.(type) {
	case gozxing.FormatException, gozxing.ChecksumException:
		// Throw the exception from the original reading
		return nil, fece
	default:
		return nil, e
	}
}

func (this *Decoder) decode(parser *BitMatrixParser, hints map[gozxing.DecodeHintType]interface{}) (*common.DecoderResult, error) {
	version, e := parser.ReadVersion()
	if e != nil {
		return nil, gozxing.WrapFormatException(e)
	}
	formatinfo, e := parser.ReadFormatInformation()
	if e != nil {
		return nil, gozxing.WrapFormatException(e)
	}
	ecLevel := formatinfo.GetErrorCorrectionLevel()

	// Read codewords
	codewords, e := parser.ReadCodewords()
	if e != nil {
		return nil, gozxing.WrapFormatException(e)
	}
	// Separate into data blocks
	dataBlocks, e := DataBlock_GetDataBlocks(codewords, version, ecLevel)
	if e != nil {
		return nil, gozxing.WrapFormatException(e)
	}

	// Count total number of data bytes
	totalBytes := 0
	for _, dataBlock := range dataBlocks {
		totalBytes += dataBlock.GetNumDataCodewords()
	}
	resultBytes := make([]byte, totalBytes)
	resultOffset := 0

	// Error-correct and copy data blocks together into a stream of bytes
	for _, dataBlock := range dataBlocks {
		codewordBytes := dataBlock.GetCodewords()
		numDataCodewords := dataBlock.GetNumDataCodewords()
		e := this.correctErrors(codewordBytes, numDataCodewords)
		if e != nil {
			return nil, e
		}
		for i := 0; i < numDataCodewords; i++ {
			resultBytes[resultOffset] = codewordBytes[i]
			resultOffset++
		}
	}

	// Decode the contents of that stream of bytes
	return DecodedBitStreamParser_Decode(resultBytes, version, ecLevel, hints)
}

func (this *Decoder) correctErrors(codewordBytes []byte, numDataCodewords int) error {
	numCodewords := len(codewordBytes)
	// First read into an array of ints
	codewordsInts := make([]int, numCodewords)
	for i := 0; i < numCodewords; i++ {
		codewordsInts[i] = int(codewordBytes[i] & 0xFF)
	}

	e := this.rsDecoder.Decode(codewordsInts, numCodewords-numDataCodewords)
	if e != nil {
		return gozxing.WrapChecksumException(e)
	}
	// Copy back into array of bytes -- only need to worry about the bytes that were data
	// We don't care about errors in the error-correction codewords
	for i := 0; i < numDataCodewords; i++ {
		codewordBytes[i] = byte(codewordsInts[i])
	}
	return nil
}
