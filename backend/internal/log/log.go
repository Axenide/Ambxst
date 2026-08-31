package log

import (
	"fmt"
	stdlog "log"
	"strings"
)

// Package log is a minimal stand-in for DankMaterialShell's internal/log
// surface, mapping to the standard library logger. Debug output is dropped.

func format(msg any, keyvals ...any) string {
	var b strings.Builder
	fmt.Fprintf(&b, "%v", msg)
	for i := 0; i+1 < len(keyvals); i += 2 {
		fmt.Fprintf(&b, " %v=%v", keyvals[i], keyvals[i+1])
	}
	return b.String()
}

func Debug(any, ...any) {}

func Info(msg any, keyvals ...any)  { stdlog.Print(format(msg, keyvals...)) }
func Warn(msg any, keyvals ...any)  { stdlog.Print(format(msg, keyvals...)) }
func Error(msg any, keyvals ...any) { stdlog.Print(format(msg, keyvals...)) }
