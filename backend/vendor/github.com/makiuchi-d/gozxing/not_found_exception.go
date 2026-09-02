package gozxing

type NotFoundException interface {
	ReaderException
	notFoundException()
}

type notFoundException struct {
	exception
}

func (notFoundException) readerException()   {}
func (notFoundException) notFoundException() {}

func NewNotFoundException(args ...interface{}) NotFoundException {
	return notFoundException{
		newException("NotFoundException", args...),
	}
}

func WrapNotFoundException(e error) NotFoundException {
	return notFoundException{
		wrapException("NotFoundException", e),
	}
}
