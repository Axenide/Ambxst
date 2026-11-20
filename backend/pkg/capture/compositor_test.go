package capture

import "testing"

func TestHyprlandVersionAtLeast(t *testing.T) {
	tests := []struct {
		version string
		want    bool
	}{
		{version: "0.56.2", want: false},
		{version: "0.57.0", want: true},
		{version: "0.57.1", want: true},
		{version: "1.0.0", want: true},
		{version: "invalid", want: false},
	}

	for _, test := range tests {
		t.Run(test.version, func(t *testing.T) {
			if got := hyprlandVersionAtLeast(test.version, 0, 57); got != test.want {
				t.Fatalf("hyprlandVersionAtLeast(%q) = %v, want %v", test.version, got, test.want)
			}
		})
	}
}
