package capture

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"sync"
)

var hyprlandLogicalFramesOnce sync.Once
var hyprlandLogicalFramesValue bool

func hyprlandLogicalFrames() bool {
	hyprlandLogicalFramesOnce.Do(func() {
		if strings.TrimSpace(os.Getenv("HYPRLAND_INSTANCE_SIGNATURE")) == "" {
			return
		}

		output, err := exec.Command("hyprctl", "-j", "version").Output()
		if err != nil {
			return
		}

		var version struct {
			Version string `json:"version"`
		}
		if json.Unmarshal(output, &version) != nil {
			return
		}
		hyprlandLogicalFramesValue = hyprlandVersionAtLeast(version.Version, 0, 57)
	})
	return hyprlandLogicalFramesValue
}

func hyprlandVersionAtLeast(version string, major, minor int) bool {
	version = strings.TrimPrefix(version, "v")
	var actualMajor, actualMinor int
	if _, err := fmt.Sscanf(version, "%d.%d", &actualMajor, &actualMinor); err != nil {
		return false
	}
	if actualMajor != major {
		return actualMajor > major
	}
	return actualMinor >= minor
}
