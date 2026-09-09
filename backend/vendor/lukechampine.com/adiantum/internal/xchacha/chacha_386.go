// Copyright (c) 2016 Andreas Auernhammer. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

// Originally from:
// https://github.com/aead/chacha20/tree/master/chacha

//go:build gc

package xchacha

import "golang.org/x/sys/cpu"

func init() {
	useSSE2 = cpu.X86.HasSSE2
	useSSSE3 = cpu.X86.HasSSSE3
}

func initialize(state *[64]byte, key []byte, nonce *[16]byte) {
	initializeGeneric(state, key, nonce)
}

// This function is implemented in chacha_386.s
//
//go:noescape
func xorKeyStreamSSE2(dst, src []byte, block, state *[64]byte, rounds int) int

func xorKeyStream(dst, src []byte, block, state *[64]byte, rounds int) int {
	if useSSE2 {
		return xorKeyStreamSSE2(dst, src, block, state, rounds)
	} else {
		return xorKeyStreamGeneric(dst, src, block, state, rounds)
	}
}
