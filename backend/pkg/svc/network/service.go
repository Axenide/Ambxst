package network

import (
	"bufio"
	"encoding/json"
	"os"
	"os/exec"
	"strconv"
	"strings"

	"ambxst/backend/pkg/ipc"
)

// Service wraps NetworkManager via the nmcli CLI (mirroring NetworkService.qml)
// and streams a state snapshot on every `nmcli monitor` event.
type Service struct {
	mu  chan struct{}
	stop chan struct{}
}

func NewService() *Service {
	return &Service{mu: make(chan struct{}, 1), stop: make(chan struct{})}
}

func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "network",
		Methods: map[string]ipc.HandlerFunc{
			"status":    s.status,
			"networks":  s.networks,
			"enable":    s.enable,
			"connect":   s.connect,
			"disconnect": s.disconnect,
		},
		Subscribe: s.subscribe,
	})
}

func (s *Service) Close() {
	select {
	case <-s.stop:
	default:
		close(s.stop)
	}
}

type state struct {
	Wifi          bool   `json:"wifi"`
	Ethernet      bool   `json:"ethernet"`
	WifiEnabled   bool   `json:"wifi_enabled"`
	WifiStatus    string `json:"wifi_status"`
	NetworkName   string `json:"network_name"`
	Strength      int    `json:"strength"`
	Connectivity  string `json:"connectivity"`
}

type apEntry struct {
	Active   bool   `json:"active"`
	Strength int    `json:"strength"`
	Frequency int   `json:"frequency"`
	SSID     string `json:"ssid"`
	BSSID    string `json:"bssid"`
	Security string `json:"security"`
}

// snapshot collects the same data NetworkService.qml reads via nmcli.
func (s *Service) snapshot() state {
	st := state{}

	// device statuses + connectivity
	out, _ := exec.Command("sh", "-c", "nmcli -t -f TYPE,STATE d status && nmcli -t -f CONNECTIVITY g").Output()
	lines := strings.Fields(string(out))
	if len(lines) > 0 {
		conn := lines[len(lines)-1]
		st.Connectivity = conn
		lines = lines[:len(lines)-1]
		for _, l := range lines {
			parts := strings.SplitN(l, ":", 2)
			if len(parts) != 2 {
				continue
			}
			typ, statev := parts[0], parts[1]
			switch typ {
			case "ethernet":
				if statev == "connected" {
					st.Ethernet = true
				}
			case "wifi":
				switch statev {
				case "connected":
					st.Wifi = true
					st.WifiStatus = "connected"
					if conn == "limited" {
						st.WifiStatus = "limited"
						st.Wifi = false
					}
				case "connecting":
					st.WifiStatus = "connecting"
				case "unavailable":
					st.WifiStatus = "disabled"
				}
			}
		}
	}

	// active connection name
	if out, err := exec.Command("sh", "-c", "nmcli -t -f NAME c show --active | head -1").Output(); err == nil {
		st.NetworkName = strings.TrimSpace(string(out))
	}

	// strength of in-use AP
	if out, err := exec.Command("sh", "-c", "nmcli -f IN-USE,SIGNAL,SSID device wifi | awk '/^\\*/{if (NR!=1) {print $2}}'").Output(); err == nil {
		if v, convErr := strconv.Atoi(strings.TrimSpace(string(out))); convErr == nil {
			st.Strength = v
		}
	}

	// radio
	if out, err := exec.Command("nmcli", "radio", "wifi").Output(); err == nil {
		st.WifiEnabled = strings.TrimSpace(string(out)) == "enabled"
	}

	if !st.Wifi && st.WifiStatus == "" && !st.Ethernet {
		st.WifiStatus = "disconnected"
	}
	return st
}

func (s *Service) status(params json.RawMessage) (any, error) {
	return s.snapshot(), nil
}

func (s *Service) networks(params json.RawMessage) (any, error) {
	return s.listNetworks(), nil
}

func (s *Service) listNetworks() []apEntry {
	out, err := exec.Command("nmcli", "-g", "ACTIVE,SIGNAL,FREQ,SSID,BSSID,SECURITY", "device", "wifi").Output()
	if err != nil {
		return nil
	}
	const placeholder = "STRINGWHICHWILLNEVERAPPEAR"
	seen := map[string]apEntry{}
	for _, line := range strings.Split(string(out), "\n") {
		line = strings.ReplaceAll(line, `\:`, placeholder)
		net := strings.Split(line, ":")
		if len(net) < 6 {
			continue
		}
		ssid := net[3]
		if ssid == "" {
			continue
		}
		entry := apEntry{
			Active:    strings.ReplaceAll(net[0], placeholder, ":") == "yes",
			Strength:  atoi(net[1]),
			Frequency: atoi(net[2]),
			SSID:      strings.ReplaceAll(ssid, placeholder, ":"),
			BSSID:     strings.ReplaceAll(net[4], placeholder, ":"),
			Security:  strings.ReplaceAll(net[5], placeholder, ":"),
		}
		if existing, ok := seen[entry.SSID]; !ok ||
			(entry.Active && !existing.Active) ||
			(!entry.Active && !existing.Active && entry.Strength > existing.Strength) {
			seen[entry.SSID] = entry
		}
	}
	out2 := make([]apEntry, 0, len(seen))
	for _, e := range seen {
		out2 = append(out2, e)
	}
	return out2
}

func (s *Service) enable(params json.RawMessage) (any, error) {
	var p struct {
		Enabled bool `json:"enabled"`
	}
	json.Unmarshal(params, &p)
	arg := "off"
	if p.Enabled {
		arg = "on"
	}
	exec.Command("nmcli", "radio", "wifi", arg).Run()
	return s.snapshot(), nil
}

func (s *Service) connect(params json.RawMessage) (any, error) {
	var p struct {
		SSID     string `json:"ssid"`
		Password string `json:"password"`
	}
	json.Unmarshal(params, &p)
	if p.SSID == "" {
		return map[string]any{"error": "missing ssid"}, nil
	}
	if p.Password != "" {
		cmd := exec.Command("bash", "-c", `nmcli connection modify "`+p.SSID+`" wifi-sec.psk "$PASSWORD"`)
		cmd.Env = append(os.Environ(), "PASSWORD="+p.Password)
		cmd.Run()
	}
	if err := exec.Command("nmcli", "dev", "wifi", "connect", p.SSID).Run(); err != nil {
		out, _ := exec.Command("nmcli", "dev", "wifi", "connect", p.SSID).CombinedOutput()
		if strings.Contains(string(out), "Secrets were required") {
			return map[string]any{"need_password": true}, nil
		}
		return map[string]any{"error": strings.TrimSpace(string(out))}, nil
	}
	return s.snapshot(), nil
}

func (s *Service) disconnect(params json.RawMessage) (any, error) {
	var p struct {
		SSID string `json:"ssid"`
	}
	json.Unmarshal(params, &p)
	if p.SSID != "" {
		exec.Command("nmcli", "connection", "down", p.SSID).Run()
	}
	return s.snapshot(), nil
}

// subscribe emits a full state snapshot once, then on every nmcli monitor event.
func (s *Service) subscribe(sub *ipc.Subscriber) {
	sub.Send("network.state", s.snapshot())
	monitor := exec.Command("nmcli", "monitor")
	stdout, err := monitor.StdoutPipe()
	if err != nil {
		return
	}
	if err := monitor.Start(); err != nil {
		return
	}
	defer monitor.Process.Kill()
	sc := bufio.NewScanner(stdout)
	for sc.Scan() {
		select {
		case <-sub.StopCh():
			return
		default:
		}
		sub.Send("network.state", s.snapshot())
	}
}

func atoi(s string) int {
	v, _ := strconv.Atoi(strings.TrimSpace(s))
	return v
}
