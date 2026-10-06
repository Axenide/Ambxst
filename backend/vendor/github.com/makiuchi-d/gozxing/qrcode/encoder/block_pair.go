package encoder

type BlockPair struct {
	dataBytes            []byte
	errorCorrectionBytes []byte
}

func NewBlockPair(data []byte, errorCorrection []byte) *BlockPair {
	return &BlockPair{data, errorCorrection}
}

func (this *BlockPair) GetDataBytes() []byte {
	return this.dataBytes
}

func (this *BlockPair) GetErrorCorrectionBytes() []byte {
	return this.errorCorrectionBytes
}
