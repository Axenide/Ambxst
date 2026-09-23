package main

import "testing"

func TestParseModURL(t *testing.T) {
	tests := []struct {
		name    string
		raw     string
		command string
		value   string
	}{
		{
			name:    "install repository",
			raw:     "ambxst://mods/install?source=https%3A%2F%2Fgithub.com%2Fexample%2Fmod.git",
			command: "install",
			value:   "https://github.com/example/mod.git",
		},
		{
			name:    "install GitHub directory",
			raw:     "AMBXST://MODS/install?source=https%3A%2F%2Fgithub.com%2Fexample%2Fmods%2Ftree%2Fmain%2Fpackage",
			command: "install",
			value:   "https://github.com/example/mods/tree/main/package",
		},
		{
			name:    "update installed mod",
			raw:     "ambxst://mods/update?id=org.example.clock",
			command: "update",
			value:   "org.example.clock",
		},
		{
			name:    "install SSH repository",
			raw:     "ambxst://mods/install?source=ssh%3A%2F%2Fgit%40github.com%2Fexample%2Fmod.git",
			command: "install",
			value:   "ssh://git@github.com/example/mod.git",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			action, err := parseModURL(tt.raw)
			if err != nil {
				t.Fatalf("parseModURL() error = %v", err)
			}
			if action.command != tt.command || action.value != tt.value {
				t.Fatalf("parseModURL() = %#v, want command %q and value %q", action, tt.command, tt.value)
			}
		})
	}
}

func TestParseModURLRejectsUnsafeOrAmbiguousInput(t *testing.T) {
	invalid := []string{
		"https://example.com/mod",
		"ambxst://other/install?source=https%3A%2F%2Fexample.com%2Fmod.git",
		"ambxst://mods/remove?id=org.example.clock",
		"ambxst://mods/install?source=%2Fhome%2Fuser%2Fmod.zip",
		"ambxst://mods/install?source=file%3A%2F%2F%2Ftmp%2Fmod.zip",
		"ambxst://mods/install?source=https%3A%2F%2Fexample.com%2Fa&source=https%3A%2F%2Fexample.com%2Fb",
		"ambxst://mods/install?source=https%3A%2F%2Fexample.com%2Fmod.git&extra=true",
		"ambxst://mods/update",
		"ambxst://mods/update?id=one&id=two",
		"ambxst://mods/update?id=org.example.clock#fragment",
	}
	for _, raw := range invalid {
		t.Run(raw, func(t *testing.T) {
			if action, err := parseModURL(raw); err == nil {
				t.Fatalf("parseModURL(%q) = %#v, want error", raw, action)
			}
		})
	}
}
