package capture

import (
	"bytes"
	"fmt"

	"ambxst/backend/internal/screenshot"
	"ambxst/backend/pkg/axmon"
)

// Frame captures an upright full-output frame for the named output.
// The returned closer releases all resources.
func Frame(outputName string, cursor bool) (*screenshot.CaptureResult, func(), error) {
	engine := screenshot.NewEngine(cursorMode(cursor))
	if err := engine.Connect(); err != nil {
		return nil, func() {}, err
	}

	raw, err := engine.CaptureOutputFrame(outputName)
	if err != nil {
		engine.Close()
		return nil, func() {}, err
	}

	result, err := screenshot.Upright(raw)
	if err != nil {
		raw.Buffer.Close()
		engine.Close()
		return nil, func() {}, err
	}

	closer := func() {
		result.Buffer.Close()
		engine.Close()
	}
	return result, closer, nil
}

// FrameRetained captures an upright full-output frame and tears down the
// wayland engine, retaining only the shm buffer. The returned closer
// releases the buffer.
func FrameRetained(outputName string, cursor bool) (*screenshot.CaptureResult, func(), error) {
	engine := screenshot.NewEngine(cursorMode(cursor))
	if err := engine.Connect(); err != nil {
		return nil, func() {}, err
	}

	raw, err := engine.CaptureOutputFrame(outputName)
	if err != nil {
		engine.Close()
		return nil, func() {}, err
	}

	result, err := screenshot.Upright(raw)
	if err != nil {
		raw.Buffer.Close()
		engine.Close()
		return nil, func() {}, err
	}

	engine.Close()
	return result, func() { result.Buffer.Close() }, nil
}

// OutputFrame returns a full-output frame, preferring the frozen session
// buffer so captures match the freeze preview shown by the tool. Falls
// back to a live capture when no freeze session is active.
func OutputFrame(name string, cursor bool) (*screenshot.CaptureResult, func(), error) {
	if w, h, ok := FrozenDims(name); ok {
		if cropped, closer, found, err := FrozenCrop(name, 0, 0, w, h); found {
			if err != nil {
				return nil, nil, err
			}
			return cropped, closer, nil
		}
	}
	return Frame(name, cursor)
}

// Region resolves the monitor containing a logical global rect and crops
// it at physical scale, preferring the frozen session frame for that
// output so captures read from the buffer the tool displayed. Falls back
// to a live capture when no freeze session is active. When outputName is
// empty the monitor is resolved from the rect center.
func Region(outputName string, x, y, w, h int, cursor bool) (*screenshot.CaptureResult, func(), error) {
	rect := screenshot.Region{
		X:      int32(x),
		Y:      int32(y),
		Width:  int32(w),
		Height: int32(h),
	}
	if rect.IsEmpty() {
		return nil, nil, fmt.Errorf("empty region")
	}

	monitors, err := axmon.List()
	if err != nil {
		return nil, nil, err
	}

	name := outputName
	if name == "" {
		m, ok := axmon.Containing(monitors, int(rect.X+rect.Width/2), int(rect.Y+rect.Height/2))
		if !ok {
			m, ok = axmon.Containing(monitors, int(rect.X), int(rect.Y))
		}
		if !ok {
			return nil, nil, fmt.Errorf("region outside all outputs")
		}
		name = m.Name
	}
	mon, ok := axmon.FindByName(monitors, name)
	if !ok {
		return nil, nil, fmt.Errorf("output %q not found", name)
	}

	scale := mon.EffectiveScale()
	localX := int(float64(int(rect.X)-mon.X())*scale + 0.5)
	localY := int(float64(int(rect.Y)-mon.Y())*scale + 0.5)
	cw := int(float64(rect.Width)*scale + 0.5)
	ch := int(float64(rect.Height)*scale + 0.5)

	if cropped, closer, found, ferr := FrozenCrop(name, int32(localX), int32(localY), int32(cw), int32(ch)); found {
		if ferr != nil {
			return nil, nil, ferr
		}
		return cropped, closer, nil
	}

	result, closer, err := Frame(name, cursor)
	if err != nil {
		return nil, nil, err
	}

	cropped, err := screenshot.CropBuffer(result, int32(localX), int32(localY), int32(cw), int32(ch))
	if err != nil {
		closer()
		return nil, nil, err
	}

	combinedCloser := func() {
		cropped.Buffer.Close()
		closer()
	}
	return cropped, combinedCloser, nil
}

func cursorMode(on bool) screenshot.CursorMode {
	if on {
		return screenshot.CursorOn
	}
	return screenshot.CursorOff
}

// RegionPNG captures a logical global rect as PNG bytes. 10-bit captures
// are downconverted so external consumers get plain 8-bit images.
func RegionPNG(outputName string, x, y, w, h int) ([]byte, func(), error) {
	result, closer, err := Region(outputName, x, y, w, h, false)
	if err != nil {
		return nil, nil, err
	}

	if screenshot.PixelFormat(result.Format).Is10Bit() {
		result.Buffer.Convert10To8()
		result.Format = uint32(result.Buffer.Format)
	}

	var buf bytes.Buffer
	if err := screenshot.EncodeBufferPNG(&buf, result.Buffer, result.Format, nil); err != nil {
		closer()
		return nil, nil, fmt.Errorf("encode png: %w", err)
	}
	return buf.Bytes(), closer, nil
}
