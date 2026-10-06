package sql3util

import (
	"errors"

	"github.com/ncruces/go-sqlite3"
	"github.com/ncruces/go-sqlite3/internal/sqlite3_wrap"
)

// CodeToError converts a numeric error code to
// an [sqlite3.ErrorCode] or [sqlite3.ExtendedErrorCode].
func CodeToError(code int32) error {
	switch {
	case code == sqlite3_wrap.OK:
		return nil
	case code <= sqlite3_wrap.DONE:
		return sqlite3.ErrorCode(code)
	default:
		return sqlite3.ExtendedErrorCode(code)
	}
}

// ErrorToCode converts an SQLite error to
// its numeric error code.
func ErrorToCode(err error) int32 {
	switch code := err.(type) {
	case nil:
		return sqlite3_wrap.OK
	case sqlite3.ErrorCode:
		return int32(code)
	case sqlite3.ExtendedErrorCode:
		return int32(code)
	case *sqlite3.Error:
		return int32(code.Code())
	}

	if code, ok := errors.AsType[sqlite3.ExtendedErrorCode](err); ok {
		return int32(code)
	}
	return sqlite3_wrap.ERROR
}
