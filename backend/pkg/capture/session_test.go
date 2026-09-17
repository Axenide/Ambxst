package capture

import (
	"fmt"
	"sync"
	"testing"
	"time"

	"ambxst/backend/internal/screenshot"
)

func newTestFrame(t *testing.T, w, h int) (*screenshot.CaptureResult, error) {
	t.Helper()
	buf, err := screenshot.CreateShmBuffer(w, h, w*4)
	if err != nil {
		return nil, err
	}
	buf.Format = screenshot.FormatARGB8888
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			off := y*buf.Stride + x*4
			buf.Data()[off+0] = 0x80
			buf.Data()[off+1] = byte(y)
			buf.Data()[off+2] = byte(x)
			buf.Data()[off+3] = 0xFF
		}
	}
	return &screenshot.CaptureResult{
		Buffer: buf,
		Format: uint32(screenshot.FormatARGB8888),
	}, nil
}

func mustFrame(t *testing.T, w, h int) *screenshot.CaptureResult {
	t.Helper()
	frame, err := newTestFrame(t, w, h)
	if err != nil {
		t.Fatalf("create frame: %v", err)
	}
	return frame
}

func resetSession() {
	ReleaseSession()
}

func TestSessionStoreDimsAndCrop(t *testing.T) {
	resetSession()
	defer resetSession()

	frame := mustFrame(t, 16, 12)
	StoreSessionFrame("DP-1", frame, func() { frame.Buffer.Close() })

	w, h, ok := FrozenDims("DP-1")
	if !ok || w != 16 || h != 12 {
		t.Fatalf("dims: ok=%v w=%d h=%d", ok, w, h)
	}

	cropped, closer, found, err := FrozenCrop("DP-1", 4, 3, 8, 6)
	if !found || err != nil {
		t.Fatalf("crop: found=%v err=%v", found, err)
	}
	defer closer()

	if cropped.Buffer.Width != 8 || cropped.Buffer.Height != 6 {
		t.Fatalf("unexpected dims %dx%d", cropped.Buffer.Width, cropped.Buffer.Height)
	}
	for y := 0; y < 6; y++ {
		for x := 0; x < 8; x++ {
			off := y*cropped.Buffer.Stride + x*4
			r := cropped.Buffer.Data()[off+2]
			g := cropped.Buffer.Data()[off+1]
			if r != byte(4+x) || g != byte(3+y) {
				t.Fatalf("pixel (%d,%d): got r=%d g=%d want r=%d g=%d", x, y, r, g, 4+x, 3+y)
			}
		}
	}
}

func TestFrozenCropSurvivesRelease(t *testing.T) {
	resetSession()
	defer resetSession()

	frame := mustFrame(t, 8, 8)
	StoreSessionFrame("DP-1", frame, func() { frame.Buffer.Close() })

	cropped, closer, found, err := FrozenCrop("DP-1", 0, 0, 8, 8)
	if !found || err != nil {
		t.Fatalf("crop: found=%v err=%v", found, err)
	}

	ReleaseSession()

	if got := cropped.Buffer.Data()[0]; got != 0x80 {
		t.Fatalf("released session corrupted independent copy: %d", got)
	}
	closer()
}

func TestSessionReplaceClosesPrevious(t *testing.T) {
	resetSession()
	defer resetSession()

	first := mustFrame(t, 4, 4)
	closedFirst := false
	StoreSessionFrame("DP-1", first, func() { closedFirst = true; first.Buffer.Close() })

	second := mustFrame(t, 6, 6)
	StoreSessionFrame("DP-1", second, func() { second.Buffer.Close() })

	if !closedFirst {
		t.Fatal("previous frame not closed on replace")
	}
	if w, h, ok := FrozenDims("DP-1"); !ok || w != 6 || h != 6 {
		t.Fatalf("session frame not replaced: ok=%v %dx%d", ok, w, h)
	}
}

func TestSessionPerOutput(t *testing.T) {
	resetSession()
	defer resetSession()

	a := mustFrame(t, 4, 4)
	b := mustFrame(t, 5, 5)
	StoreSessionFrame("DP-1", a, func() { a.Buffer.Close() })
	StoreSessionFrame("DP-2", b, func() { b.Buffer.Close() })

	if w, _, ok := FrozenDims("DP-1"); !ok || w != 4 {
		t.Fatal("DP-1 frame missing")
	}
	if w, _, ok := FrozenDims("DP-2"); !ok || w != 5 {
		t.Fatal("DP-2 frame missing")
	}

	ReleaseSession()

	if _, _, ok := FrozenDims("DP-1"); ok {
		t.Fatal("DP-1 not released")
	}
	if _, _, ok := FrozenDims("DP-2"); ok {
		t.Fatal("DP-2 not released")
	}
}

func TestSessionReleaseEmpty(t *testing.T) {
	resetSession()
	resetSession()
}

func TestSessionTTL(t *testing.T) {
	resetSession()
	defer resetSession()

	oldTTL, oldTick := sessionTTL.Load(), sweepTick.Load()
	sessionTTL.Store(int64(20 * time.Millisecond))
	sweepTick.Store(int64(5 * time.Millisecond))
	defer func() {
		sessionTTL.Store(oldTTL)
		sweepTick.Store(oldTick)
	}()

	frame := mustFrame(t, 4, 4)
	closed := make(chan struct{})
	StoreSessionFrame("DP-1", frame, func() { close(closed); frame.Buffer.Close() })

	select {
	case <-closed:
	case <-time.After(2 * time.Second):
		t.Fatal("frame not swept after TTL")
	}

	if _, _, ok := FrozenDims("DP-1"); ok {
		t.Fatal("expired frame still present")
	}
}

func TestSessionConcurrent(t *testing.T) {
	resetSession()
	defer resetSession()

	var wg sync.WaitGroup
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			for j := 0; j < 25; j++ {
				frame, err := newTestFrame(t, 4, 4)
				if err != nil {
					t.Errorf("create frame: %v", err)
					return
				}
				name := fmt.Sprintf("OUT-%d", i%2)
				StoreSessionFrame(name, frame, func() { frame.Buffer.Close() })
				if _, closer, found, err := FrozenCrop(name, 0, 0, 4, 4); found {
					if err != nil {
						t.Errorf("crop: %v", err)
						return
					}
					closer()
				}
				if j%5 == 0 {
					ReleaseSession()
				}
			}
		}(i)
	}
	wg.Wait()
}
