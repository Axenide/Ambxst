// Package wlcontext implements a minimal pure-Go Wayland display client.
//
// Scope is intentionally narrow: open a display, enumerate globals via the
// registry, and let callers bind specific globals (currently only
// zwlr_gamma_control_manager_v1). It implements just enough of the
// wl_display/wl_registry protocol to support the nightlight service; no
// surfaces, no inputs, no outputs.
//
// Wire format reference:
//   https://wayland.freedesktop.org/docs/html/section-4.html
package wlcontext

import (
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"sync"
	"sync/atomic"
	"syscall"
	"unsafe"
)

const (
	wlDisplayID  = 1
	wlRegistryID = 2
	// nextIDStart is the first client-allocated id. Some compositors
	// (Hyprland) reject non-sequential ids, so we start at 2 and increment.
	nextIDStart = 2
)

const (
	wlDisplaySync                = 0
	wlDisplayGetRegistry         = 1
	wlRegistryBind               = 0
	wlRegistryGlobal             = 0
	wlRegistryGlobalRemove       = 1
	zwlrGammaManagerGetControl   = 0
	zwlrGammaManagerDestroy      = 1
	zwlrGammaControlSetGamma     = 0
	zwlrGammaControlSetTemp      = 4
	zwlrGammaControlDestroy      = 5
	zwlrGammaControlEventGSize    = 0
)

const headerSize = 8

// Global describes a single registry.global event.
type Global struct {
	Name      uint32
	Interface string
	Version   uint32
}

// Conn is a Wayland display connection.
type Conn struct {
	fd       int32
	mu       sync.Mutex
	nextID   atomic.Uint32
	globals  map[string]uint32
	outputs  []uint32
	gammaMgr uint32

	closed atomic.Bool
	sock   *net.UnixConn

	// dropAll causes the background drain goroutine to silently drop every
	// event instead of dispatching. wlcontext itself doesn't interpret
	// events; that's the caller's job. Set to true for fire-and-forget use.
	dropAll atomic.Bool
	stopCh  chan struct{}
}

// Connect opens the Wayland display and returns a connection handle.
// Honors $WAYLAND_DISPLAY (default "wayland-0") and $WAYLAND_DISPLAY_SOCKET
// for the libwayland fd-passing convention.
func Connect() (*Conn, error) {
	sock, err := dial()
	if err != nil {
		return nil, err
	}
	fd, err := extractFD(sock)
	if err != nil {
		sock.Close()
		return nil, err
	}
	c := &Conn{
		fd:      int32(fd),
		globals: make(map[string]uint32),
		sock:    sock,
		stopCh:  make(chan struct{}),
	}
	c.nextID.Store(nextIDStart)
	c.dropAll.Store(true) // default: silent drop; services can opt in
	if err := c.fetchRegistry(); err != nil {
		c.Close()
		return nil, fmt.Errorf("fetch registry: %w", err)
	}
	go c.drainLoop()
	return c, nil
}

func dial() (*net.UnixConn, error) {
	if path, ok := os.LookupEnv("WAYLAND_DISPLAY_SOCKET"); ok {
		c, err := net.Dial("unix", path)
		if err != nil {
			return nil, err
		}
		return c.(*net.UnixConn), nil
	}
	display := os.Getenv("WAYLAND_DISPLAY")
	if display == "" {
		display = "wayland-0"
	}
	runtime := os.Getenv("XDG_RUNTIME_DIR")
	if runtime == "" {
		return nil, errors.New("XDG_RUNTIME_DIR not set")
	}
	c, err := net.Dial("unix", runtime+"/"+display)
	if err != nil {
		return nil, err
	}
	return c.(*net.UnixConn), nil
}

func extractFD(uc *net.UnixConn) (int, error) {
	raw, err := uc.SyscallConn()
	if err != nil {
		return -1, err
	}
	var fd int
	var ctrlErr error
	if err := raw.Control(func(f uintptr) {
		fd = int(f)
	}); err != nil {
		return -1, err
	}
	if ctrlErr != nil {
		return -1, ctrlErr
	}
	return fd, nil
}

// Close shuts down the connection.
func (c *Conn) Close() {
	if c.closed.Swap(true) {
		return
	}
	select {
	case <-c.stopCh:
	default:
		close(c.stopCh)
	}
	if c.sock != nil {
		c.sock.Close()
	}
}

// FD exposes the raw socket fd (for clients that need it).
func (c *Conn) FD() int { return int(c.fd) }

// Outputs returns the wl_output global names discovered in the registry.
func (c *Conn) Outputs() []uint32 {
	c.mu.Lock()
	defer c.mu.Unlock()
	out := make([]uint32, len(c.outputs))
	copy(out, c.outputs)
	return out
}

// GammaManagerGlobal returns the registry name of zwlr_gamma_control_manager_v1
// or 0 if the global is not present.
func (c *Conn) GammaManagerGlobal() uint32 {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.gammaMgr
}

// allocID allocates a new client-side object id.
func (c *Conn) allocID() uint32 {
	return c.nextID.Add(1) - 1
}

// AllocID is the exported form of allocID for callers that need to reserve
// an id before sending the request.
func (c *Conn) AllocID() uint32 {
	return c.allocID()
}

// TryReadEvent attempts to read one event with a short poll timeout.
// Returns a zero header and io.EOF-style error when no event is available,
// allowing callers to drain pending events without blocking.
func (c *Conn) TryReadEvent(buf []byte) (header, []byte, error) {
	pfd := []int32{int32(c.fd), 0x0001} // POLLIN
	r, _, _ := syscall.Syscall(syscall.SYS_POLL, uintptr(unsafe.Pointer(&pfd[0])), 1, 50)
	if r == 0 {
		return header{}, nil, nil
	}
	h, args, err := readMessage(int(c.fd), buf)
	if err != nil {
		return header{}, nil, err
	}
	return h, args, nil
}

// header is a parsed Wayland message header.
type header struct {
	Sender  uint32
	SizeDiv uint16
	opcode  uint16
}

// roundtrip exchanges sync → server hello so we know we're connected.
func (c *Conn) roundtrip() error {
	id := c.allocID()
	if err := c.sendRequest(wlDisplayID, wlDisplaySync, encodeU32(id)); err != nil {
		return err
	}
	return c.readUntil(func(h header, args []byte) bool {
		if h.Sender == id {
			return true
		}
		return false
	})
}

// fetchRegistry issues get_registry, then sync, and reads globals until
// the sync callback's done event arrives (which guarantees no more events
// are pending on the registry).
func (c *Conn) fetchRegistry() error {
	regID := c.allocID()
	if err := c.sendRequest(wlDisplayID, wlDisplayGetRegistry, encodeU32(regID)); err != nil {
		return err
	}
	syncID := c.allocID()
	if err := c.sendRequest(wlDisplayID, wlDisplaySync, encodeU32(syncID)); err != nil {
		return err
	}
	return c.readUntil(func(h header, args []byte) bool {
		if h.Sender == syncID && h.opcode == 0 {
			return true
		}
		if h.Sender == regID && h.opcode == wlRegistryGlobal {
			name := binary.LittleEndian.Uint32(args[0:4])
			s, next, err := readString(args, 4)
			if err != nil {
				return false
			}
			ver := binary.LittleEndian.Uint32(args[next : next+4])
			c.mu.Lock()
			c.globals[s] = name
			if s == "wl_output" {
				c.outputs = append(c.outputs, name)
			} else if s == "zwlr_gamma_control_manager_v1" {
				c.gammaMgr = name
			}
			c.mu.Unlock()
			_ = ver
		}
		return false
	})
}

// readUntil reads messages from the socket until predicate returns true.
// Used for synchronous protocol handshakes.
func (c *Conn) readUntil(accept func(h header, args []byte) bool) error {
	buf := make([]byte, 65536)
	for {
		if c.closed.Load() {
			return errors.New("connection closed")
		}
		h, args, err := readMessage(int(c.fd), buf)
		if err != nil {
			return err
		}
		if accept(h, args) {
			return nil
		}
	}
}

// sendRequest writes a message to the socket. Args must already include the
// proper padding and string encoding per the Wayland wire format.
func (c *Conn) sendRequest(sender uint32, opcode uint16, args []byte) error {
	total := headerSize + len(args)
	msg := make([]byte, 0, total)
	hdr := make([]byte, headerSize)
	binary.LittleEndian.PutUint32(hdr[0:4], sender)
	binary.LittleEndian.PutUint16(hdr[4:6], opcode)
	binary.LittleEndian.PutUint16(hdr[6:8], uint16(total))
	msg = append(msg, hdr...)
	msg = append(msg, args...)
	return writeMessage(int(c.fd), msg)
}

// readMessage reads exactly one Wayland message into buf. Returns the
// parsed header, arguments slice, and any error.
func readMessage(fd int, buf []byte) (header, []byte, error) {
	for {
		n, _, errno := syscall.Syscall(syscall.SYS_READ, uintptr(fd),
			uintptr(unsafe.Pointer(&buf[0])), uintptr(headerSize))
		if errno == 11 { // EAGAIN
			if err := waitReadable(fd); err != nil {
				return header{}, nil, err
			}
			continue
		}
		if errno != 0 {
			return header{}, nil, syscall.Errno(errno)
		}
		if n == 0 {
			return header{}, nil, io.EOF
		}
		if int(n) == headerSize {
			break
		}
	}
	h := header{
		Sender: binary.LittleEndian.Uint32(buf[0:4]),
		opcode: binary.LittleEndian.Uint16(buf[4:6]),
	}
	size := int(binary.LittleEndian.Uint16(buf[6:8]))
	if size < headerSize || size > len(buf) {
		return header{}, nil, fmt.Errorf("invalid size: %d", size)
	}
	total := headerSize
	for total < size {
		n, _, errno := syscall.Syscall(syscall.SYS_READ, uintptr(fd),
			uintptr(unsafe.Pointer(&buf[total])), uintptr(size-total))
		if errno == 11 { // EAGAIN
			if err := waitReadable(fd); err != nil {
				return header{}, nil, err
			}
			continue
		}
		if errno != 0 {
			return header{}, nil, syscall.Errno(errno)
		}
		if n == 0 {
			return header{}, nil, io.EOF
		}
		total += int(n)
	}
	return h, buf[headerSize:size], nil
}

// waitReadable blocks until fd is readable or the deadline expires. Calls
// poll(2) directly via Syscall to avoid pulling in golang.org/x/sys/unix
// for a single syscall.
func waitReadable(fd int) error {
	var pfd [2]int32
	pfd[0] = int32(fd)
	pfd[1] = 0x0001 // POLLIN
	for {
		n, _, errno := syscall.Syscall(syscall.SYS_POLL, uintptr(unsafe.Pointer(&pfd[0])), 1, 2000)
		if errno != 0 {
			return syscall.Errno(errno)
		}
		if n > 0 {
			return nil
		}
	}
}

// writeMessage writes buf to the Wayland socket.
func writeMessage(fd int, buf []byte) error {
	off := 0
	for off < len(buf) {
		n, _, errno := syscall.Syscall(syscall.SYS_WRITE, uintptr(fd),
			uintptr(unsafe.Pointer(&buf[off])), uintptr(len(buf)-off))
		if errno != 0 {
			return syscall.Errno(errno)
		}
		if n == 0 {
			return io.EOF
		}
		off += int(n)
	}
	return nil
}

// readString decodes a Wayland string argument starting at off in args.
// Returns the string and the offset immediately after it (padded to 4 bytes).
func readString(args []byte, off int) (string, int, error) {
	if off+4 > len(args) {
		return "", 0, errors.New("short string length")
	}
	length := binary.LittleEndian.Uint32(args[off : off+4])
	off += 4
	end := off + int(length)
	if end > len(args) {
		return "", 0, errors.New("short string data")
	}
	// String data includes the trailing NUL.
	s := string(args[off : end-1])
	off = end
	if pad := off % 4; pad != 0 {
		off += 4 - pad
	}
	return s, off, nil
}

// encodeU32 encodes a single uint32 argument.
func encodeU32(v uint32) []byte {
	out := make([]byte, 4)
	binary.LittleEndian.PutUint32(out, v)
	return out
}

// encodeString encodes a Wayland string argument (length, data, NUL, padding).
func encodeString(s string) []byte {
	raw := append([]byte(s), 0)
	if pad := len(raw) % 4; pad != 0 {
		raw = append(raw, make([]byte, 4-pad)...)
	}
	out := make([]byte, 4+len(raw))
	binary.LittleEndian.PutUint32(out[0:4], uint32(len(s)+1))
	copy(out[4:], raw)
	return out
}

// Bind binds a global by name and returns the new client-side object id.
// `interfaceName` should be the well-known name (e.g. "wl_output" or
// "zwlr_gamma_control_manager_v1").
//
// Some bindings trigger server events (e.g. wl_output sends geometry/mode/etc
// after bind). We drain a few events best-effort to keep the socket buffer
// from filling up and stalling further writes.
func (c *Conn) Bind(name uint32, interfaceName string, version uint32) (uint32, error) {
	id := c.allocID()
	args := append(encodeU32(name), encodeString(interfaceName)...)
	args = append(args, encodeU32(version)...)
	args = append(args, encodeU32(id)...)
	if err := c.sendRequest(wlRegistryID, wlRegistryBind, args); err != nil {
		return 0, err
	}
	c.drainBestEffort()
	return id, nil
}

// DrainBestEffort is the exported form of drainBestEffort.
func (c *Conn) DrainBestEffort() { c.drainBestEffort() }

// drainLoop continuously reads and discards events so the socket buffer
// never fills up. Wayland events arrive asynchronously from the compositor
// in response to bind()/get_*/etc requests and even on their own (e.g.
// output hotplug). Without this loop, a client that doesn't process
// events will see write() return EPIPE once the buffer overflows.
//
// Compositor-sent error events (wl_display.error) terminate the connection;
// we log those so callers can debug protocol mistakes.
func (c *Conn) drainLoop() {
	buf := make([]byte, 4096)
	for {
		select {
		case <-c.stopCh:
			return
		default:
		}
		pfd := []int32{int32(c.fd), 0x0001}
		r, _, _ := syscall.Syscall(syscall.SYS_POLL, uintptr(unsafe.Pointer(&pfd[0])), 1, 200)
		if r <= 0 {
			continue
		}
		h, args, err := readMessage(int(c.fd), buf)
		if err != nil {
			return
		}
		if h.Sender == 1 && h.opcode == 0 && len(args) >= 8 {
			// wl_display.error: object_id(u32) + code(u32) + message(string)
			msg := ""
			if len(args) >= 12 {
				slen := binary.LittleEndian.Uint32(args[8:12])
				if int(slen) <= len(args)-12 {
					msg = string(args[12 : 12+slen-1])
				}
			}
			fmt.Fprintf(os.Stderr, "[wlcontext] server error: %s\n", msg)
		}
	}
}

// drainBestEffort reads events until the socket has nothing left to read,
// bounded by a max count to avoid infinite loops on a busy compositor.
// Used after bind() where the server replies with output/interface
// metadata we don't care about.
func (c *Conn) drainBestEffort() {
	buf := make([]byte, 4096)
	for i := 0; i < 256; i++ {
		// POLLIN with zero timeout returns immediately; 0 means no data.
		pfd := []int32{int32(c.fd), 0x0001}
		r, _, _ := syscall.Syscall(syscall.SYS_POLL, uintptr(unsafe.Pointer(&pfd[0])), 1, 0)
		if r == 0 {
			return
		}
		h, _, err := c.TryReadEvent(buf)
		if err != nil {
			return
		}
		if h.Sender == 0 {
			return
		}
	}
}

// SendRequest is a low-level escape hatch: write a request on a client-owned
// object id with raw args bytes (already padded). Used by the gamma service.
func (c *Conn) SendRequest(sender uint32, opcode uint16, args []byte) error {
	return c.sendRequest(sender, opcode, args)
}

// SendRequestWithFD is like SendRequest but also passes an fd to the
// compositor via SCM_RIGHTS ancillary data. Used by set_gamma to deliver
// the gamma ramp memory map.
func (c *Conn) SendRequestWithFD(sender uint32, opcode uint16, fd int, args []byte) error {
	total := headerSize + len(args)
	msg := make([]byte, 0, total)
	hdr := make([]byte, headerSize)
	binary.LittleEndian.PutUint32(hdr[0:4], sender)
	binary.LittleEndian.PutUint16(hdr[4:6], opcode)
	binary.LittleEndian.PutUint16(hdr[6:8], uint16(total))
	msg = append(msg, hdr...)
	msg = append(msg, args...)

	// Build SCM_RIGHTS control message. One fd = 4 bytes payload.
	oobLen := syscall.CmsgSpace(4)
	oob := make([]byte, oobLen)
	cmsghdr := (*syscall.Cmsghdr)(unsafe.Pointer(&oob[0]))
	cmsghdr.Level = syscall.SOL_SOCKET
	cmsghdr.Type = syscall.SCM_RIGHTS
	cmsghdr.SetLen(syscall.CmsgLen(4))
	fdBytes := (*[4]byte)(unsafe.Pointer(&fd))
	oobOffset := int(cmsghdr.Len)
	copy(oob[oobOffset:oobLen], fdBytes[:])

	iov := syscall.Iovec{Base: &msg[0]}
	iov.SetLen(len(msg))
	var msghdr syscall.Msghdr
	msghdr.Iov = &iov
	msghdr.Iovlen = 1
	msghdr.Control = &oob[0]
	msghdr.SetControllen(len(oob))

	if _, _, errno := syscall.Syscall(syscall.SYS_SENDMSG, uintptr(c.fd), uintptr(unsafe.Pointer(&msghdr)), 0); errno != 0 {
		return syscall.Errno(errno)
	}
	return nil
}

// ReadEvent reads the next event message and returns its parsed header.
// Returns (header{nil,}, nil, io.EOF) if the connection is closed.
func (c *Conn) ReadEvent(buf []byte) (header, []byte, error) {
	return readMessage(int(c.fd), buf)
}