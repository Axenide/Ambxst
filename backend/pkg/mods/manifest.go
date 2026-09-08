// Package mods installs and composes Ambxst modifications.
//
// The package has no background worker. Repository access and generation
// builds only happen in response to an explicit method call.
package mods

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

const (
	ManifestFile = "ambxst.mod.json"
	APIVersion   = 1
)

var idPattern = regexp.MustCompile(`^[a-z0-9]+(?:[._-][a-z0-9]+)*$`)
var settingKeyPattern = regexp.MustCompile(`^[a-z][a-zA-Z0-9]*$`)
var sha256Pattern = regexp.MustCompile(`^[a-fA-F0-9]{64}$`)

type Manifest struct {
	Schema            string            `json:"$schema,omitempty"`
	ManifestVersion   int               `json:"manifestVersion"`
	ID                string            `json:"id"`
	Name              string            `json:"name"`
	Version           string            `json:"version"`
	Description       string            `json:"description"`
	License           string            `json:"license,omitempty"`
	Author            string            `json:"author,omitempty"`
	AuthorURL         string            `json:"authorUrl,omitempty"`
	Homepage          string            `json:"homepage,omitempty"`
	Compatibility     Compatibility     `json:"compatibility,omitempty"`
	Dependencies      []string          `json:"dependencies,omitempty"`
	DependencySources map[string]string `json:"dependencySources,omitempty"`
	Conflicts         []string          `json:"conflicts,omitempty"`
	Commands          []string          `json:"commands,omitempty"`
	Permissions       []string          `json:"permissions,omitempty"`
	Settings          *SettingsRef      `json:"settings,omitempty"`
	Operations        []Operation       `json:"operations"`

	// Keys this build does not recognise, kept for the package status only.
	UnknownFields []string `json:"-"`
}

type Compatibility struct {
	API               int      `json:"api,omitempty"`
	Ambxst            string   `json:"ambxst,omitempty"`
	TestedBaseCommits []string `json:"testedBaseCommits,omitempty"`
}

type Operation struct {
	Type           string `json:"type"`
	Source         string `json:"source"`
	Target         string `json:"target,omitempty"`
	Replace        bool   `json:"replace,omitempty"`
	ExpectedSHA256 string `json:"expectedSha256,omitempty"`
}

type SettingsRef struct {
	Schema string `json:"schema"`
}

type SettingsSchema struct {
	Schema  string         `json:"$schema,omitempty"`
	Version int            `json:"version"`
	Fields  []SettingField `json:"fields"`
}

type SettingField struct {
	Key             string          `json:"key"`
	Label           string          `json:"label"`
	Description     string          `json:"description,omitempty"`
	Type            string          `json:"type"`
	Default         any             `json:"default"`
	Minimum         *float64        `json:"minimum,omitempty"`
	Maximum         *float64        `json:"maximum,omitempty"`
	Options         []SettingOption `json:"options,omitempty"`
	RestartRequired bool            `json:"restartRequired,omitempty"`
}

type SettingOption struct {
	Label string `json:"label"`
	Value string `json:"value"`
}

func LoadManifest(root string) (Manifest, error) {
	data, err := os.ReadFile(filepath.Join(root, ManifestFile))
	if err != nil {
		return Manifest{}, fmt.Errorf("read manifest: %w", err)
	}
	var manifest Manifest
	if err := json.Unmarshal(data, &manifest); err != nil {
		return Manifest{}, fmt.Errorf("parse manifest: %w", err)
	}
	// A key this build does not know is reported, never fatal. Refusing the
	// package would mean any metadata added to the format later breaks every
	// older Ambxst that reads it.
	manifest.UnknownFields = unknownManifestFields(data)
	if err := manifest.Validate(root); err != nil {
		return Manifest{}, err
	}
	return manifest, nil
}

func unknownManifestFields(data []byte) []string {
	var probe Manifest
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	var unknown []string
	for {
		err := decoder.Decode(&probe)
		if err == nil || errors.Is(err, io.EOF) {
			return unknown
		}
		const marker = "unknown field "
		index := strings.Index(err.Error(), marker)
		if index < 0 {
			return unknown
		}
		name := strings.Trim(err.Error()[index+len(marker):], "\"")
		if name == "" {
			return unknown
		}
		for _, seen := range unknown {
			if seen == name {
				return unknown
			}
		}
		unknown = append(unknown, name)
		// The decoder stops at the first unknown key, so drop it and look again.
		var generic map[string]json.RawMessage
		if json.Unmarshal(data, &generic) != nil {
			return unknown
		}
		delete(generic, name)
		reduced, marshalErr := json.Marshal(generic)
		if marshalErr != nil {
			return unknown
		}
		data = reduced
		decoder = json.NewDecoder(bytes.NewReader(data))
		decoder.DisallowUnknownFields()
	}
}

func (m Manifest) Validate(root string) error {
	if m.ManifestVersion != APIVersion {
		return fmt.Errorf("unsupported manifest version %d", m.ManifestVersion)
	}
	if !idPattern.MatchString(m.ID) {
		return fmt.Errorf("invalid mod id %q", m.ID)
	}
	if strings.TrimSpace(m.Name) == "" {
		return fmt.Errorf("mod name is required")
	}
	if _, ok := parseVersion(m.Version); !ok {
		return fmt.Errorf("invalid mod version %q", m.Version)
	}
	if m.Compatibility.API != 0 && m.Compatibility.API != APIVersion {
		return fmt.Errorf("mod requires API %d", m.Compatibility.API)
	}
	references := make(map[string]bool)
	for _, id := range append(append([]string{}, m.Dependencies...), m.Conflicts...) {
		if !idPattern.MatchString(id) {
			return fmt.Errorf("invalid referenced mod id %q", id)
		}
		if id == m.ID {
			return fmt.Errorf("mod cannot reference itself as a dependency or conflict")
		}
		if references[id] {
			return fmt.Errorf("duplicate dependency or conflict %q", id)
		}
		references[id] = true
	}
	for id, source := range m.DependencySources {
		if !idPattern.MatchString(id) {
			return fmt.Errorf("invalid dependency source id %q", id)
		}
		if !stringInList(m.Dependencies, id) {
			return fmt.Errorf("dependency source %q is not declared as a dependency", id)
		}
		if strings.TrimSpace(source) == "" {
			return fmt.Errorf("dependency source %q is empty", id)
		}
	}
	if len(m.Operations) == 0 {
		return fmt.Errorf("mod has no operations")
	}
	for i, op := range m.Operations {
		if op.Type != "overlay" && op.Type != "patch" {
			return fmt.Errorf("operation %d has unsupported type %q", i+1, op.Type)
		}
		source, err := safeJoin(root, op.Source)
		if err != nil {
			return fmt.Errorf("operation %d source: %w", i+1, err)
		}
		info, err := os.Stat(source)
		if err != nil {
			return fmt.Errorf("operation %d source: %w", i+1, err)
		}
		if !info.Mode().IsRegular() {
			return fmt.Errorf("operation %d source is not a regular file", i+1)
		}
		if op.Type == "overlay" {
			if op.Target == "" {
				return fmt.Errorf("operation %d target is required", i+1)
			}
			if _, err := safeJoin(root, op.Target); err != nil {
				return fmt.Errorf("operation %d target: %w", i+1, err)
			}
			if op.Replace && op.ExpectedSHA256 == "" {
				return fmt.Errorf("operation %d requires expectedSha256 when replace is true", i+1)
			}
			if op.ExpectedSHA256 != "" && !sha256Pattern.MatchString(op.ExpectedSHA256) {
				return fmt.Errorf("operation %d has an invalid expectedSha256", i+1)
			}
			if !op.Replace && op.ExpectedSHA256 != "" {
				return fmt.Errorf("operation %d has expectedSha256 without replace", i+1)
			}
		} else if op.Target != "" || op.Replace || op.ExpectedSHA256 != "" {
			return fmt.Errorf("operation %d has overlay fields on a patch", i+1)
		}
	}
	if m.Settings != nil {
		schemaPath, err := safeJoin(root, m.Settings.Schema)
		if err != nil {
			return fmt.Errorf("settings schema: %w", err)
		}
		if _, err := LoadSettingsSchema(schemaPath); err != nil {
			return err
		}
	}
	return validatePackageTree(root)
}

func stringInList(values []string, target string) bool {
	for _, value := range values {
		if value == target {
			return true
		}
	}
	return false
}

func LoadSettingsSchema(path string) (SettingsSchema, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return SettingsSchema{}, fmt.Errorf("read settings schema: %w", err)
	}
	var schema SettingsSchema
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&schema); err != nil {
		return SettingsSchema{}, fmt.Errorf("parse settings schema: %w", err)
	}
	if schema.Version != 1 {
		return SettingsSchema{}, fmt.Errorf("unsupported settings schema version %d", schema.Version)
	}
	seen := make(map[string]bool)
	for _, field := range schema.Fields {
		if !settingKeyPattern.MatchString(field.Key) {
			return SettingsSchema{}, fmt.Errorf("invalid setting key %q", field.Key)
		}
		if seen[field.Key] {
			return SettingsSchema{}, fmt.Errorf("duplicate setting key %q", field.Key)
		}
		seen[field.Key] = true
		if strings.TrimSpace(field.Label) == "" {
			return SettingsSchema{}, fmt.Errorf("setting %s has no label", field.Key)
		}
		if field.Minimum != nil && field.Maximum != nil && *field.Minimum > *field.Maximum {
			return SettingsSchema{}, fmt.Errorf("setting %s minimum exceeds maximum", field.Key)
		}
		if field.Type == "enum" {
			if field.Minimum != nil || field.Maximum != nil || len(field.Options) == 0 {
				return SettingsSchema{}, fmt.Errorf("setting %s has invalid enum constraints", field.Key)
			}
			options := make(map[string]bool)
			for _, option := range field.Options {
				if strings.TrimSpace(option.Label) == "" || option.Value == "" {
					return SettingsSchema{}, fmt.Errorf("setting %s has an invalid option", field.Key)
				}
				if options[option.Value] {
					return SettingsSchema{}, fmt.Errorf("setting %s has duplicate option %q", field.Key, option.Value)
				}
				options[option.Value] = true
			}
		} else if len(field.Options) != 0 {
			return SettingsSchema{}, fmt.Errorf("setting %s has options for a non-enum type", field.Key)
		}
		if (field.Type == "boolean" || field.Type == "string") && (field.Minimum != nil || field.Maximum != nil) {
			return SettingsSchema{}, fmt.Errorf("setting %s has numeric constraints", field.Key)
		}
		if err := validateSettingValue(field, field.Default); err != nil {
			return SettingsSchema{}, fmt.Errorf("setting %s default: %w", field.Key, err)
		}
	}
	return schema, nil
}

func validateSettingValue(field SettingField, value any) error {
	switch field.Type {
	case "boolean":
		if _, ok := value.(bool); !ok {
			return fmt.Errorf("expected a boolean")
		}
	case "string":
		if _, ok := value.(string); !ok {
			return fmt.Errorf("expected a string")
		}
	case "integer", "number":
		number, ok := value.(float64)
		if !ok {
			return fmt.Errorf("expected a number")
		}
		if field.Type == "integer" && number != float64(int64(number)) {
			return fmt.Errorf("expected an integer")
		}
		if field.Minimum != nil && number < *field.Minimum {
			return fmt.Errorf("must be at least %v", *field.Minimum)
		}
		if field.Maximum != nil && number > *field.Maximum {
			return fmt.Errorf("must be at most %v", *field.Maximum)
		}
	case "enum":
		text, ok := value.(string)
		if !ok {
			return fmt.Errorf("expected an option value")
		}
		for _, option := range field.Options {
			if option.Value == text {
				return nil
			}
		}
		return fmt.Errorf("unknown option %q", text)
	default:
		return fmt.Errorf("unsupported type %q", field.Type)
	}
	return nil
}

func (m Manifest) AffectedFiles(root string) ([]string, error) {
	seen := make(map[string]struct{})
	for _, op := range m.Operations {
		if op.Type == "overlay" {
			seen[filepath.ToSlash(filepath.Clean(op.Target))] = struct{}{}
			continue
		}
		patchPath, err := safeJoin(root, op.Source)
		if err != nil {
			return nil, err
		}
		files, err := patchTargets(patchPath)
		if err != nil {
			return nil, err
		}
		for _, file := range files {
			seen[file] = struct{}{}
		}
	}
	files := make([]string, 0, len(seen))
	for file := range seen {
		files = append(files, file)
	}
	sort.Strings(files)
	return files, nil
}

func patchTargets(path string) ([]string, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("read patch: %w", err)
	}
	defer f.Close()

	seen := make(map[string]struct{})
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		if !strings.HasPrefix(line, "+++ ") && !strings.HasPrefix(line, "--- ") {
			continue
		}
		name := strings.Fields(strings.TrimSpace(line[4:]))
		if len(name) == 0 || name[0] == "/dev/null" {
			continue
		}
		target := strings.TrimPrefix(strings.TrimPrefix(name[0], "a/"), "b/")
		if !isSafeRelative(target) {
			return nil, fmt.Errorf("patch contains unsafe target %q", target)
		}
		seen[filepath.ToSlash(filepath.Clean(target))] = struct{}{}
	}
	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("scan patch: %w", err)
	}
	out := make([]string, 0, len(seen))
	for target := range seen {
		out = append(out, target)
	}
	sort.Strings(out)
	return out, nil
}

func safeJoin(root, relative string) (string, error) {
	if !isSafeRelative(relative) {
		return "", fmt.Errorf("unsafe relative path %q", relative)
	}
	return filepath.Join(root, filepath.Clean(relative)), nil
}

func isSafeRelative(path string) bool {
	if path == "" || filepath.IsAbs(path) {
		return false
	}
	clean := filepath.Clean(path)
	return clean != "." && clean != ".." && !strings.HasPrefix(clean, ".."+string(filepath.Separator))
}

func validatePackageTree(root string) error {
	return filepath.WalkDir(root, func(path string, entry os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if path != root && entry.IsDir() && entry.Name() == ".git" {
			return filepath.SkipDir
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		if info.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("package symlinks are not allowed: %s", path)
		}
		return nil
	})
}
