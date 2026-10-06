package adiantum // import "lukechampine.com/adiantum"

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"encoding/binary"
	"math/bits"

	"golang.org/x/crypto/poly1305"
	"lukechampine.com/adiantum/hbsh"
	"lukechampine.com/adiantum/internal/xchacha"
	"lukechampine.com/adiantum/nh"
)

// hashNHPoly1305 implements hbsh.Hash with NH and Poly1305.
type hashNHPoly1305 struct {
	keyT  [32]byte
	keyM  [32]byte
	keyNH [1072]byte
}

// Sum implements hbsh.Hash.
func (h *hashNHPoly1305) Sum(dst, msg, tweak []byte) []byte {
	// poly1305 hash 8*len(msg) and tweak with keyT
	tweakBuf := make([]byte, 16+24)
	binary.LittleEndian.PutUint64(tweakBuf[:8], uint64(8*len(msg)))
	var outT [16]byte
	poly1305.Sum(&outT, append(tweakBuf[:16], tweak...), &h.keyT)

	// NH hash message in chunks of up to 1024 bytes, then poly1305 those hashes
	// with keyM
	mac := poly1305.New(&h.keyM)
	var outNH [32]byte
	for len(msg) >= 1024 {
		nh.Sum(&outNH, msg[:1024], h.keyNH[:])
		mac.Write(outNH[:])
		msg = msg[1024:]
	}
	// handle final (incomplete) chunk, if it exists
	if len(msg) > 0 {
		// if necessary, pad to multiple of 16 bytes
		if len(msg)%16 != 0 {
			var pad [1024]byte
			n := copy(pad[:], msg)
			n += 16 - (n % 16)
			msg = pad[:n]
		}
		nh.Sum(&outNH, msg, h.keyNH[:])
		mac.Write(outNH[:])
	}
	var outM [16]byte
	mac.Sum(outM[:0])

	// return the sum of the hashes
	sum := addHashes(outT, outM)
	return append(dst[:0], sum[:]...)
}

type chachaStream struct {
	key    []byte
	rounds int
}

func (s *chachaStream) XORKeyStream(msg, nonce []byte) {
	nonceBuf := make([]byte, 24)
	n := copy(nonceBuf, nonce)
	nonceBuf[n] = 1
	xchacha.XORKeyStream(msg, msg, nonceBuf, s.key, s.rounds)
}

func makeAdiantum(key []byte, chachaRounds int) (hbsh.StreamCipher, cipher.Block, hbsh.TweakableHash) {
	if len(key) != xchacha.KeySize {
		panic("adiantum: key must be 32 bytes long")
	}
	// create stream cipher and derive block+hash keys
	stream := &chachaStream{key, chachaRounds}
	keyBuf := bytes.NewBuffer(make([]byte, 32+16+16+1072))
	stream.XORKeyStream(keyBuf.Bytes(), nil)
	block, _ := aes.NewCipher(keyBuf.Next(32))
	hash := new(hashNHPoly1305)
	copy(hash.keyT[:16], keyBuf.Next(16))
	copy(hash.keyM[:16], keyBuf.Next(16))
	copy(hash.keyNH[:], keyBuf.Next(1072)) // enough to hash a 1024-byte message
	return stream, block, hash
}

// New8 returns an Adiantum cipher with the specified key, using XChaCha8 as the
// stream cipher. The key must be 32 bytes.
func New8(key []byte) *hbsh.HBSH {
	return hbsh.New(makeAdiantum(key, 8))
}

// New returns an Adiantum cipher with the specified key. The key must be 32
// bytes.
func New(key []byte) *hbsh.HBSH {
	return hbsh.New(makeAdiantum(key, 12))
}

// New20 returns an Adiantum cipher with the specified key, using XChaCha20 as
// the stream cipher. The key must be 32 bytes.
func New20(key []byte) *hbsh.HBSH {
	return hbsh.New(makeAdiantum(key, 20))
}

func addHashes(x, y [16]byte) [16]byte {
	x1 := binary.LittleEndian.Uint64(x[:8])
	x2 := binary.LittleEndian.Uint64(x[8:16])
	y1 := binary.LittleEndian.Uint64(y[:8])
	y2 := binary.LittleEndian.Uint64(y[8:16])
	r1, c := bits.Add64(x1, y1, 0)
	r2, _ := bits.Add64(x2, y2, c)
	binary.LittleEndian.PutUint64(x[:8], r1)
	binary.LittleEndian.PutUint64(x[8:], r2)
	return x
}
