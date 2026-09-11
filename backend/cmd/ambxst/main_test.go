package main

import "testing"

func TestDefaultTMUXTmpDir(t *testing.T) {
	cases := []struct {
		name       string
		current    string
		xdgRuntime string
		want       string
	}{
		{"explicit wins", "/custom/tmux", "/run/user/1000", "/custom/tmux"},
		{"falls back to xdg", "", "/run/user/1000", "/run/user/1000"},
		{"nothing to set", "", "", ""},
		{"explicit without xdg", "/custom/tmux", "", "/custom/tmux"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := defaultTMUXTmpDir(tc.current, tc.xdgRuntime); got != tc.want {
				t.Fatalf("defaultTMUXTmpDir(%q, %q) = %q, want %q", tc.current, tc.xdgRuntime, got, tc.want)
			}
		})
	}
}
