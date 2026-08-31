package gozxing

type InvertedLuminanceSource struct {
	LuminanceSource
}

func NewInvertedLuminanceSource(delegate LuminanceSource) LuminanceSource {
	return &InvertedLuminanceSource{delegate}
}

func (this *InvertedLuminanceSource) GetRow(y int, row []byte) ([]byte, error) {
	var e error
	row, e = this.LuminanceSource.GetRow(y, row)
	if e != nil {
		return row, e
	}
	width := this.GetWidth()
	for i := 0; i < width; i++ {
		row[i] = 255 - (row[i] & 0xff)
	}
	return row, nil
}

func (this *InvertedLuminanceSource) GetMatrix() []byte {
	matrix := this.LuminanceSource.GetMatrix()
	length := this.GetWidth() * this.GetHeight()
	invertedMatrix := make([]byte, length)
	for i := 0; i < length; i++ {
		invertedMatrix[i] = 255 - (matrix[i] & 0xff)
	}
	return invertedMatrix
}

func (this *InvertedLuminanceSource) Crop(left, top, width, height int) (LuminanceSource, error) {
	cropped, e := this.LuminanceSource.Crop(left, top, width, height)
	if e != nil {
		return nil, e
	}
	return NewInvertedLuminanceSource(cropped), nil
}

func (this *InvertedLuminanceSource) Invert() LuminanceSource {
	return this.LuminanceSource
}

func (this *InvertedLuminanceSource) RotateCounterClockwise() (LuminanceSource, error) {
	rotated, e := this.LuminanceSource.RotateCounterClockwise()
	if e != nil {
		return nil, e
	}
	return NewInvertedLuminanceSource(rotated), nil
}

func (this *InvertedLuminanceSource) RotateCounterClockwise45() (LuminanceSource, error) {
	rotated, e := this.LuminanceSource.RotateCounterClockwise45()
	if e != nil {
		return nil, e
	}
	return NewInvertedLuminanceSource(rotated), nil
}

func (this *InvertedLuminanceSource) String() string {
	return LuminanceSourceString(this)
}
