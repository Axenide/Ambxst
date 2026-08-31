package gozxing

import (
	errors "golang.org/x/xerrors"
)

type BinaryBitmap struct {
	binarizer Binarizer
	matrix    *BitMatrix
}

func NewBinaryBitmap(binarizer Binarizer) (*BinaryBitmap, error) {
	if binarizer == nil {
		return nil, errors.New("IllegalArgumentException: Binarizer must be non-null")
	}
	return &BinaryBitmap{binarizer, nil}, nil
}

func (this *BinaryBitmap) GetWidth() int {
	return this.binarizer.GetWidth()
}

func (this *BinaryBitmap) GetHeight() int {
	return this.binarizer.GetHeight()
}

func (this *BinaryBitmap) GetBlackRow(y int, row *BitArray) (*BitArray, error) {
	return this.binarizer.GetBlackRow(y, row)
}

func (this *BinaryBitmap) GetBlackMatrix() (*BitMatrix, error) {
	// The matrix is created on demand the first time it is requested, then cached. There are two
	// reasons for this:
	// 1. This work will never be done if the caller only installs 1D Reader objects, or if a
	//    1D Reader finds a barcode before the 2D Readers run.
	// 2. This work will only be done once even if the caller installs multiple 2D Readers.
	if this.matrix == nil {
		var e error
		this.matrix, e = this.binarizer.GetBlackMatrix()
		if e != nil {
			return nil, e
		}
	}
	return this.matrix, nil
}

func (this *BinaryBitmap) IsCropSupported() bool {
	return this.binarizer.GetLuminanceSource().IsCropSupported()
}

func (this *BinaryBitmap) Crop(left, top, width, height int) (*BinaryBitmap, error) {
	newSource, e := this.binarizer.GetLuminanceSource().Crop(left, top, width, height)
	if e != nil {
		return nil, e
	}
	return NewBinaryBitmap(this.binarizer.CreateBinarizer(newSource))
}

func (this *BinaryBitmap) IsRotateSupported() bool {
	return this.binarizer.GetLuminanceSource().IsRotateSupported()
}

func (this *BinaryBitmap) RotateCounterClockwise() (*BinaryBitmap, error) {
	newSource, e := this.binarizer.GetLuminanceSource().RotateCounterClockwise()
	if e != nil {
		return nil, e
	}
	return NewBinaryBitmap(this.binarizer.CreateBinarizer(newSource))
}

func (this *BinaryBitmap) RotateCounterClockwise45() (*BinaryBitmap, error) {
	newSource, e := this.binarizer.GetLuminanceSource().RotateCounterClockwise45()
	if e != nil {
		return nil, e
	}
	return NewBinaryBitmap(this.binarizer.CreateBinarizer(newSource))
}

func (this *BinaryBitmap) String() string {
	matrix, e := this.GetBlackMatrix()
	if e != nil {
		if _, ok := e.(NotFoundException); ok {
			return ""
		}
		return e.Error()
	}
	return matrix.String()
}
