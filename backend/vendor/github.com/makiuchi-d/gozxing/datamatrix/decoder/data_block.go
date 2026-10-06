package decoder

import (
	"github.com/makiuchi-d/gozxing"
)

// DataBlock Encapsulates a block of data within a Data Matrix Code.
// Data Matrix Codes may split their data into multiple blocks,
// each of which is a unit of data and error-correction codewords.
// Each is represented by an instance of this class.
type DataBlock struct {
	numDataCodewords int
	codewords        []byte
}

// DataBlocks_getDataBlocks When Data Matrix Codes use multiple data blocks,
// they actually interleave the bytes of each of them.
// That is, the first byte of data block 1 to n is written, then the second bytes, and so on. This
// method will separate the data into original blocks.
//
// @param rawCodewords bytes as read directly from the Data Matrix Code
// @param version version of the Data Matrix Code
// @return DataBlocks containing original bytes, "de-interleaved" from representation in the Data Matrix Code
//
func DataBlocks_getDataBlocks(rawCodewords []byte, version *Version) ([]DataBlock, error) {
	// Figure out the number and size of data blocks used by this version
	ecBlocks := version.getECBlocks()

	// First count the total number of data blocks
	totalBlocks := 0
	ecBlockArray := ecBlocks.getECBlocks()
	for _, ecBlock := range ecBlockArray {
		totalBlocks += ecBlock.getCount()
	}

	// Now establish DataBlocks of the appropriate size and number of data codewords
	result := make([]DataBlock, totalBlocks)
	numResultBlocks := 0
	for _, ecBlock := range ecBlockArray {
		for i := 0; i < ecBlock.getCount(); i++ {
			numDataCodewords := ecBlock.getDataCodewords()
			numBlockCodewords := ecBlocks.getECCodewords() + numDataCodewords
			result[numResultBlocks].numDataCodewords = numDataCodewords
			result[numResultBlocks].codewords = make([]byte, numBlockCodewords)
			numResultBlocks++
		}
	}

	// All blocks have the same amount of data, except that the last n
	// (where n may be 0) have 1 less byte. Figure out where these start.
	// TODO(bbrown): There is only one case where there is a difference for Data Matrix for size 144
	longerBlocksTotalCodewords := len(result[0].codewords)
	// shorterBlocksTotalCodewords := longerBlocksTotalCodewords - 1

	longerBlocksNumDataCodewords := longerBlocksTotalCodewords - ecBlocks.getECCodewords()
	shorterBlocksNumDataCodewords := longerBlocksNumDataCodewords - 1
	// The last elements of result may be 1 element shorter for 144 matrix
	// first fill out as many elements as all of them have minus 1
	rawCodewordsOffset := 0
	for i := 0; i < shorterBlocksNumDataCodewords; i++ {
		for j := 0; j < numResultBlocks; j++ {
			result[j].codewords[i] = rawCodewords[rawCodewordsOffset]
			rawCodewordsOffset++
		}
	}

	// Fill out the last data block in the longer ones
	specialVersion := version.getVersionNumber() == 24
	numLongerBlocks := numResultBlocks
	if specialVersion {
		numLongerBlocks = 8
	}
	for j := 0; j < numLongerBlocks; j++ {
		result[j].codewords[longerBlocksNumDataCodewords-1] = rawCodewords[rawCodewordsOffset]
		rawCodewordsOffset++
	}

	// Now add in error correction blocks
	max := len(result[0].codewords)
	for i := longerBlocksNumDataCodewords; i < max; i++ {
		for j := 0; j < numResultBlocks; j++ {
			jOffset := j
			iOffset := i
			if specialVersion {
				jOffset = (j + 8) % numResultBlocks
				if jOffset > 7 {
					iOffset = i - 1
				}
			}
			result[jOffset].codewords[iOffset] = rawCodewords[rawCodewordsOffset]
			rawCodewordsOffset++
		}
	}

	if rawCodewordsOffset != len(rawCodewords) {
		return nil, gozxing.NewFormatException(
			"rawCodewordsOffset=%v, len(rawCodewords)=%v", rawCodewordsOffset, len(rawCodewords))
	}

	return result, nil
}

func (d *DataBlock) getNumDataCodewords() int {
	return d.numDataCodewords
}

func (d *DataBlock) getCodewords() []byte {
	return d.codewords
}
