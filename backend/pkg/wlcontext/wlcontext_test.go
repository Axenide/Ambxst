package wlcontext

import (
	"testing"
)

func TestConnectAndEnumerate(t *testing.T) {
	c, err := Connect()
	if err != nil {
		t.Skipf("Wayland not available in this environment: %v", err)
	}
	defer c.Close()

	if c.GammaManagerGlobal() == 0 {
		t.Log("zwlr_gamma_control_manager_v1 not advertised by this compositor")
	}
	out := c.Outputs()
	if len(out) == 0 {
		t.Log("no wl_output globals seen")
	} else {
		t.Logf("found %d wl_output(s)", len(out))
	}
}