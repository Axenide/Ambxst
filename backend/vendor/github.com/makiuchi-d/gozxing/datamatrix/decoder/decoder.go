package decoder

import (
	"github.com/makiuchi-d/gozxing"
	"github.com/makiuchi-d/gozxing/common"
	"github.com/makiuchi-d/gozxing/common/reedsolomon"
)

// Decoder The main class which implements Data Matrix Code decoding
//  -- as opposed to locating and extracting the Data Matrix Code from an image.
//
type Decoder struct {
	rsDecoder *reedsolomon.ReedSolomonDecoder
}

func NewDecoder() *Decoder {
	return &Decoder{
		rsDecoder: reedsolomon.NewReedSolomonDecoder(reedsolomon.GenericGF_DATA_MATRIX_FIELD_256),
	}
}

// DecodeBoolMap Convenience method that can decode a Data Matrix Code represented as a 2D array of booleans.
// "true" is taken to mean a black module.
//
// @param image booleans representing white/black Data Matrix Code modules
// @return text and bytes encoded within the Data Matrix Code
// @throws FormatException if the Data Matrix Code cannot be decoded
// @throws ChecksumException if error correction fails
//
func (d *Decoder) DecodeBoolMap(image [][]bool) (*common.DecoderResult, error) {
	bits, e := gozxing.ParseBoolMapToBitMatrix(image)
	if e != nil {
		return nil, gozxing.WrapReaderException(e)
	}
	return d.Decode(bits)
}

// Decode Decodes a Data Matrix Code represented as a {@link BitMatrix}.
// A 1 or "true" is taken to mean a black module.
//
// @param bits booleans representing white/black Data Matrix Code modules
// @return text and bytes encoded within the Data Matrix Code
// @throws FormatException if the Data Matrix Code cannot be decoded
// @throws ChecksumException if error correction fails
//
func (d *Decoder) Decode(bits *gozxing.BitMatrix) (*common.DecoderResult, error) {

	// Construct a parser and read version, error-correction level
	parser, e := NewBitMatrixParser(bits)
	if e != nil {
		return nil, e
	}
	version := parser.GetVersion()

	// Read codewords
	// success if version is valid (always success here)
	codewords, _ := parser.readCodewords()

	// Separate into data blocks
	// success if version is valid (always success here)
	dataBlocks, _ := DataBlocks_getDataBlocks(codewords, version)

	// Count total number of data bytes
	totalBytes := 0
	for _, db := range dataBlocks {
		totalBytes += db.getNumDataCodewords()
	}
	resultBytes := make([]byte, totalBytes)

	dataBlocksCount := len(dataBlocks)
	// Error-correct and copy data blocks together into a stream of bytes
	for j := 0; j < dataBlocksCount; j++ {
		dataBlock := dataBlocks[j]
		codewordBytes := dataBlock.getCodewords()
		numDataCodewords := dataBlock.getNumDataCodewords()
		e := d.correctErrors(codewordBytes, numDataCodewords)
		if e != nil {
			return nil, e
		}
		for i := 0; i < numDataCodewords; i++ {
			// De-interlace data blocks.
			resultBytes[i*dataBlocksCount+j] = codewordBytes[i]
		}
	}

	// Decode the contents of that stream of bytes
	return DecodedBitStreamParser_decode(resultBytes)
}

// correctErrors Given data and error-correction codewords received, possibly corrupted by errors,
// attempts to correct the errors in-place using Reed-Solomon error correction.
//
// @param codewordBytes data and error correction codewords
// @param numDataCodewords number of codewords that are data bytes
// @throws ChecksumException if error correction fails
//
func (d *Decoder) correctErrors(codewordBytes []byte, numDataCodewords int) error {
	numCodewords := len(codewordBytes)
	// First read into an array of ints
	codewordsInts := make([]int, numCodewords)
	for i := 0; i < numCodewords; i++ {
		codewordsInts[i] = int(codewordBytes[i]) & 0xFF
	}
	e := d.rsDecoder.Decode(codewordsInts, len(codewordBytes)-numDataCodewords)
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
