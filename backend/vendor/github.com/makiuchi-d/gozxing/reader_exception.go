package gozxing

import (
	"fmt"

	errors "golang.org/x/xerrors"
)

type ReaderException interface {
	error
	readerException()
}

type readerException struct {
	exception
}

func WrapReaderException(e error) ReaderException {
	return readerException{
		wrapException("ReaderException", e),
	}
}

func (readerException) readerException() {}

type exception struct {
	msg   string
	next  error
	frame errors.Frame
}

func newException(prefix string, args ...interface{}) exception {
	msg := prefix
	if len(args) > 0 {
		msg += ": " + fmt.Sprintf(args[0].(string), args[1:]...)
	}
	return exception{
		msg,
		nil,
		errors.Caller(2),
	}
}

func wrapException(msg string, next error) exception {
	return exception{
		msg,
		next,
		errors.Caller(2),
	}
}

func (e exception) Error() string {
	return e.msg
}

func (e exception) Unwrap() error {
	return e.next
}

func (e exception) Format(s fmt.State, v rune) {
	errors.FormatError(e, s, v)
}

func (e exception) FormatError(p errors.Printer) error {
	p.Print(e.msg)
	e.frame.Format(p)
	return e.next
}
