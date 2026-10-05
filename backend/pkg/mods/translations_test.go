package mods

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"regexp"
	"strings"
	"testing"
)

func TestModTranslationsHaveMatchingKeysAndPlaceholders(t *testing.T) {
	root := filepath.Join("..", "..", "..", "translations")
	load := func(locale string) map[string]string {
		t.Helper()
		data, err := os.ReadFile(filepath.Join(root, locale+".json"))
		if err != nil {
			t.Fatal(err)
		}
		var dictionary map[string]string
		if err := json.Unmarshal(data, &dictionary); err != nil {
			t.Fatal(err)
		}
		return dictionary
	}
	english := load("en")
	placeholder := regexp.MustCompile(`%[1-9][0-9]*`)
	for _, locale := range []string{"ru", "es"} {
		dictionary := load(locale)
		for key, source := range english {
			if !strings.HasPrefix(key, "mods.") {
				continue
			}
			translated, ok := dictionary[key]
			if !ok || strings.TrimSpace(translated) == "" {
				t.Errorf("%s is missing %s", locale, key)
				continue
			}
			if !reflect.DeepEqual(sortedStrings(placeholder.FindAllString(source, -1)), sortedStrings(placeholder.FindAllString(translated, -1))) {
				t.Errorf("%s has different placeholders for %s", locale, key)
			}
		}
	}
}
