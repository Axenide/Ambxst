//go:build linux

package systemmonitor

import (
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
)

type syscallStatfs = syscall.Statfs_t

func statfs(mount string, st *syscallStatfs) error {
	s := syscall.Statfs_t{}
	if err := syscall.Statfs(mount, &s); err != nil {
		return err
	}
	*st = s
	return nil
}

func nvidiaQuery(pciID string) (usage float64, temp int) {
	out, err := exec.Command("nvidia-smi", "-i", pciID,
		"--query-gpu=utilization.gpu,temperature.gpu",
		"--format=csv,noheader,nounits").Output()
	if err != nil {
		return 0, -1
	}
	parts := strings.Split(strings.TrimSpace(string(out)), ",")
	if len(parts) >= 2 {
		u, _ := strconv.ParseFloat(strings.TrimSpace(parts[0]), 64)
		t, _ := strconv.Atoi(strings.TrimSpace(parts[1]))
		return u, t
	}
	return 0, -1
}

func amdTemp(card string) int {
	base := filepath.Join("/sys/class/drm", card, "device/hwmon")
	entries, err := os.ReadDir(base)
	if err != nil || len(entries) == 0 {
		return -1
	}
	data, err := os.ReadFile(filepath.Join(base, entries[0].Name(), "temp1_input"))
	if err != nil {
		return -1
	}
	val, _ := strconv.Atoi(strings.TrimSpace(string(data)))
	return val / 1000
}