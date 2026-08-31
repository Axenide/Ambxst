package gozxing

type FormatException interface {
	ReaderException
	formatException()
}

type formatException struct {
	exception
}

func (formatException) readerException() {}
func (formatException) formatException() {}

func NewFormatException(args ...interface{}) FormatException {
	return formatException{
		newException("FormatException", args...),
	}
}

func WrapFormatException(e error) FormatException {
	return formatException{
		wrapException("FormatException", e),
	}
}
