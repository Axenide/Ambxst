package hbsh // import "lukechampine.com/adiantum/hbsh"

import (
	"crypto/cipher"
	"encoding/binary"
	"math/bits"
)

// A StreamCipher xors msg with a keystream, modified by a nonce.
type StreamCipher interface {
	XORKeyStream(msg, nonce []byte)
}

// TweakableHash is a tweakable cryptographic hash function. It appends the hash
// of src to dst and returns it.
type TweakableHash interface {
	Sum(dst, src, tweak []byte) []byte
}

// HBSH is a cipher using the HBSH encryption mode.
type HBSH struct {
	stream StreamCipher
	block  cipher.Block
	thash  TweakableHash

	hashBuf [32]byte
}

func (h *HBSH) streamXOR(nonce, msg []byte) []byte {
	h.stream.XORKeyStream(msg, nonce)
	return msg
}

func (h *HBSH) hash(tweak, msg []byte) []byte {
	return h.thash.Sum(h.hashBuf[:0], msg, tweak)
}

func (h *HBSH) encryptBlock(src []byte) []byte {
	h.block.Encrypt(src, src)
	return src
}

func (h *HBSH) decryptBlock(src []byte) []byte {
	h.block.Decrypt(src, src)
	return src
}

// Encrypt encrypts block using the specified tweak. The block must be at least
// 16 bytes. The size of the tweak is restricted by the underlying primitives.
func (h *HBSH) Encrypt(block, tweak []byte) []byte {
	pl, pr := block[:len(block)-16], block[len(block)-16:]
	pm := blockAdd(pr, h.hash(tweak, pl))
	cm := h.encryptBlock(pm)
	cl := h.streamXOR(cm, pl)
	cr := blockSub(cm, h.hash(tweak, cl))
	return append(cl, cr...)
}

// Decrypt decrypts block using the specified tweak. The block must be at least
// 16 bytes. The size of the tweak is restricted by the underlying primitives.
func (h *HBSH) Decrypt(block, tweak []byte) []byte {
	cl, cr := block[:len(block)-16], block[len(block)-16:]
	cm := blockAdd(cr, h.hash(tweak, cl))
	pl := h.streamXOR(cm, cl)
	pm := h.decryptBlock(cm)
	pr := blockSub(pm, h.hash(tweak, pl))
	return append(pl, pr...)
}

// New returns an HBSH cipher using the specified primitives.
func New(stream StreamCipher, block cipher.Block, hash TweakableHash) *HBSH {
	return &HBSH{
		stream: stream,
		block:  block,
		thash:  hash,
	}
}

func blockAdd(x []byte, y []byte) []byte {
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

func blockSub(x []byte, y []byte) []byte {
	x1 := binary.LittleEndian.Uint64(x[:8])
	x2 := binary.LittleEndian.Uint64(x[8:16])
	y1 := binary.LittleEndian.Uint64(y[:8])
	y2 := binary.LittleEndian.Uint64(y[8:16])

	r1, c := bits.Sub64(x1, y1, 0)
	r2, _ := bits.Sub64(x2, y2, c)

	binary.LittleEndian.PutUint64(x[:8], r1)
	binary.LittleEndian.PutUint64(x[8:], r2)
	return x
}
