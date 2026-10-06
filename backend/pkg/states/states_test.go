package states

import (
	"path/filepath"
	"sync"
	"testing"
)

func TestSetKeyPreservesOtherKeys(t *testing.T) {
	path := filepath.Join(t.TempDir(), "states.json")
	if err := SetKey(path, "a", true); err != nil {
		t.Fatal(err)
	}
	if err := SetKey(path, "b", "x"); err != nil {
		t.Fatal(err)
	}
	doc := Read(path)
	if doc["a"] != true || doc["b"] != "x" {
		t.Fatalf("got %v", doc)
	}
}

func TestConcurrentWritesKeepAllKeys(t *testing.T) {
	path := filepath.Join(t.TempDir(), "states.json")
	var wg sync.WaitGroup
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < 20; j++ {
				_ = SetKey(path, "caffeine", j%2 == 0)
				_ = SetKey(path, "gameMode", j%2 == 1)
			}
		}()
	}
	wg.Wait()
	doc := Read(path)
	if _, ok := doc["caffeine"]; !ok {
		t.Fatal("caffeine key lost")
	}
	if _, ok := doc["gameMode"]; !ok {
		t.Fatal("gameMode key lost")
	}
}
