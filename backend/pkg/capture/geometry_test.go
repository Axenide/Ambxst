package capture

import "testing"

func TestScaledRegionRectUsesProvidedOutputOrigin(t *testing.T) {
	x, y, width, height := scaledRegionRect(125, 70, 20, 10, 100, 50, 1.5)
	if x != 38 || y != 30 || width != 30 || height != 15 {
		t.Fatalf("scaledRegionRect() = %d,%d %dx%d, want 38,30 30x15", x, y, width, height)
	}
}
