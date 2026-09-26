package main

import (
	"fmt"
	"net/url"
	"strings"
)

const modURLScheme = "ambxst"

type modURLAction struct {
	command string
	value   string
}

func parseModURL(raw string) (modURLAction, error) {
	parsed, err := url.Parse(strings.TrimSpace(raw))
	if err != nil {
		return modURLAction{}, fmt.Errorf("invalid mod URL: %w", err)
	}
	if !strings.EqualFold(parsed.Scheme, modURLScheme) || !strings.EqualFold(parsed.Host, "mods") {
		return modURLAction{}, fmt.Errorf("mod URL must start with %s://mods/", modURLScheme)
	}
	if parsed.User != nil || parsed.Fragment != "" {
		return modURLAction{}, fmt.Errorf("mod URL contains unsupported parts")
	}

	action := strings.Trim(parsed.Path, "/")
	query := parsed.Query()
	switch action {
	case "install":
		if err := requireOnlyQuery(query, "source"); err != nil {
			return modURLAction{}, err
		}
		source := query.Get("source")
		if !isRemoteModSource(source) {
			return modURLAction{}, fmt.Errorf("install source must be an HTTPS or SSH Git repository URL")
		}
		return modURLAction{command: "install", value: source}, nil
	default:
		return modURLAction{}, fmt.Errorf("unsupported mod URL action %q", action)
	}
}

func requireOnlyQuery(query url.Values, key string) error {
	if len(query) != 1 || len(query[key]) != 1 || query[key][0] == "" {
		return fmt.Errorf("mod URL requires exactly one %q parameter", key)
	}
	return nil
}

// isRemoteModSource accepts HTTPS and SSH Git sources. A host that starts
// with "-" would reach git and ssh as an option, so it is refused here rather
// than left to git's own check.
func isRemoteModSource(source string) bool {
	if strings.HasPrefix(source, "git@") {
		parts := strings.SplitN(strings.TrimPrefix(source, "git@"), ":", 2)
		return len(parts) == 2 && parts[0] != "" && parts[1] != "" && !strings.HasPrefix(parts[0], "-")
	}
	parsed, err := url.Parse(source)
	if err != nil || parsed.Host == "" || strings.HasPrefix(parsed.Host, "-") {
		return false
	}
	return (parsed.Scheme == "https" && parsed.User == nil) || parsed.Scheme == "ssh"
}
