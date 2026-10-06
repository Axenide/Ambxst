// Copyright (c) 2016 Andreas Auernhammer. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

// Originally from:
// https://github.com/aead/chacha20/tree/master/chacha

//go:build !(gc && (386 || amd64 || arm64))

package xchacha

func initialize(state *[64]byte, key []byte, nonce *[16]byte) {
	initializeGeneric(state, key, nonce)
}

func xorKeyStream(dst, src []byte, block, state *[64]byte, rounds int) int {
	return xorKeyStreamGeneric(dst, src, block, state, rounds)
}
