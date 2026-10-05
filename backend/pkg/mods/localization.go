package mods

import (
	"encoding/json"
	"fmt"
	"os"
	"regexp"
)

// Localization describes the interface, not the programming language.
// An absent declaration remains unknown for older packages.
type Localization struct {
	Mode            string            `json:"mode"`
	DefaultLanguage string            `json:"defaultLanguage,omitempty"`
	Languages       []string          `json:"languages,omitempty"`
	Resources       map[string]string `json:"resources,omitempty"`
}

var languageTag = regexp.MustCompile(`^[a-zA-Z]{2,8}(-[a-zA-Z0-9]{1,8})*$`)

func localizationWarnings(l *Localization, root string) []string {
	if l == nil {
		return nil
	}
	warnings := []string{}
	if l.Mode != "translated" && l.Mode != "single" && l.Mode != "none" {
		warnings = append(warnings, "invalid_mode")
	}
	if l.Mode != "none" && !languageTag.MatchString(l.DefaultLanguage) {
		warnings = append(warnings, "invalid_default")
	}
	seen := map[string]bool{}
	for _, lang := range l.Languages {
		if !languageTag.MatchString(lang) || seen[lang] {
			warnings = append(warnings, "invalid_languages")
		}
		seen[lang] = true
	}
	if l.Mode == "translated" && !seen[l.DefaultLanguage] {
		warnings = append(warnings, "missing_default")
	}
	if l.Mode == "single" && len(l.Languages) > 1 {
		warnings = append(warnings, "invalid_languages")
	}
	for lang, resource := range l.Resources {
		path, err := safeJoin(root, resource)
		if err != nil || !seen[lang] {
			warnings = append(warnings, fmt.Sprintf("invalid_resource:%s", lang))
			continue
		}
		data, err := os.ReadFile(path)
		var strings map[string]string
		if err != nil || json.Unmarshal(data, &strings) != nil || len(strings) == 0 {
			warnings = append(warnings, fmt.Sprintf("invalid_resource:%s", lang))
		}
	}
	return warnings
}
