package oned

func NewUPCEANWriter(enc encoder) *OneDimensionalCodeWriter {
	writer := NewOneDimensionalCodeWriter(enc)
	writer.defaultMargin = 9
	return writer
}
