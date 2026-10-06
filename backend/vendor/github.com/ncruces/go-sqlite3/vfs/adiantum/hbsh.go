package adiantum

import (
	"encoding/binary"
	"encoding/hex"
	"io"

	"lukechampine.com/adiantum/hbsh"

	"github.com/ncruces/go-sqlite3"
	"github.com/ncruces/go-sqlite3/internal/errutil"
	"github.com/ncruces/go-sqlite3/internal/util"
	"github.com/ncruces/go-sqlite3/util/vfsutil"
	"github.com/ncruces/go-sqlite3/vfs"
)

type hbshVFS struct {
	vfs.VFS
	init HBSHCreator
}

func (h *hbshVFS) Open(name string, flags vfs.OpenFlag) (vfs.File, vfs.OpenFlag, error) {
	// notest // OpenFilename is called instead
	if name == "" {
		return h.OpenFilename(nil, flags)
	}
	return nil, flags, sqlite3.CANTOPEN
}

func (h *hbshVFS) OpenFilename(name *vfs.Filename, flags vfs.OpenFlag) (file vfs.File, _ vfs.OpenFlag, err error) {
	file, flags, err = vfsutil.WrapOpenFilename(h.VFS, name, flags)

	// Encrypt everything except super journals and memory files.
	if err != nil || flags&(vfs.OPEN_SUPER_JOURNAL|vfs.OPEN_MEMORY) != 0 {
		return file, flags, err
	}

	var hbsh *hbsh.HBSH
	if f, ok := vfsutil.UnwrapFile[*hbshFile](name.DatabaseFile()); ok {
		hbsh = f.hbsh
	} else {
		var key []byte
		if params := name.URIParameters(); name == nil {
			key = h.init.KDF("") // Temporary files get a random key.
		} else if t, ok := params["key"]; ok {
			key = []byte(t[0])
		} else if t, ok := params["hexkey"]; ok {
			key, _ = hex.DecodeString(t[0])
		} else if t, ok := params["textkey"]; ok && len(t[0]) > 0 {
			key = h.init.KDF(t[0])
		} else if flags&vfs.OPEN_MAIN_DB != 0 {
			// Main databases may have their key specified as a PRAGMA.
			return &hbshFile{File: file, init: h.init}, flags, nil
		}
		hbsh = h.init.HBSH(key)
	}

	if hbsh == nil {
		file.Close()
		return nil, flags, sqlite3.IOERR_BADKEY
	}
	return &hbshFile{File: file, hbsh: hbsh, init: h.init}, flags, nil
}

// Larger blocks improve both security (wide-block cipher)
// and throughput (cheap hashes amortize the block cipher's cost).
// Use the default SQLite page size;
// smaller pages pay the cost of unaligned access.
// https://sqlite.org/pgszchng2016.html
const (
	tweakSize = 8
	blockSize = 4096
)

// Ensure blockSize is a power of two.
var _ [0]struct{} = [blockSize & (blockSize - 1)]struct{}{}

func roundDown(i int64) int64 {
	return i &^ (blockSize - 1)
}

func roundUp[T int | int64](i T) T {
	return (i + (blockSize - 1)) &^ (blockSize - 1)
}

type hbshFile struct {
	vfs.File
	init  HBSHCreator
	hbsh  *hbsh.HBSH
	tweak [tweakSize]byte
	block [blockSize]byte
}

func (h *hbshFile) Pragma(name, value string) (string, error) {
	var key []byte
	switch name {
	case "key":
		key = []byte(value)
	case "hexkey":
		key, _ = hex.DecodeString(value)
	case "textkey":
		if len(value) > 0 {
			key = h.init.KDF(value)
		}
	default:
		return vfsutil.WrapPragma(h.File, name, value)
	}

	if h.hbsh = h.init.HBSH(key); h.hbsh != nil {
		return "ok", nil
	}
	return "", sqlite3.IOERR_BADKEY
}

func (h *hbshFile) ReadAt(p []byte, off int64) (n int, err error) {
	if h.hbsh == nil {
		// Only OPEN_MAIN_DB can have a missing key.
		if off == 0 && len(p) == 100 {
			// SQLite is trying to read the header of a database file.
			// Pretend the file is empty so the key may be specified as a PRAGMA.
			return 0, io.EOF
		}
		return 0, sqlite3.CANTOPEN
	}

	min := roundDown(off)
	max := roundUp(off + int64(len(p)))

	// Read one block at a time.
	for ; min < max; min += blockSize {
		m, err := h.File.ReadAt(h.block[:], min)
		if m != blockSize {
			return n, err
		}

		binary.LittleEndian.PutUint64(h.tweak[:], uint64(min))
		data := h.hbsh.Decrypt(h.block[:], h.tweak[:])

		if off > min {
			data = data[off-min:]
		}
		n += copy(p[n:], data)
	}

	if n != len(p) {
		panic(errutil.AssertErr())
	}
	return n, nil
}

func (h *hbshFile) WriteAt(p []byte, off int64) (n int, err error) {
	if h.hbsh == nil {
		return 0, sqlite3.READONLY
	}

	min := roundDown(off)
	max := roundUp(off + int64(len(p)))

	// Write one block at a time.
	for ; min < max; min += blockSize {
		binary.LittleEndian.PutUint64(h.tweak[:], uint64(min))
		data := h.block[:]

		if off > min || len(p[n:]) < blockSize {
			// Partial block write: read-update-write.
			m, err := h.File.ReadAt(h.block[:], min)
			if m == blockSize {
				data = h.hbsh.Decrypt(h.block[:], h.tweak[:])
			} else if err != io.EOF {
				return n, err
			} else {
				// Writing past the EOF.
				// We're either appending an entirely new block,
				// or the final block was only partially written.
				// A partially written block can't be decrypted,
				// and is as good as corrupt.
				// Either way, zero pad the file to the next block size.
				clear(data)
			}
			if off > min {
				data = data[off-min:]
			}
		}

		t := copy(data, p[n:])
		h.hbsh.Encrypt(h.block[:], h.tweak[:])

		m, err := h.File.WriteAt(h.block[:], min)
		if m != blockSize {
			return n, err
		}
		n += t
	}

	if n != len(p) {
		panic(errutil.AssertErr())
	}
	return n, nil
}

func (h *hbshFile) DeviceCharacteristics() vfs.DeviceCharacteristic {
	var _ [0]struct{} = [blockSize - 4096]struct{}{} // Ensure blockSize is 4K.
	return h.File.DeviceCharacteristics() & (0 |
		// These flags are safe:
		vfs.IOCAP_ATOMIC4K |
		vfs.IOCAP_IMMUTABLE |
		vfs.IOCAP_SEQUENTIAL |
		vfs.IOCAP_SUBPAGE_READ |
		vfs.IOCAP_BATCH_ATOMIC |
		vfs.IOCAP_UNDELETABLE_WHEN_OPEN)
}

func (h *hbshFile) SectorSize() int {
	return util.LCM(h.File.SectorSize(), blockSize)
}

func (h *hbshFile) Truncate(size int64) error {
	return h.File.Truncate(roundUp(size))
}

func (h *hbshFile) ChunkSize(size int) {
	vfsutil.WrapChunkSize(h.File, roundUp(size))
}

func (h *hbshFile) SizeHint(size int64) error {
	return vfsutil.WrapSizeHint(h.File, roundUp(size))
}

// Wrap optional methods.

func (h *hbshFile) Unwrap() vfs.File {
	return h.File // notest
}

func (h *hbshFile) SharedMemory() vfs.SharedMemory {
	return vfsutil.WrapSharedMemory(h.File) // notest
}

func (h *hbshFile) LockState() vfs.LockLevel {
	return vfsutil.WrapLockState(h.File) // notest
}

func (h *hbshFile) PersistentWAL() bool {
	return vfsutil.WrapPersistWAL(h.File) // notest
}

func (h *hbshFile) SetPersistentWAL(keepWAL bool) {
	vfsutil.WrapSetPersistWAL(h.File, keepWAL) // notest
}

func (h *hbshFile) HasMoved() (bool, error) {
	return vfsutil.WrapHasMoved(h.File) // notest
}

func (h *hbshFile) Overwrite() error {
	return vfsutil.WrapOverwrite(h.File) // notest
}

func (h *hbshFile) SyncSuper(super string) error {
	return vfsutil.WrapSyncSuper(h.File, super) // notest
}

func (h *hbshFile) CommitPhaseTwo() error {
	return vfsutil.WrapCommitPhaseTwo(h.File) // notest
}

func (h *hbshFile) BeginAtomicWrite() error {
	return vfsutil.WrapBeginAtomicWrite(h.File) // notest
}

func (h *hbshFile) CommitAtomicWrite() error {
	return vfsutil.WrapCommitAtomicWrite(h.File) // notest
}

func (h *hbshFile) RollbackAtomicWrite() error {
	return vfsutil.WrapRollbackAtomicWrite(h.File) // notest
}

func (h *hbshFile) CheckpointStart() {
	vfsutil.WrapCheckpointStart(h.File) // notest
}

func (h *hbshFile) CheckpointDone() {
	vfsutil.WrapCheckpointDone(h.File) // notest
}

func (h *hbshFile) BusyHandler(handler func() bool) {
	vfsutil.WrapBusyHandler(h.File, handler) // notest
}
