// Package sql3util implements SQLite utilities.
package sql3util

import (
	"strings"
	"time"

	"github.com/ncruces/go-sqlite3/internal/util"
)

// Unquote unquotes a string.
//
// https://sqlite.org/lang_keywords.html
func Unquote(val string) string {
	if len(val) < 2 {
		return val
	}
	fst := val[0]
	lst := val[len(val)-1]
	rst := val[1 : len(val)-1]
	if fst == '[' && lst == ']' {
		return rst
	}
	if fst != lst {
		return val
	}
	var old, new string
	switch fst {
	default:
		return val
	case '`':
		old, new = "``", "`"
	case '"':
		old, new = `""`, `"`
	case '\'':
		old, new = `''`, `'`
	}
	return strings.ReplaceAll(rst, old, new)
}

// NamedArg splits an named arg into a key and value,
// around an equals sign.
// Spaces are trimmed around both key and value.
func NamedArg(arg string) (key, val string) {
	key, val, _ = strings.Cut(arg, "=")
	key = strings.TrimSpace(key)
	val = strings.TrimSpace(val)
	return
}

// ParseBool parses a boolean.
//
// https://sqlite.org/pragma.html#syntax
func ParseBool(s string) (b, ok bool) {
	return util.ParseBool(s)
}

// ParseFloat parses a decimal floating point number.
func ParseFloat(s string) (f float64, ok bool) {
	return util.ParseFloat(s)
}

// ParseTimeShift parses a time shift modifier,
// also the output of timediff.
//
// https://sqlite.org/lang_datefunc.html
func ParseTimeShift(s string) (years, months, days int, duration time.Duration, ok bool) {
	return util.ParseTimeShift(s)
}

// ValidPageSize returns true if s is a valid page size.
//
// https://sqlite.org/fileformat.html#pages
func ValidPageSize(s int) bool {
	return util.ValidPageSize(s)
}

// Affinity is the type affinity of a column.
//
// https://sqlite.org/datatype3.html#type_affinity
type Affinity byte

const (
	TEXT Affinity = iota
	NUMERIC
	INTEGER
	REAL
	BLOB
)

// GetAffinity determines the affinity of a column by the declared type of the column.
//
// https://sqlite.org/datatype3.html#determination_of_column_affinity
func GetAffinity(declType string) Affinity {
	if declType == "" {
		return BLOB
	}
	name := strings.ToUpper(declType)
	if strings.Contains(name, "INT") {
		return INTEGER
	}
	if strings.Contains(name, "CHAR") || strings.Contains(name, "CLOB") || strings.Contains(name, "TEXT") {
		return TEXT
	}
	if strings.Contains(name, "BLOB") {
		return BLOB
	}
	if strings.Contains(name, "REAL") || strings.Contains(name, "FLOA") || strings.Contains(name, "DOUB") {
		return REAL
	}
	return NUMERIC
}
