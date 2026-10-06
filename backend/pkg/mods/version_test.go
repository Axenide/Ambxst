package mods

import "testing"

func TestMatchesVersion(t *testing.T) {
	tests := []struct {
		version    string
		constraint string
		want       bool
	}{
		{"1.2.5", ">=1.2.0 <1.3.0", true},
		{"1.3.0", ">=1.2.0 <1.3.0", false},
		{"1.2.5", "=1.2.5", true},
		{"1.2", ">=1.0.0", false},
		{"1.2.5-dev", ">1.2.4", true},
	}
	for _, test := range tests {
		if got := matchesVersion(test.version, test.constraint); got != test.want {
			t.Errorf("matchesVersion(%q, %q) = %v, want %v", test.version, test.constraint, got, test.want)
		}
	}
}
