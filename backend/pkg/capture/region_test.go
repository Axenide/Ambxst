package capture

import (
	"testing"

	"ambxst/backend/pkg/axmon"
)

func TestRegionScalePrefersFrozenFrameFactor(t *testing.T) {
	resetSession()
	defer resetSession()

	frame := mustFrame(t, 2880, 1800)
	StoreSessionFrame("eDP-2", frame, func() { frame.Buffer.Close() })

	mon := axmon.Monitor{Name: "eDP-2", Width: 2880, Height: 1800, LogicalW: 1440, LogicalH: 900, Scale: 2}
	if got := regionScale(mon, "eDP-2"); got != 2.0 {
		t.Fatalf("regionScale = %v, want 2.0", got)
	}
}

func TestRegionScaleRejectsStaleFrozenFrame(t *testing.T) {
	resetSession()
	defer resetSession()

	// Frame from a previous layout: half the current physical size, so
	// the derived factor (1.0) disagrees with the compositor scale (2.0).
	frame := mustFrame(t, 1440, 900)
	StoreSessionFrame("eDP-2", frame, func() { frame.Buffer.Close() })

	mon := axmon.Monitor{Name: "eDP-2", Width: 2880, Height: 1800, LogicalW: 1440, LogicalH: 900, Scale: 2}
	if got := regionScale(mon, "eDP-2"); got != 2.0 {
		t.Fatalf("regionScale = %v, want 2.0 fallback", got)
	}
}

func TestRegionScaleFallbackWithoutFrozenFrame(t *testing.T) {
	resetSession()
	defer resetSession()

	mon := axmon.Monitor{Name: "DP-2", Width: 1920, Height: 1080, LogicalW: 1920, LogicalH: 1080, Scale: 1}
	if got := regionScale(mon, "DP-2"); got != 1.0 {
		t.Fatalf("regionScale = %v, want 1.0", got)
	}
}

func TestRegionScaleLegacyHyprlandDims(t *testing.T) {
	resetSession()
	defer resetSession()

	// Old bug repro: physical width/height from Hyprland fed directly as
	// logical extents made the frame factor collapse to ~1.0. Explicit
	// logical extents keep it at the real scale.
	frame := mustFrame(t, 2880, 1800)
	StoreSessionFrame("eDP-2", frame, func() { frame.Buffer.Close() })

	mon := axmon.Monitor{Name: "eDP-2", Width: 2880, Height: 1800, LogicalW: 1440, LogicalH: 900, Scale: 2}
	if got := regionScale(mon, "eDP-2"); got != 2.0 {
		t.Fatalf("regionScale = %v, want 2.0", got)
	}
}
