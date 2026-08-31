package encoder

func NewDataMatrixSymbolInfo144() *SymbolInfo {
	si := NewSymbolInfoRS(false, 1558, 620, 22, 22, 36, -1, 62)
	si.funcGetInterleavedBlockCount = datamatrixSymbolInfo144_getInterleavedBlockCount
	si.funcGetDataLengthForInterleavedBlock = datamatrixSymbolInfo144_getDataLengthForInterleavedBlock
	return si
}

func datamatrixSymbolInfo144_getInterleavedBlockCount(this *SymbolInfo) int {
	return 10
}

func datamatrixSymbolInfo144_getDataLengthForInterleavedBlock(this *SymbolInfo, index int) int {
	if index <= 8 {
		return 156
	}
	return 155
}
