package mods

import (
	"strconv"
	"strings"
)

type version [3]int

func parseVersion(raw string) (version, bool) {
	base := strings.SplitN(strings.TrimSpace(raw), "-", 2)[0]
	parts := strings.Split(base, ".")
	if len(parts) != 3 {
		return version{}, false
	}
	var out version
	for i, part := range parts {
		value, err := strconv.Atoi(part)
		if err != nil || value < 0 {
			return version{}, false
		}
		out[i] = value
	}
	return out, true
}

func compareVersion(a, b version) int {
	for i := range a {
		if a[i] < b[i] {
			return -1
		}
		if a[i] > b[i] {
			return 1
		}
	}
	return 0
}

func matchesVersion(rawVersion, constraint string) bool {
	if strings.TrimSpace(constraint) == "" {
		return true
	}
	current, ok := parseVersion(rawVersion)
	if !ok {
		return false
	}
	for _, term := range strings.Fields(constraint) {
		op := "="
		value := term
		for _, candidate := range []string{">=", "<=", ">", "<", "="} {
			if strings.HasPrefix(term, candidate) {
				op = candidate
				value = strings.TrimPrefix(term, candidate)
				break
			}
		}
		required, ok := parseVersion(value)
		if !ok {
			return false
		}
		cmp := compareVersion(current, required)
		switch op {
		case ">=":
			ok = cmp >= 0
		case "<=":
			ok = cmp <= 0
		case ">":
			ok = cmp > 0
		case "<":
			ok = cmp < 0
		default:
			ok = cmp == 0
		}
		if !ok {
			return false
		}
	}
	return true
}
