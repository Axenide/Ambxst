package encoder

type Encoder interface {
	getEncodingMode() int
	encode(context *EncoderContext) error
}
