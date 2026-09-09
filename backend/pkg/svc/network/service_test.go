package network

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"testing"
)

func TestMain(m *testing.M) {
	if os.Getenv("AUDIT_STUB") == "1" {
		switch filepath.Base(os.Args[0]) {
		case "nmcli":
			if log := os.Getenv("AUDIT_NMCLI_LOG"); log != "" {
				if f, err := os.OpenFile(log, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o600); err == nil {
					_ = json.NewEncoder(f).Encode(os.Args[1:])
					_ = f.Close()
				}
			}
			if len(os.Args) > 1 && os.Args[1] == "-g" {
				fmt.Println(os.Getenv("AUDIT_SCAN_LINE"))
			}
			os.Exit(0)
		}
	}
	os.Exit(m.Run())
}

func shortMarkerDir(t *testing.T) string {
	t.Helper()
	dir, err := os.MkdirTemp("/tmp", "asv-")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.RemoveAll(dir) })
	return dir
}

func TestScanSurvivesMaliciousSSID(t *testing.T) {
	stubDir := t.TempDir()
	exe, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(exe, filepath.Join(stubDir, "nmcli")); err != nil {
		t.Fatal(err)
	}

	markerDir := shortMarkerDir(t)
	ssid := "$(touch " + filepath.Join(markerDir, "m") + ")"
	if len(ssid) > 32 {
		t.Fatalf("SSID exceeds the 32-byte 802.11 limit: %d bytes", len(ssid))
	}
	scan := "no:87:5180:" + ssid + ":02\\:00\\:00\\:00\\:00\\:00:WPA2"

	t.Setenv("PATH", stubDir+":"+os.Getenv("PATH"))
	t.Setenv("AUDIT_STUB", "1")
	t.Setenv("AUDIT_SCAN_LINE", scan)
	t.Setenv("AUDIT_NMCLI_LOG", "")

	svc := NewService()
	found := false
	for _, n := range svc.listNetworks() {
		if n.SSID == ssid {
			found = true
		}
	}
	if !found {
		t.Fatal("malicious broadcast SSID did not survive nmcli -g parsing into the scan list")
	}
}

func TestConnectNeverInterpolatesSSIDIntoShell(t *testing.T) {
	stubDir := t.TempDir()
	exe, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(exe, filepath.Join(stubDir, "nmcli")); err != nil {
		t.Fatal(err)
	}

	markerDir := shortMarkerDir(t)
	payloads := []string{
		"$(touch " + filepath.Join(markerDir, "m1") + ")",
		"\";touch " + filepath.Join(markerDir, "m2") + ";#",
	}

	for i, ssid := range payloads {
		if len(ssid) > 32 {
			t.Fatalf("payload %d exceeds the 32-byte 802.11 limit", i)
		}
		t.Run(fmt.Sprintf("payload%d", i), func(t *testing.T) {
			log := filepath.Join(t.TempDir(), "nmcli.json")
			t.Setenv("PATH", stubDir+":"+os.Getenv("PATH"))
			t.Setenv("AUDIT_STUB", "1")
			t.Setenv("AUDIT_NMCLI_LOG", log)

			svc := NewService()
			params, err := json.Marshal(map[string]string{"ssid": ssid, "password": "audit-placeholder"})
			if err != nil {
				t.Fatal(err)
			}
			if _, err := svc.connect(params); err != nil {
				t.Fatal(err)
			}

			if _, err := os.Stat(filepath.Join(markerDir, fmt.Sprintf("m%d", i+1))); err == nil {
				t.Fatal("command-injection marker was created: SSID reached a shell")
			}

			raw, err := os.ReadFile(log)
			if err != nil {
				t.Fatalf("nmcli stub was never invoked: %v", err)
			}
			var sawModify bool
			for _, line := range splitLines(string(raw)) {
				var argv []string
				if err := json.Unmarshal([]byte(line), &argv); err != nil {
					continue
				}
				if len(argv) >= 3 && argv[0] == "connection" && argv[1] == "modify" {
					sawModify = true
					if argv[2] != ssid {
						t.Fatalf("nmcli received mutated SSID %q, want literal %q", argv[2], ssid)
					}
				}
			}
			if !sawModify {
				t.Fatal("no `nmcli connection modify` invocation was recorded")
			}
		})
	}
}

func splitLines(s string) []string {
	var out []string
	start := 0
	for i := 0; i < len(s); i++ {
		if s[i] == '\n' {
			out = append(out, s[start:i])
			start = i + 1
		}
	}
	if start < len(s) {
		out = append(out, s[start:])
	}
	return out
}
