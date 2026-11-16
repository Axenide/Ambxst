package compositor

import (
	"encoding/json"
	"net"
	"path/filepath"
	"testing"
	"time"
)

func TestCallRetriesUntilAxctlSocketAppears(t *testing.T) {
	runtimeDir := t.TempDir()
	t.Setenv("XDG_RUNTIME_DIR", runtimeDir)
	manager := NewManager(nil)
	t.Cleanup(func() {
		manager.rpcMu.Lock()
		if manager.rpcConn != nil {
			_ = manager.rpcConn.Close()
		}
		manager.rpcMu.Unlock()
	})

	type callResult struct {
		result json.RawMessage
		err    error
	}
	callDone := make(chan callResult, 1)
	go func() {
		result, err := manager.Call("Application.List", map[string]any{})
		callDone <- callResult{result: result, err: err}
	}()

	time.Sleep(2 * socketWaitStep)
	listener, err := net.Listen("unix", filepath.Join(runtimeDir, "axctl.sock"))
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()

	conn, err := listener.Accept()
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	var request struct {
		Method string `json:"method"`
	}
	if err := json.NewDecoder(conn).Decode(&request); err != nil {
		t.Fatal(err)
	}
	if request.Method != "Application.List" {
		t.Fatalf("method = %q, want Application.List", request.Method)
	}
	if err := json.NewEncoder(conn).Encode(map[string]any{
		"id":     1,
		"result": map[string]bool{"ready": true},
	}); err != nil {
		t.Fatal(err)
	}

	result := <-callDone
	if result.err != nil {
		t.Fatal(result.err)
	}
	var payload map[string]bool
	if err := json.Unmarshal(result.result, &payload); err != nil {
		t.Fatal(err)
	}
	if !payload["ready"] {
		t.Fatalf("unexpected result: %s", result.result)
	}
}
