package clipboard

import "testing"

// The reconnect window: when the Wayland display errors, run()'s teardown
// nils manager/device while the wlClient stays registered on the service,
// so IPC handlers can reach the copy paths with no live connection. These
// paths must return errors instead of dereferencing the nil proxies.

func TestCopyContentWithoutConnectionReturnsError(t *testing.T) {
	w := &wlClient{}
	if err := w.copyContent("text/plain;charset=utf-8", []byte("hello")); err == nil {
		t.Fatal("expected an error when the wayland connection is down")
	}
}

func TestCopyTextAwaitWithoutConnectionReturnsFalse(t *testing.T) {
	w := &wlClient{}
	if w.copyTextAwait("text/plain;charset=utf-8", []byte("hello")) {
		t.Fatal("expected no confirmation when the wayland connection is down")
	}
}

func TestClearSelectionWithoutConnectionIsSafe(t *testing.T) {
	w := &wlClient{}
	w.clearSelection()
}
