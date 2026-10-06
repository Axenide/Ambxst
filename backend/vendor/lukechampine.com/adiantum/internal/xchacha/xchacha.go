package xchacha

// KeySize is the size of an XChaCha key.
const KeySize = 32

// NonceSize is the size of an XChaCha nonce.
const NonceSize = 24

// XORKeyStream xors the bytes of src with the key stream derived from the key
// and nonce.
func XORKeyStream(dst, src, nonce, key []byte, rounds int) {
	if len(dst) < len(src) {
		panic("xchacha: dst buffer is too small")
	}
	if len(key) != KeySize {
		panic("xchacha: bad key length")
	}
	if len(nonce) != NonceSize {
		panic("xchacha: bad nonce length")
	}
	if rounds != 20 && rounds != 12 && rounds != 8 {
		panic("xchacha: bad number of rounds")
	}

	// expand nonce with HChaCha
	var Nonce [16]byte
	var tmpKey [32]byte
	var hNonce [16]byte
	copy(hNonce[:], nonce[:16])
	copy(tmpKey[:], key)
	hChaChaGeneric(&tmpKey, &hNonce, &tmpKey, rounds)
	copy(Nonce[8:], nonce[16:])

	var block, state [64]byte
	initialize(&state, tmpKey[:], &Nonce)
	xorKeyStream(dst, src, &block, &state, rounds)
}
