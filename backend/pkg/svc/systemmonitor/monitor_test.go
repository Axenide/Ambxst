package systemmonitor

import (
	"sync"
	"testing"
)

// Sample computes CPU deltas from the prevTotal/prevIdle baselines it
// mutates. In production two callers overlap: one ticker goroutine per IPC
// subscriber plus the systemmonitor.getState handler, so the baseline
// read-modify-write must be safe for concurrent use.
func TestSampleConcurrentBaselines(t *testing.T) {
	m := NewMonitor(nil, 2000)
	var wg sync.WaitGroup
	for i := 0; i < 4; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < 50; j++ {
				_ = m.Sample()
			}
		}()
	}
	wg.Wait()
}

// A single-threaded sampler must always report a bounded CPU percentage;
// two overlapping samples used to mix baselines and could report values
// outside [0, 100].
func TestSampleUsageBounds(t *testing.T) {
	m := NewMonitor(nil, 2000)
	for i := 0; i < 5; i++ {
		d := m.Sample()
		if d.CPU.Usage < 0 || d.CPU.Usage > 100 {
			t.Fatalf("sample %d: CPU usage out of range: %f", i, d.CPU.Usage)
		}
	}
}
