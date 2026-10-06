package clipboard

import (
	"bytes"
	"crypto/md5"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"log"
	"os"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	wlclient "github.com/AvengeMedia/dankgo/wayland/client"

	"ambxst/backend/internal/proto/wlr_data_control"
)

const (
	captureTimeout  = 5 * time.Second
	maxCaptureBytes = 64 << 20
	emojiConfirmMax = 800 * time.Millisecond
)

// wlClient owns a persistent wlr-data-control connection: it watches the
// clipboard selection and serves copies as the selection owner.
type wlClient struct {
	svc *Service

	writeMu sync.Mutex

	mu        sync.Mutex
	selOffer  *wlr_data_control.ZwlrDataControlOfferV1
	selMimes  []string
	primOffer *wlr_data_control.ZwlrDataControlOfferV1
	pendMimes []string
	liveHash  string
	confirmCh chan struct{}
	source    *wlr_data_control.ZwlrDataControlSourceV1

	display *wlclient.Display
	ctx     *wlclient.Context
	manager *wlr_data_control.ZwlrDataControlManagerV1
	device  *wlr_data_control.ZwlrDataControlDeviceV1

	captureSeq atomic.Uint64

	stopCh chan struct{}
	doneCh chan struct{}
}

// startWayland returns errNoDataControl when the compositor lacks the
// protocol; the clipboard feature is then disabled.
func startWayland(svc *Service) (*wlClient, error) {
	w := &wlClient{svc: svc, stopCh: make(chan struct{}), doneCh: make(chan struct{})}
	if err := w.connect(); err != nil {
		return nil, err
	}
	go w.run()
	return w, nil
}

var errNoDataControl = errors.New("wlr-data-control not available")

func (w *wlClient) connect() error {
	display, err := wlclient.Connect("")
	if err != nil {
		log.Printf("[clipboard] wayland connect: %v", err)
		return errNoDataControl
	}
	w.display = display
	w.ctx = display.Context()

	registry, err := display.GetRegistry()
	if err != nil {
		w.teardown()
		return errNoDataControl
	}

	var manager *wlr_data_control.ZwlrDataControlManagerV1
	var seat *wlclient.Seat

	registry.SetGlobalHandler(func(ev wlclient.RegistryGlobalEvent) {
		switch ev.Interface {
		case wlr_data_control.ZwlrDataControlManagerV1InterfaceName:
			if manager != nil {
				return
			}
			m := wlr_data_control.NewZwlrDataControlManagerV1(w.ctx)
			if err := registry.Bind(ev.Name, ev.Interface, min(ev.Version, 2), m); err == nil {
				manager = m
			}
		case wlclient.SeatInterfaceName:
			if seat != nil {
				return
			}
			st := wlclient.NewSeat(w.ctx)
			if err := registry.Bind(ev.Name, ev.Interface, min(ev.Version, 1), st); err == nil {
				seat = st
			}
		}
	})

	if err := w.roundtrip(); err != nil {
		w.teardown()
		return err
	}
	if manager == nil {
		w.teardown()
		log.Printf("[clipboard] compositor does not advertise %s", wlr_data_control.ZwlrDataControlManagerV1InterfaceName)
		return errNoDataControl
	}
	if seat == nil {
		w.teardown()
		log.Printf("[clipboard] no wl_seat global found")
		return errNoDataControl
	}

	device, err := manager.GetDataDevice(seat)
	if err != nil {
		w.teardown()
		return err
	}
	w.manager = manager
	w.device = device

	device.SetDataOfferHandler(func(ev wlr_data_control.ZwlrDataControlDeviceV1DataOfferEvent) {
		if ev.Id == nil {
			return
		}
		w.pendMimes = nil
		ev.Id.SetOfferHandler(func(oe wlr_data_control.ZwlrDataControlOfferV1OfferEvent) {
			w.pendMimes = append(w.pendMimes, oe.MimeType)
		})
	})

	device.SetSelectionHandler(func(ev wlr_data_control.ZwlrDataControlDeviceV1SelectionEvent) {
		w.handleSelection(ev.Id, false)
	})

	device.SetPrimarySelectionHandler(func(ev wlr_data_control.ZwlrDataControlDeviceV1PrimarySelectionEvent) {
		w.handleSelection(ev.Id, true)
	})

	device.SetFinishedHandler(func(wlr_data_control.ZwlrDataControlDeviceV1FinishedEvent) {
		log.Printf("[clipboard] data control device finished; reconnecting")
	})

	if err := w.roundtrip(); err != nil {
		w.teardown()
		return err
	}
	return nil
}

func (w *wlClient) roundtrip() error {
	callback, err := w.display.Sync()
	if err != nil {
		return err
	}
	done := make(chan struct{})
	callback.SetDoneHandler(func(wlclient.CallbackDoneEvent) { close(done) })
	for {
		select {
		case <-done:
			return nil
		default:
			if err := w.ctx.Dispatch(); err != nil {
				return err
			}
		}
	}
}

func (w *wlClient) run() {
	defer close(w.doneCh)
	backoff := 2 * time.Second
	for {
		select {
		case <-w.stopCh:
			w.teardown()
			return
		default:
		}
		err := w.dispatchLoop()
		if err == nil {
			return
		}
		select {
		case <-w.stopCh:
			w.teardown()
			return
		default:
		}
		log.Printf("[clipboard] wayland loop: %v; reconnecting in %v", err, backoff)
		w.teardown()
		select {
		case <-w.stopCh:
			return
		case <-time.After(backoff):
		}
		if backoff < 30*time.Second {
			backoff *= 2
		}
		for {
			select {
			case <-w.stopCh:
				w.teardown()
				return
			default:
			}
			if err := w.connect(); err == nil {
				break
			} else if errors.Is(err, errNoDataControl) {
				log.Printf("[clipboard] reconnect: %v", err)
			}
			select {
			case <-w.stopCh:
				w.teardown()
				return
			case <-time.After(30 * time.Second):
			}
		}
		backoff = 2 * time.Second
	}
}

func (w *wlClient) dispatchLoop() error {
	for {
		select {
		case <-w.stopCh:
			return nil
		default:
		}
		if err := w.ctx.Dispatch(); err != nil {
			return err
		}
	}
}

func (w *wlClient) teardown() {
	if w.device != nil {
		w.device.Destroy()
		w.device = nil
	}
	if w.manager != nil {
		w.manager.Destroy()
		w.manager = nil
	}
	if w.ctx != nil {
		w.ctx.Close()
		w.ctx = nil
	}
	w.display = nil
}

func (w *wlClient) stop() {
	select {
	case <-w.stopCh:
		return
	default:
	}
	close(w.stopCh)
	if w.ctx != nil {
		w.ctx.Close()
	}
	select {
	case <-w.doneCh:
	case <-time.After(2 * time.Second):
	}
}

func (w *wlClient) write(fn func() error) error {
	w.writeMu.Lock()
	defer w.writeMu.Unlock()
	return fn()
}

// handleSelection runs on the event loop; primary offers are tracked only
// for lifecycle cleanup.
func (w *wlClient) handleSelection(offer *wlr_data_control.ZwlrDataControlOfferV1, isPrimary bool) {
	if isPrimary {
		if w.primOffer != nil && w.primOffer != offer {
			w.primOffer.Destroy()
		}
		w.primOffer = offer
		return
	}

	if w.selOffer != nil && w.selOffer != offer {
		w.selOffer.Destroy()
	}
	w.selOffer = offer
	w.selMimes = append([]string(nil), w.pendMimes...)

	if c := w.confirmCh; c != nil {
		w.confirmCh = nil
		select {
		case c <- struct{}{}:
		default:
		}
	}

	if offer == nil {
		w.mu.Lock()
		w.selOffer = nil
		w.selMimes = nil
		w.mu.Unlock()
		w.setLiveHash("")
		return
	}

	mimes := w.pendMimes
	w.pendMimes = nil
	w.capture(offer, mimes)
}

// capture reads the offered content. The pipe read must not block the
// event loop: the source's send event can only be dispatched there, so
// blocking would deadlock the transfer.
func (w *wlClient) capture(offer *wlr_data_control.ZwlrDataControlOfferV1, mimes []string) {
	mime := pickCaptureMime(mimes)
	if mime == "" {
		w.setLiveHash("")
		return
	}

	r, wr, err := os.Pipe()
	if err != nil {
		log.Printf("[clipboard] pipe: %v", err)
		return
	}
	writeFd := int(wr.Fd())
	err = w.write(func() error { return offer.Receive(mime, writeFd) })
	wr.Close()
	if err != nil {
		r.Close()
		log.Printf("[clipboard] receive %s: %v", mime, err)
		return
	}

	seq := w.captureSeq.Add(1)
	go func() {
		r.SetReadDeadline(time.Now().Add(captureTimeout))
		content, err := readAllCapped(r, maxCaptureBytes)
		r.Close()
		if err != nil {
			log.Printf("[clipboard] read %s: %v", mime, err)
			return
		}
		if w.captureSeq.Load() != seq {
			log.Printf("[clipboard] dropping stale capture seq=%d", seq)
			return
		}

		if mime != "text/uri-list" && !strings.HasPrefix(mime, "image/") {
			content = bytes.ReplaceAll(content, []byte("\r"), nil)
		}

		w.setLiveHash(md5Hash(content))

		isImage := strings.HasPrefix(mime, "image/")
		if w.svc.captureContent(mime, mimes, content, isImage, int64(len(content))) {
			w.svc.Send("clipboard.refresh", map[string]any{"ok": true})
		}
	}()
}

// copyContent makes the daemon the selection owner for the given content.
func (w *wlClient) copyContent(mime string, content []byte) error {
	if len(content) == 0 {
		return errors.New("empty content")
	}
	return w.write(func() error {
		if w.source != nil {
			w.source.Destroy()
			w.source = nil
		}
		source, err := w.manager.CreateDataSource()
		if err != nil {
			return err
		}
		source.SetSendHandler(func(ev wlr_data_control.ZwlrDataControlSourceV1SendEvent) {
			go serveData(ev.Fd, content)
		})
		source.SetCancelledHandler(func(wlr_data_control.ZwlrDataControlSourceV1CancelledEvent) {
			w.write(func() error {
				if w.source == source {
					w.source = nil
				}
				return source.Destroy()
			})
		})
		if err := source.Offer(mime); err != nil {
			source.Destroy()
			return err
		}
		if err := w.device.SetSelection(source); err != nil {
			source.Destroy()
			return err
		}
		w.source = source
		return nil
	})
}

// copyTextAwait waits for the compositor to echo the selection back (or
// the timeout), so a paste keystroke never reads a stale selection.
func (w *wlClient) copyTextAwait(mime string, content []byte) bool {
	confirm := make(chan struct{}, 1)
	w.mu.Lock()
	w.confirmCh = confirm
	w.mu.Unlock()

	if err := w.copyContent(mime, content); err != nil {
		w.mu.Lock()
		w.confirmCh = nil
		w.mu.Unlock()
		log.Printf("[clipboard] copy for type: %v", err)
		return false
	}

	select {
	case <-confirm:
		return true
	case <-time.After(emojiConfirmMax):
		w.mu.Lock()
		w.confirmCh = nil
		w.mu.Unlock()
		return false
	}
}

// clearSelection: some compositors don't echo a NULL selection, so the
// hash must be reset here or re-copies get skipped as unchanged.
func (w *wlClient) clearSelection() {
	w.write(func() error { return w.device.SetSelection(nil) })
	w.setLiveHash("")
}

func (w *wlClient) setLiveHash(hash string) {
	w.mu.Lock()
	w.liveHash = hash
	w.mu.Unlock()
}

func (w *wlClient) liveHashValue() string {
	w.mu.Lock()
	defer w.mu.Unlock()
	return w.liveHash
}

func (w *wlClient) liveMimes() []string {
	w.mu.Lock()
	defer w.mu.Unlock()
	return append([]string(nil), w.selMimes...)
}

// liveContent reads the requested mime from the current selection offer.
func (w *wlClient) liveContent(mime string) ([]byte, error) {
	w.mu.Lock()
	offer := w.selOffer
	w.mu.Unlock()
	if offer == nil {
		return nil, errors.New("no clipboard selection")
	}

	r, wr, err := os.Pipe()
	if err != nil {
		return nil, err
	}
	writeFd := int(wr.Fd())
	err = w.write(func() error { return offer.Receive(mime, writeFd) })
	wr.Close()
	if err != nil {
		r.Close()
		return nil, err
	}
	r.SetReadDeadline(time.Now().Add(captureTimeout))
	content, err := readAllCapped(r, maxCaptureBytes)
	r.Close()
	if err != nil {
		return nil, err
	}
	if mime == "text/uri-list" || strings.HasPrefix(mime, "text/") {
		content = bytes.ReplaceAll(content, []byte("\r"), nil)
	}
	return content, nil
}

func serveData(fd int, content []byte) {
	f := os.NewFile(uintptr(fd), "clipboard-send")
	if f == nil {
		return
	}
	defer f.Close()
	if len(content) > 0 {
		f.Write(content)
	}
}

func readAllCapped(f *os.File, cap int64) ([]byte, error) {
	var buf bytes.Buffer
	if _, err := buf.ReadFrom(io.LimitReader(f, cap+1)); err != nil {
		return nil, err
	}
	if int64(buf.Len()) > cap {
		return nil, fmt.Errorf("clipboard content exceeds %d bytes", cap)
	}
	return buf.Bytes(), nil
}

func md5Hash(content []byte) string {
	sum := md5.Sum(content)
	return hex.EncodeToString(sum[:])
}

// pickCaptureMime: uri-list, then images, then plain text (UTF-8 first).
func pickCaptureMime(mimes []string) string {
	var imageMime string
	for _, m := range mimes {
		switch {
		case m == "text/uri-list":
			return m
		case strings.HasPrefix(m, "image/"):
			if imageMime == "" {
				imageMime = m
			}
		}
	}
	if imageMime != "" {
		return imageMime
	}
	for _, m := range []string{"text/plain;charset=utf-8", "text/plain"} {
		for _, offered := range mimes {
			if offered == m {
				return m
			}
		}
	}
	return ""
}
