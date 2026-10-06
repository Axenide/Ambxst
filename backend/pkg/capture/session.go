package capture

import (
	"sync"
	"sync/atomic"
	"time"

	"ambxst/backend/internal/screenshot"
)

const defaultSessionTTL = 2 * time.Minute
const defaultSweepTick = 30 * time.Second

var (
	sessionMu     sync.RWMutex
	sessionFrames = map[string]*sessionFrame{}

	sessionTTL atomic.Int64
	sweepTick  atomic.Int64

	sweepOnce sync.Once
	sweepWake = make(chan struct{}, 1)
)

func init() {
	sessionTTL.Store(int64(defaultSessionTTL))
	sweepTick.Store(int64(defaultSweepTick))
}

type sessionFrame struct {
	result *screenshot.CaptureResult
	closer func()
	at     time.Time
}

// StoreSessionFrame retains an upright full-output frame as the freeze
// session buffer for output, closing any previous frame. Ownership of
// result and closer moves to the session.
func StoreSessionFrame(output string, result *screenshot.CaptureResult, closer func()) {
	if result == nil || closer == nil {
		return
	}

	sessionMu.Lock()
	if old, ok := sessionFrames[output]; ok {
		old.closer()
	}
	sessionFrames[output] = &sessionFrame{result: result, closer: closer, at: time.Now()}
	sessionMu.Unlock()

	sweepOnce.Do(func() { go sweepLoop() })
	notifySweeper()
}

// FrozenDims reports the frozen frame size for output.
func FrozenDims(output string) (int32, int32, bool) {
	sessionMu.RLock()
	defer sessionMu.RUnlock()
	f, ok := sessionFrames[output]
	if !ok || f.result == nil || f.result.Buffer == nil {
		return 0, 0, false
	}
	return int32(f.result.Buffer.Width), int32(f.result.Buffer.Height), true
}

// FrozenCrop copies a physical-pixel rect out of the frozen frame for
// output. found is false when no frozen frame exists. The returned result
// is an independent copy owned by the caller; the session buffer is only
// read while the session lock is held.
func FrozenCrop(output string, x, y, w, h int32) (*screenshot.CaptureResult, func(), bool, error) {
	sessionMu.RLock()
	defer sessionMu.RUnlock()
	f, ok := sessionFrames[output]
	if !ok || f.result == nil || f.result.Buffer == nil {
		return nil, nil, false, nil
	}

	cropped, err := screenshot.CropBuffer(f.result, x, y, w, h)
	if err != nil {
		return nil, nil, true, err
	}
	return cropped, func() { cropped.Buffer.Close() }, true, nil
}

// ReleaseSession closes and drops every frozen frame.
func ReleaseSession() {
	sessionMu.Lock()
	released := false
	for name, f := range sessionFrames {
		f.closer()
		delete(sessionFrames, name)
		released = true
	}
	sessionMu.Unlock()

	if released {
		notifySweeper()
	}
}

func notifySweeper() {
	select {
	case sweepWake <- struct{}{}:
	default:
	}
}

func sweepLoop() {
	for {
		select {
		case <-sweepWake:
		case <-time.After(time.Duration(sweepTick.Load())):
		}

		sessionMu.Lock()
		now := time.Now()
		ttl := time.Duration(sessionTTL.Load())
		for name, f := range sessionFrames {
			if now.Sub(f.at) > ttl {
				f.closer()
				delete(sessionFrames, name)
			}
		}
		sessionMu.Unlock()
	}
}
