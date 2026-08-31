package svc

import (
	"encoding/json"
	"errors"
	"fmt"

	"ambxst/backend/pkg/ipc"
)

// RawParams is the raw JSON params payload type used by handlers.
type RawParams = json.RawMessage

func paramsGet(params RawParams, key string) string {
	if len(params) == 0 {
		return ""
	}
	var m map[string]any
	if json.Unmarshal(params, &m) != nil {
		return ""
	}
	v, _ := m[key].(string)
	return v
}

func paramsBool(params RawParams, key string, def bool) bool {
	if len(params) == 0 {
		return def
	}
	var m map[string]any
	if json.Unmarshal(params, &m) != nil {
		return def
	}
	v, ok := m[key].(bool)
	if !ok {
		return def
	}
	return v
}

func paramsInt(params RawParams, key string, def int) int {
	if len(params) == 0 {
		return def
	}
	var m map[string]any
	if json.Unmarshal(params, &m) != nil {
		return def
	}
	switch v := m[key].(type) {
	case float64:
		return int(v)
	case int:
		return v
	}
	return def
}

// subID generates a unique subscriber key per goroutine invocation.
func subID(sub *ipc.Subscriber) string {
	return fmt.Sprintf("%p", &sub)
}

func errorsNew(msg string) error { return errors.New(msg) }