// Portions Copyright (c) 2025 Avenge Media LLC
// Licensed under the MIT License. Derived from DankMaterialShell.

package screenshot

import (
	"fmt"
	stdlog "log"
	"sync"

	"ambxst/backend/internal/proto/wlr_screencopy"
	"ambxst/backend/internal/proto/wp_color_management"
	wlhelpers "ambxst/backend/internal/wayland/client"

	"github.com/AvengeMedia/dankgo/wayland/client"
)

type WaylandOutput struct {
	wlOutput        *client.Output
	globalName      uint32
	name            string
	x, y            int32
	width           int32
	height          int32
	scale           int32
	fractionalScale float64
	transform       int32
}

type Engine struct {
	cursor CursorMode

	display  *client.Display
	registry *client.Registry
	ctx      *client.Context

	compositor *client.Compositor
	shm        *client.Shm
	screencopy *wlr_screencopy.ZwlrScreencopyManagerV1
	colorMgr   *wp_color_management.WpColorManagerV1

	outputs   map[uint32]*WaylandOutput
	outputsMu sync.Mutex
}

func NewEngine(cursor CursorMode) *Engine {
	return &Engine{
		cursor:  cursor,
		outputs: make(map[uint32]*WaylandOutput),
	}
}

func (e *Engine) Connect() error {
	display, err := client.Connect("")
	if err != nil {
		return err
	}
	e.display = display
	e.ctx = display.Context()

	if err := e.setupRegistry(); err != nil {
		return fmt.Errorf("registry setup: %w", err)
	}
	if err := e.roundtrip(); err != nil {
		return fmt.Errorf("roundtrip: %w", err)
	}
	if e.screencopy == nil {
		return fmt.Errorf("compositor does not support wlr-screencopy-unstable-v1")
	}
	return e.roundtrip()
}

func (e *Engine) Close() {
	e.cleanup()
}

func (e *Engine) roundtrip() error {
	return wlhelpers.Roundtrip(e.display, e.ctx)
}

func (e *Engine) setupRegistry() error {
	registry, err := e.display.GetRegistry()
	if err != nil {
		return err
	}
	e.registry = registry

	registry.SetGlobalHandler(func(ev client.RegistryGlobalEvent) {
		e.handleGlobal(ev)
	})

	registry.SetGlobalRemoveHandler(func(ev client.RegistryGlobalRemoveEvent) {
		e.outputsMu.Lock()
		delete(e.outputs, ev.Name)
		e.outputsMu.Unlock()
	})

	return nil
}

func (e *Engine) handleGlobal(ev client.RegistryGlobalEvent) {
	switch ev.Interface {
	case client.CompositorInterfaceName:
		comp := client.NewCompositor(e.ctx)
		if err := e.registry.Bind(ev.Name, ev.Interface, ev.Version, comp); err == nil {
			e.compositor = comp
		}

	case client.ShmInterfaceName:
		shm := client.NewShm(e.ctx)
		if err := e.registry.Bind(ev.Name, ev.Interface, ev.Version, shm); err == nil {
			e.shm = shm
		}

	case client.OutputInterfaceName:
		output := client.NewOutput(e.ctx)
		version := min(ev.Version, 4)
		if err := e.registry.Bind(ev.Name, ev.Interface, version, output); err == nil {
			e.outputsMu.Lock()
			e.outputs[ev.Name] = &WaylandOutput{
				wlOutput:        output,
				globalName:      ev.Name,
				scale:           1,
				fractionalScale: 1.0,
			}
			e.outputsMu.Unlock()
			e.setupOutputHandlers(ev.Name, output)
		}

	case wlr_screencopy.ZwlrScreencopyManagerV1InterfaceName:
		sc := wlr_screencopy.NewZwlrScreencopyManagerV1(e.ctx)
		version := min(ev.Version, 3)
		if err := e.registry.Bind(ev.Name, ev.Interface, version, sc); err == nil {
			e.screencopy = sc
		}

	case wp_color_management.WpColorManagerV1InterfaceName:
		mgr := wp_color_management.NewWpColorManagerV1(e.ctx)
		if err := e.registry.Bind(ev.Name, ev.Interface, 1, mgr); err == nil {
			e.colorMgr = mgr
		}
	}
}

func (e *Engine) setupOutputHandlers(name uint32, output *client.Output) {
	output.SetGeometryHandler(func(ev client.OutputGeometryEvent) {
		e.outputsMu.Lock()
		if o, ok := e.outputs[name]; ok {
			o.x, o.y = ev.X, ev.Y
			o.transform = int32(ev.Transform)
		}
		e.outputsMu.Unlock()
	})

	output.SetModeHandler(func(ev client.OutputModeEvent) {
		if ev.Flags&uint32(client.OutputModeCurrent) == 0 {
			return
		}
		e.outputsMu.Lock()
		if o, ok := e.outputs[name]; ok {
			o.width, o.height = ev.Width, ev.Height
		}
		e.outputsMu.Unlock()
	})

	output.SetScaleHandler(func(ev client.OutputScaleEvent) {
		e.outputsMu.Lock()
		if o, ok := e.outputs[name]; ok {
			o.scale = ev.Factor
			o.fractionalScale = float64(ev.Factor)
		}
		e.outputsMu.Unlock()
	})

	output.SetNameHandler(func(ev client.OutputNameEvent) {
		e.outputsMu.Lock()
		if o, ok := e.outputs[name]; ok {
			o.name = ev.Name
		}
		e.outputsMu.Unlock()
	})
}

func (e *Engine) cleanup() {
	if e.colorMgr != nil {
		e.colorMgr.Destroy()
	}
	if e.screencopy != nil {
		e.screencopy.Destroy()
	}
	if e.display != nil {
		e.ctx.Close()
	}
}

// OutputInfo returns the wayland-reported info for a named output.
func (e *Engine) OutputInfo(name string) (*Output, bool) {
	e.outputsMu.Lock()
	defer e.outputsMu.Unlock()
	for _, o := range e.outputs {
		if o.name == name {
			return &Output{
				Name:            o.name,
				X:               o.x,
				Y:               o.y,
				Width:           o.width,
				Height:          o.height,
				Scale:           o.scale,
				FractionalScale: o.fractionalScale,
				Transform:       o.transform,
			}, true
		}
	}
	return nil, false
}

// ListOutputs enumerates connected outputs via a fresh connection.
func ListOutputs() ([]Output, error) {
	engine := NewEngine(CursorOff)
	if err := engine.Connect(); err != nil {
		return nil, err
	}
	defer engine.Close()

	engine.outputsMu.Lock()
	defer engine.outputsMu.Unlock()

	result := make([]Output, 0, len(engine.outputs))
	for _, o := range engine.outputs {
		result = append(result, Output{
			Name:            o.name,
			X:               o.x,
			Y:               o.y,
			Width:           o.width,
			Height:          o.height,
			Scale:           o.scale,
			FractionalScale: o.fractionalScale,
			Transform:       o.transform,
		})
	}
	return result, nil
}

// CaptureOutputFrame captures the raw scanout framebuffer of a named output.
// No transform is applied; use Upright before interpreting pixels.
func (e *Engine) CaptureOutputFrame(outputName string) (*CaptureResult, error) {
	var output *WaylandOutput
	e.outputsMu.Lock()
	for _, o := range e.outputs {
		if o.name == outputName {
			output = o
			break
		}
	}
	e.outputsMu.Unlock()

	if output == nil {
		return nil, fmt.Errorf("output %q not found", outputName)
	}

	frame, err := e.screencopy.CaptureOutput(int32(e.cursor), output.wlOutput)
	if err != nil {
		return nil, fmt.Errorf("capture output: %w", err)
	}

	result, err := e.processFrame(frame)
	if err != nil {
		return nil, err
	}

	result.Region = Region{
		X:      output.x,
		Y:      output.y,
		Width:  output.width,
		Height: output.height,
	}
	result.Transform = output.transform
	return result, nil
}

// Upright flips and re-orients a raw capture so rows read left-to-right,
// top-to-bottom in logical orientation. Closes the source buffer if a new
// one was allocated.
func Upright(result *CaptureResult) (*CaptureResult, error) {
	if result.YInverted {
		result.Buffer.FlipVertical()
		result.YInverted = false
	}

	if result.Transform == TransformNormal {
		return result, nil
	}

	transformed, err := result.Buffer.ApplyTransform(InverseTransform(result.Transform))
	if err != nil {
		return nil, fmt.Errorf("apply transform: %w", err)
	}

	if transformed != result.Buffer {
		result.Buffer.Close()
		result.Buffer = transformed
	}

	result.Region.Width = int32(transformed.Width)
	result.Region.Height = int32(transformed.Height)
	return result, nil
}

// CropBuffer crops an upright capture at pixel coordinates. The caller keeps
// ownership of src and must close it; the returned result owns a new buffer.
func CropBuffer(src *CaptureResult, x, y, w, h int32) (*CaptureResult, error) {
	bufW := int32(src.Buffer.Width)
	bufH := int32(src.Buffer.Height)

	if x < 0 {
		w += x
		x = 0
	}
	if y < 0 {
		h += y
		y = 0
	}
	if x+w > bufW {
		w = bufW - x
	}
	if y+h > bufH {
		h = bufH - y
	}
	if w <= 0 || h <= 0 {
		return nil, fmt.Errorf("empty crop rect")
	}

	cropped, err := CreateShmBuffer(int(w), int(h), int(w)*4)
	if err != nil {
		return nil, fmt.Errorf("create crop buffer: %w", err)
	}

	srcData := src.Buffer.Data()
	dstData := cropped.Data()

	for row := int32(0); row < h; row++ {
		srcOff := (int(y)+int(row))*src.Buffer.Stride + int(x)*4
		dstOff := int(row) * cropped.Stride
		copy(dstData[dstOff:dstOff+int(w)*4], srcData[srcOff:srcOff+int(w)*4])
	}
	cropped.Format = src.Buffer.Format

	return &CaptureResult{
		Buffer: cropped,
		Region: Region{X: x, Y: y, Width: w, Height: h},
		Format: uint32(cropped.Format),
	}, nil
}

func (e *Engine) processFrame(frame *wlr_screencopy.ZwlrScreencopyFrameV1) (*CaptureResult, error) {
	var buf *ShmBuffer
	var pool *client.ShmPool
	var wlBuf *client.Buffer
	var format PixelFormat
	var yInverted bool
	ready := false
	failed := false

	frame.SetBufferHandler(func(ev wlr_screencopy.ZwlrScreencopyFrameV1BufferEvent) {
		format = PixelFormat(ev.Format)
		bpp := format.BytesPerPixel()
		if int(ev.Stride) < int(ev.Width)*bpp {
			stdlog.Printf("screenshot: invalid stride %d width %d bpp %d", ev.Stride, ev.Width, bpp)
			failed = true
			return
		}
		var err error
		buf, err = CreateShmBuffer(int(ev.Width), int(ev.Height), int(ev.Stride))
		if err != nil {
			stdlog.Printf("screenshot: failed to create buffer: %v", err)
			failed = true
			return
		}
		buf.Format = format
	})

	frame.SetFlagsHandler(func(ev wlr_screencopy.ZwlrScreencopyFrameV1FlagsEvent) {
		yInverted = (ev.Flags & 1) != 0
	})

	frame.SetBufferDoneHandler(func(ev wlr_screencopy.ZwlrScreencopyFrameV1BufferDoneEvent) {
		if buf == nil {
			return
		}

		var err error
		pool, err = e.shm.CreatePool(buf.Fd(), int32(buf.Size()))
		if err != nil {
			stdlog.Printf("screenshot: failed to create pool: %v", err)
			failed = true
			return
		}

		wlBuf, err = pool.CreateBuffer(0, int32(buf.Width), int32(buf.Height), int32(buf.Stride), uint32(format))
		if err != nil {
			pool.Destroy()
			pool = nil
			stdlog.Printf("screenshot: failed to create wl_buffer: %v", err)
			failed = true
			return
		}

		if err := frame.Copy(wlBuf); err != nil {
			stdlog.Printf("screenshot: failed to copy frame: %v", err)
		}
	})

	frame.SetReadyHandler(func(ev wlr_screencopy.ZwlrScreencopyFrameV1ReadyEvent) {
		ready = true
	})

	frame.SetFailedHandler(func(ev wlr_screencopy.ZwlrScreencopyFrameV1FailedEvent) {
		failed = true
	})

	for !ready && !failed {
		if err := e.ctx.Dispatch(); err != nil {
			frame.Destroy()
			return nil, fmt.Errorf("dispatch: %w", err)
		}
	}

	frame.Destroy()
	if wlBuf != nil {
		wlBuf.Destroy()
	}
	if pool != nil {
		pool.Destroy()
	}

	if failed {
		if buf != nil {
			buf.Close()
		}
		return nil, fmt.Errorf("frame capture failed")
	}

	if format.Is24Bit() {
		converted, newFormat, err := buf.ConvertTo32Bit(format)
		if err != nil {
			buf.Close()
			return nil, fmt.Errorf("convert 24-bit to 32-bit: %w", err)
		}
		if converted != buf {
			buf.Close()
			buf = converted
		}
		format = newFormat
	}

	return &CaptureResult{
		Buffer:    buf,
		YInverted: yInverted,
		Format:    uint32(format),
	}, nil
}
