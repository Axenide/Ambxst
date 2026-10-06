package oned

import (
	"github.com/makiuchi-d/gozxing"
)

var extensionStartPattern = []int{1, 1, 2}

type UPCEANExtensionSupport struct {
	twoSupport  *UPCEANExtension2Support
	fiveSupport *UPCEANExtension5Support
}

func NewUPCEANExtensionSupport() *UPCEANExtensionSupport {
	return &UPCEANExtensionSupport{
		twoSupport:  NewUPCEANExtension2Support(),
		fiveSupport: NewUPCEANExtension5Support(),
	}
}

func (this *UPCEANExtensionSupport) decodeRow(rowNumber int, row *gozxing.BitArray, rowOffset int) (*gozxing.Result, error) {
	extensionStartRange, e := upceanReader_findGuardPattern(row, rowOffset, false, extensionStartPattern)
	if e != nil {
		return nil, e
	}

	result, e := this.fiveSupport.decodeRow(rowNumber, row, extensionStartRange)
	if e == nil {
		return result, nil
	}
	if _, ok := e.(gozxing.ReaderException); ok {
		result, e = this.twoSupport.decodeRow(rowNumber, row, extensionStartRange)
		if e == nil {
			return result, nil
		}
	}
	return nil, e
}
