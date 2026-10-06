package decoder

import (
	errors "golang.org/x/xerrors"
)

type DataBlock struct {
	numDataCodewords int
	codewords        []byte
}

func NewDataBlock(numDataCodewords int, codewords []byte) *DataBlock {
	return &DataBlock{
		numDataCodewords: numDataCodewords,
		codewords:        codewords,
	}
}

func DataBlock_GetDataBlocks(rawCodewords []byte, version *Version, ecLevel ErrorCorrectionLevel) ([]*DataBlock, error) {
	if len(rawCodewords) != version.GetTotalCodewords() {
		return nil, errors.Errorf(
			"IllegalArgumentException: len(rawCodewords)=%v, totalCodewords=%v",
			len(rawCodewords), version.GetTotalCodewords())
	}

	// Figure out the number and size of data blocks used by this version and
	// error correction level
	ecBlocks := version.GetECBlocksForLevel(ecLevel)

	// First count the total number of data blocks
	totalBlocks := 0
	ecBlockArray := ecBlocks.GetECBlocks()
	for _, ecBlock := range ecBlockArray {
		totalBlocks += ecBlock.GetCount()
	}

	// Now establish DataBlocks of the appropriate size and number of data codewords
	result := make([]*DataBlock, totalBlocks)
	numResultBlocks := 0
	for _, ecBlock := range ecBlockArray {
		for i := 0; i < ecBlock.GetCount(); i++ {
			numDataCodewords := ecBlock.GetDataCodewords()
			numBlockCodewords := ecBlocks.GetECCodewordsPerBlock() + numDataCodewords
			result[numResultBlocks] = NewDataBlock(numDataCodewords, make([]byte, numBlockCodewords))
			numResultBlocks++
		}
	}

	// All blocks have the same amount of data, except that the last n
	// (where n may be 0) have 1 more byte. Figure out where these start.
	shorterBlocksTotalCodewords := len(result[0].codewords)
	longerBlocksStartAt := len(result) - 1
	for longerBlocksStartAt >= 0 {
		numCodewords := len(result[longerBlocksStartAt].codewords)
		if numCodewords == shorterBlocksTotalCodewords {
			break
		}
		longerBlocksStartAt--
	}
	longerBlocksStartAt++

	shorterBlocksNumDataCodewords := shorterBlocksTotalCodewords - ecBlocks.GetECCodewordsPerBlock()
	// The last elements of result may be 1 element longer;
	// first fill out as many elements as all of them have
	rawCodewordsOffset := 0
	for i := 0; i < shorterBlocksNumDataCodewords; i++ {
		for j := 0; j < numResultBlocks; j++ {
			result[j].codewords[i] = rawCodewords[rawCodewordsOffset]
			rawCodewordsOffset++
		}
	}
	// Fill out the last data block in the longer ones
	for j := longerBlocksStartAt; j < numResultBlocks; j++ {
		result[j].codewords[shorterBlocksNumDataCodewords] = rawCodewords[rawCodewordsOffset]
		rawCodewordsOffset++
	}
	// Now add in error correction blocks
	max := len(result[0].codewords)
	for i := shorterBlocksNumDataCodewords; i < max; i++ {
		for j := 0; j < numResultBlocks; j++ {
			iOffset := i
			if j >= longerBlocksStartAt {
				iOffset = i + 1
			}
			result[j].codewords[iOffset] = rawCodewords[rawCodewordsOffset]
			rawCodewordsOffset++
		}
	}
	return result, nil
}

func (this *DataBlock) GetNumDataCodewords() int {
	return this.numDataCodewords
}

func (this *DataBlock) GetCodewords() []byte {
	return this.codewords
}
