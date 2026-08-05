package brightness

import "testing"

func TestDDCVCPRegExMatch(t *testing.T) {
	cases := []struct {
		name   string
		line   string
		wantOK bool
		cur    int
		max    int
	}{
		{
			name:   "real ddcutil output",
			line:   "VCP code 0x10 (Brightness                    ): current value =   100, max value =   100",
			wantOK: true, cur: 100, max: 100,
		},
		{
			name:   "smaller brightness with extra spaces",
			line:   "VCP code 0x10 (Brightness                    ): current value =    37, max value =   100",
			wantOK: true, cur: 37, max: 100,
		},
		{
			name:   "zero brightness",
			line:   "VCP code 0x10 (Brightness                    ): current value =     0, max value =   100",
			wantOK: true, cur: 0, max: 100,
		},
		{
			name:   "any current/max line is matched",
			line:   "VCP code 0x12 (Contrast                    ): current value =    50, max value =   100",
			wantOK: true, cur: 50, max: 100,
		},
		{
			name:   "garbage input is rejected",
			line:   "this is not a VCP line",
			wantOK: false,
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			m := ddcVCPRe.FindStringSubmatch(c.line)
			gotOK := len(m) >= 3
			if gotOK != c.wantOK {
				t.Fatalf("match=%v wantOK=%v line=%q", m, c.wantOK, c.line)
			}
			if !gotOK {
				return
			}
			if m[1] != strconvItoa(c.cur) || m[2] != strconvItoa(c.max) {
				t.Fatalf("got cur=%s max=%s, want cur=%d max=%d", m[1], m[2], c.cur, c.max)
			}
		})
	}
}

func TestDDCVCPRegExMultiline(t *testing.T) {
	// Real ddcutil output can have multiple VCP codes listed. Make sure
	// the regex still finds the brightness line.
	out := `VCP code 0x10 (Brightness                    ): current value =    60, max value =   100
VCP code 0x12 (Contrast                      ): current value =    50, max value =   100
`
	m := ddcVCPRe.FindStringSubmatch(out)
	if len(m) < 3 {
		t.Fatalf("expected match in multi-line output, got %q", m)
	}
	if m[1] != "60" || m[2] != "100" {
		t.Fatalf("got cur=%s max=%s, want 60/100", m[1], m[2])
	}
}

// strconvItoa is a tiny shim to avoid importing strconv just for
// one assertion. Kept local to keep the test file focused.
func strconvItoa(i int) string {
	if i == 0 {
		return "0"
	}
	const digits = "0123456789"
	neg := i < 0
	if neg {
		i = -i
	}
	var buf [20]byte
	pos := len(buf)
	for i > 0 {
		pos--
		buf[pos] = digits[i%10]
		i /= 10
	}
	if neg {
		pos--
		buf[pos] = '-'
	}
	return string(buf[pos:])
}
