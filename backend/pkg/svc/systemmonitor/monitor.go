package systemmonitor

import (
	"bufio"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"sync"
)

// StaticInfo is the one-time detected hardware info.
type StaticInfo struct {
	CPUModel   string `json:"cpu_model"`
	GPUNames   []string `json:"gpu_names"`
	GPUVendors []string `json:"gpu_vendors"`
	DiskTypes  map[string]string `json:"disk_types"`
	GPUCount   int    `json:"gpu_count"`
}

// Delta holds a sample of live metrics.
type Delta struct {
	CPU  CPU   `json:"cpu"`
	RAM  RAM   `json:"ram"`
	Disk Disk  `json:"disk"`
	GPU  GPU   `json:"gpu"`
}

type CPU struct {
	Usage float64 `json:"usage"`
	Temp  int     `json:"temp"`
}

type RAM struct {
	Usage     float64 `json:"usage"`
	Total     int64   `json:"total"`
	Used      int64   `json:"used"`
	Available int64   `json:"available"`
}

type Disk struct {
	Usage map[string]float64 `json:"usage"`
}

type GPU struct {
	Detected bool      `json:"detected"`
	Count    int       `json:"count"`
	Usages   []float64 `json:"usages"`
	Temps    []int     `json:"temps"`
}

// GPUInfo describes a detected GPU.
type GPUInfo struct {
	Vendor    string `json:"vendor"`
	Name      string `json:"name"`
	Card      string `json:"card,omitempty"`
	PCIID     string `json:"pci_id,omitempty"`
	PowerPath string `json:"power_path,omitempty"`
}

type Monitor struct {
	mu        sync.RWMutex
	disks     []string
	prevTotal int64
	prevIdle  int64
	cpuModel  string
	gpuInfo   []GPUInfo
	diskTypes map[string]string
	updateMS  int
}

func NewMonitor(disks []string, updateMS int) *Monitor {
	if len(disks) == 0 {
		disks = []string{"/"}
	}
	m := &Monitor{
		disks:    disks,
		cpuModel: detectCPUModel(),
		gpuInfo:  detectGPUs(),
		updateMS: updateMS,
	}
	m.diskTypes = m.detectDiskTypes()
	return m
}

func (m *Monitor) Static() StaticInfo {
	m.mu.RLock()
	names := make([]string, 0, len(m.gpuInfo))
	vendors := make([]string, 0, len(m.gpuInfo))
	for _, g := range m.gpuInfo {
		names = append(names, g.Name)
		vendors = append(vendors, g.Vendor)
	}
	diskTypes := make(map[string]string, len(m.diskTypes))
	for k, v := range m.diskTypes {
		diskTypes[k] = v
	}
	gpuCount := len(m.gpuInfo)
	m.mu.RUnlock()
	return StaticInfo{
		CPUModel:   m.cpuModel,
		GPUNames:   names,
		GPUVendors: vendors,
		DiskTypes:  diskTypes,
		GPUCount:   gpuCount,
	}
}

// UpdateMS returns the configured sample interval.
func (m *Monitor) UpdateMS() int {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.updateMS
}

// SetUpdateMS changes the sample interval.
func (m *Monitor) SetUpdateMS(ms int) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if ms > 0 {
		m.updateMS = ms
	}
}

// SetDisks changes the monitored mounts and re-detects their types.
func (m *Monitor) SetDisks(disks []string) {
	if len(disks) == 0 {
		return
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	m.disks = disks
	m.diskTypes = m.detectDiskTypes()
}

func (m *Monitor) detectDiskTypes() map[string]string {
	types := map[string]string{}
	for _, mount := range m.disks {
		types[mount] = "unknown"
		if dev := deviceForMount(mount); dev != "" {
			base := strings.TrimPrefix(dev, "/dev/")
			base = regexp.MustCompile(`p?[0-9]+$`).ReplaceAllString(base, "")
			p := filepath.Join("/sys/block", base, "queue/rotational")
			if data, err := os.ReadFile(p); err == nil {
				if strings.TrimSpace(string(data)) == "1" {
					types[mount] = "hdd"
				} else {
					types[mount] = "ssd"
				}
			}
		}
	}
	return types
}

func deviceForMount(mount string) string {
	f, err := os.Open("/proc/mounts")
	if err != nil {
		return ""
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		parts := strings.Fields(sc.Text())
		if len(parts) >= 2 && parts[1] == mount {
			return parts[0]
		}
	}
	return ""
}

func detectCPUModel() string {
	f, err := os.Open("/proc/cpuinfo")
	if err != nil {
		return "Unknown CPU"
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	reSpace := regexp.MustCompile(`\s+`)
	reSuffix := regexp.MustCompile(` (?i:(CPU|FPU|APU|Processor|Dual-Core|Quad-Core|Six-Core|Eight-Core|Ten-Core|[0-9]+-Core))$`)
	reRadeon := regexp.MustCompile(`(?i)\s+(w/|with)\s+Radeon.*$`)
	reAt := regexp.MustCompile(`\s+@.*$`)
	for sc.Scan() {
		line := sc.Text()
		if strings.HasPrefix(line, "model name") {
			model := strings.TrimSpace(strings.SplitN(line, ":", 2)[1])
			model = reSuffix.ReplaceAllString(model, "")
			model = reRadeon.ReplaceAllString(model, "")
			model = reAt.ReplaceAllString(model, "")
			model = reSpace.ReplaceAllString(strings.TrimSpace(model), " ")
			return model
		}
	}
	return "Unknown CPU"
}

func detectGPUs() []GPUInfo {
	var gpus []GPUInfo
	// NVIDIA
	base := "/proc/driver/nvidia/gpus"
	if entries, err := os.ReadDir(base); err == nil {
		for _, e := range entries {
			info := filepath.Join(base, e.Name(), "information")
			gpu := GPUInfo{Vendor: "nvidia", Name: "NVIDIA GPU", PCIID: e.Name()}
			if data, err := os.ReadFile(info); err == nil {
				sc := bufio.NewScanner(strings.NewReader(string(data)))
				for sc.Scan() {
					if strings.HasPrefix(sc.Text(), "Model:") {
						gpu.Name = strings.TrimSpace(strings.SplitN(sc.Text(), ":", 2)[1])
					}
				}
			}
			powerPath := filepath.Join("/sys/bus/pci/devices", e.Name(), "power/runtime_status")
			if _, err := os.Stat(powerPath); err == nil {
				gpu.PowerPath = powerPath
			}
			gpus = append(gpus, gpu)
		}
	}
	// DRM cards
	drmBase := "/sys/class/drm"
	if entries, err := os.ReadDir(drmBase); err == nil {
		for _, e := range entries {
			if !strings.HasPrefix(e.Name(), "card") || strings.Contains(e.Name(), "-") {
				continue
			}
			vendorPath := filepath.Join(drmBase, e.Name(), "device/vendor")
			data, err := os.ReadFile(vendorPath)
			if err != nil {
				continue
			}
			vendor := strings.ToLower(strings.TrimSpace(string(data)))
			switch vendor {
			case "0x1002":
				gpus = append(gpus, GPUInfo{Vendor: "amd", Name: "AMD GPU " + strings.TrimPrefix(e.Name(), "card"), Card: e.Name()})
			case "0x8086":
				gpus = append(gpus, GPUInfo{Vendor: "intel", Name: "Intel GPU " + strings.TrimPrefix(e.Name(), "card"), Card: e.Name()})
			}
		}
	}
	return gpus
}

// Sample computes one delta.
func (m *Monitor) Sample() Delta {
	cpuUsage, newTotal, newIdle := m.sampleCPU()
	m.prevTotal, m.prevIdle = newTotal, newIdle
	ramUsage, ramTotal, ramUsed, ramAvail := m.sampleMem()
	diskUsage := m.sampleDisks()
	gpuUsages, gpuTemps := m.sampleGPU()
	return Delta{
		CPU:  CPU{Usage: cpuUsage, Temp: m.sampleCPUTemp()},
		RAM:  RAM{Usage: ramUsage, Total: ramTotal, Used: ramUsed, Available: ramAvail},
		Disk: Disk{Usage: diskUsage},
		GPU:  GPU{Detected: len(m.gpuInfo) > 0, Count: len(m.gpuInfo), Usages: gpuUsages, Temps: gpuTemps},
	}
}

func (m *Monitor) sampleCPU() (usage float64, total, idle int64) {
	data, err := os.ReadFile("/proc/stat")
	if err != nil {
		return 0, m.prevTotal, m.prevIdle
	}
	line := strings.SplitN(string(data), "\n", 2)[0]
	if !strings.HasPrefix(line, "cpu ") {
		return 0, m.prevTotal, m.prevIdle
	}
	fields := strings.Fields(line)
	values := make([]int64, 0, len(fields)-1)
	for _, f := range fields[1:] {
		v, _ := strconv.ParseInt(f, 10, 64)
		values = append(values, v)
	}
	var sum int64
	for _, v := range values {
		sum += v
	}
	if len(values) >= 5 {
		idle = values[3] + values[4]
	}
	total = sum
	diffIdle := idle - m.prevIdle
	diffTotal := total - m.prevTotal
	if diffTotal <= 0 {
		return 0, total, idle
	}
	return float64(diffTotal-diffIdle) * 100 / float64(diffTotal), total, idle
}

func (m *Monitor) sampleCPUTemp() int {
	base := "/sys/class/hwmon"
	entries, err := os.ReadDir(base)
	if err != nil {
		return -1
	}
	for _, e := range entries {
		path := filepath.Join(base, e.Name())
		nameData, err := os.ReadFile(filepath.Join(path, "name"))
		if err != nil {
			continue
		}
		name := strings.TrimSpace(string(nameData))
		if !isCpuTempDriver(name) {
			continue
		}
		items, _ := os.ReadDir(path)
		for _, it := range items {
			if strings.HasPrefix(it.Name(), "temp") && strings.HasSuffix(it.Name(), "_input") {
				data, err := os.ReadFile(filepath.Join(path, it.Name()))
				if err != nil {
					continue
				}
				val, _ := strconv.Atoi(strings.TrimSpace(string(data)))
				if val > 10000 && val < 120000 {
					return val / 1000
				}
			}
		}
	}
	return -1
}

func isCpuTempDriver(name string) bool {
	switch name {
	case "coretemp", "k10temp", "zenpower", "cpu_thermal", "x86_pkg_temp", "amd_energy":
		return true
	}
	return false
}

func (m *Monitor) sampleMem() (usage float64, total, used, available int64) {
	data, err := os.ReadFile("/proc/meminfo")
	if err != nil {
		return 0, 0, 0, 0
	}
	sc := bufio.NewScanner(strings.NewReader(string(data)))
	for sc.Scan() {
		fields := strings.Fields(sc.Text())
		if len(fields) < 2 {
			continue
		}
		val, _ := strconv.ParseInt(fields[1], 10, 64)
		switch fields[0] {
		case "MemTotal:":
			total = val
		case "MemAvailable:":
			available = val
		}
		if total > 0 && available > 0 {
			break
		}
	}
	if total == 0 {
		return 0, 0, 0, 0
	}
	used = total - available
	return float64(used) * 100 / float64(total), total, used, available
}

func (m *Monitor) sampleDisks() map[string]float64 {
	m.mu.RLock()
	disks := append([]string(nil), m.disks...)
	m.mu.RUnlock()
	usage := map[string]float64{}
	for _, mount := range disks {
		usage[mount] = diskUsage(mount)
	}
	return usage
}

func diskUsage(mount string) float64 {
	var st syscallStatfs
	if err := statfs(mount, &st); err != nil {
		return 0
	}
	total := st.Blocks * uint64(st.Frsize)
	if total == 0 {
		return 0
	}
	used := total - (st.Bavail * uint64(st.Frsize))
	return float64(used) * 100 / float64(total)
}

func (m *Monitor) sampleGPU() (usages []float64, temps []int) {
	for _, g := range m.gpuInfo {
		u, t := 0.0, -1
		switch g.Vendor {
		case "nvidia":
			if g.PowerPath != "" {
				data, err := os.ReadFile(g.PowerPath)
				if err == nil && strings.TrimSpace(string(data)) != "active" {
					usages = append(usages, 0.0)
					temps = append(temps, -1)
					continue
				}
			}
			u, t = nvidiaQuery(g.PCIID)
		case "amd":
			if data, err := os.ReadFile(filepath.Join("/sys/class/drm", g.Card, "device/gpu_busy_percent")); err == nil {
				u, _ = strconv.ParseFloat(strings.TrimSpace(string(data)), 64)
			}
			t = amdTemp(g.Card)
		case "intel":
		}
		usages = append(usages, u)
		temps = append(temps, t)
	}
	return
}