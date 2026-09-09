//go:build gc

package nh

import "golang.org/x/sys/cpu"

//go:noescape
func sumAsm(out *[32]byte, m []byte, key []byte)

//go:noescape
func sumAVX2(out *[32]byte, m []byte, key []byte)

//go:noescape
func sumSSE2(out *[32]byte, m []byte, key []byte)

func sum(out *[32]byte, m []byte, key []byte) {
	switch {
	case cpu.X86.HasAVX2:
		sumAVX2(out, m, key)
	case cpu.X86.HasSSE2:
		sumSSE2(out, m, key)
	default:
		sumAsm(out, m, key)
	}
}
