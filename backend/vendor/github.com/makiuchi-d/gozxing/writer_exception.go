package gozxing

type WriterException interface {
	error
	writerException()
}

type writerException struct {
	exception
}

func (writerException) writerException() {}

func NewWriterException(args ...interface{}) WriterException {
	return writerException{
		newException("WriterException", args...),
	}
}

func WrapWriterException(err error) WriterException {
	return writerException{
		wrapException("WriterException", err),
	}
}
