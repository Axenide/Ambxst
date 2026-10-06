package encoder

import (
	"golang.org/x/text/encoding/charmap"

	"github.com/makiuchi-d/gozxing"
)

type EncoderContext struct {
	msg         []byte
	shape       SymbolShapeHint
	minSize     *gozxing.Dimension
	maxSize     *gozxing.Dimension
	codewords   []byte
	pos         int
	newEncoding int
	symbolInfo  *SymbolInfo
	skipAtEnd   int
}

func NewEncoderContext(msg string) (*EncoderContext, error) {
	//From this point on Strings are not Unicode anymore!
	msgBinary, e := charmap.ISO8859_1.NewEncoder().Bytes([]byte(msg))
	if e != nil {
		return nil, gozxing.NewWriterException(
			"Message contains characters outside ISO-8859-1 encoding. %v", e)
	}
	sb := make([]byte, 0, len(msgBinary))
	for i, c := 0, len(msgBinary); i < c; i++ {
		ch := msgBinary[i] & 0xff
		sb = append(sb, ch)
	}
	return &EncoderContext{
		msg:         sb, //Not Unicode here!
		shape:       SymbolShapeHint_FORCE_NONE,
		codewords:   make([]byte, 0, len(sb)),
		newEncoding: -1,
	}, nil
}

func (this *EncoderContext) SetSymbolShape(shape SymbolShapeHint) {
	this.shape = shape
}

func (this *EncoderContext) SetSizeConstraints(minSize, maxSize *gozxing.Dimension) {
	this.minSize = minSize
	this.maxSize = maxSize
}

func (this *EncoderContext) GetMessage() []byte {
	return this.msg
}

func (this *EncoderContext) SetSkipAtEnd(count int) {
	this.skipAtEnd = count
}

func (this *EncoderContext) GetCurrentChar() byte {
	return this.msg[this.pos]
}

func (this *EncoderContext) GetCurrent() byte {
	return this.msg[this.pos]
}

func (this *EncoderContext) GetCodewords() []byte {
	return this.codewords
}

func (this *EncoderContext) WriteCodewords(codewords []byte) {
	this.codewords = append(this.codewords, codewords...)
}

func (this *EncoderContext) WriteCodeword(codeword byte) {
	this.codewords = append(this.codewords, codeword)
}

func (this *EncoderContext) GetCodewordCount() int {
	return len(this.codewords)
}

func (this *EncoderContext) GetNewEncoding() int {
	return this.newEncoding
}

func (this *EncoderContext) SignalEncoderChange(encoding int) {
	this.newEncoding = encoding
}

func (this *EncoderContext) ResetEncoderSignal() {
	this.newEncoding = -1
}

func (this *EncoderContext) HasMoreCharacters() bool {
	return this.pos < this.getTotalMessageCharCount()
}

func (this *EncoderContext) getTotalMessageCharCount() int {
	return len(this.msg) - this.skipAtEnd
}

func (this *EncoderContext) GetRemainingCharacters() int {
	return this.getTotalMessageCharCount() - this.pos
}

func (this *EncoderContext) GetSymbolInfo() *SymbolInfo {
	return this.symbolInfo
}

func (this *EncoderContext) UpdateSymbolInfo() error {
	return this.UpdateSymbolInfoByLength(this.GetCodewordCount())
}

func (this *EncoderContext) UpdateSymbolInfoByLength(len int) error {
	var e error
	if this.symbolInfo == nil || len > this.symbolInfo.GetDataCapacity() {
		this.symbolInfo, e = SymbolInfo_Lookup(len, this.shape, this.minSize, this.maxSize, true)
	}
	return e
}

func (this *EncoderContext) ResetSymbolInfo() {
	this.symbolInfo = nil
}
