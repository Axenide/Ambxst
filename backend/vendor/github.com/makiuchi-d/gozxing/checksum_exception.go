package gozxing

type ChecksumException interface {
	ReaderException
	checksumException()
}

type checksumException struct {
	exception
}

func (checksumException) readerException()   {}
func (checksumException) checksumException() {}

func NewChecksumException(args ...interface{}) ChecksumException {
	return checksumException{
		newException("ChecksumException", args...),
	}
}

func WrapChecksumException(e error) ChecksumException {
	return checksumException{
		wrapException("ChecksumException", e),
	}
}
