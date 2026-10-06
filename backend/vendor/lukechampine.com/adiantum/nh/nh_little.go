//go:build (amd64 && !gc) || 386 || arm || arm64 || mipsle || mips64le || ppc64le || riscv || riscv64 || wasm

package nh

import "unsafe"

func sum(out *[32]byte, m, k []byte) {
	sumLittleEndian(
		(*[4]uint64)(unsafe.Pointer(out)),
		unsafe.Slice((*uint32)(unsafe.Pointer(unsafe.SliceData(m))), len(m)/4),
		unsafe.Slice((*uint32)(unsafe.Pointer(unsafe.SliceData(k))), len(k)/4))
}

func sumLittleEndian(out *[4]uint64, m, k []uint32) {
	out[0] = 0
	out[1] = 0
	out[2] = 0
	out[3] = 0

	for len(m) >= 4 && len(k) >= 16 {
		m0 := m[0]
		m1 := m[1]
		m2 := m[2]
		m3 := m[3]

		out[0] += uint64(m0+k[0]) * uint64(m2+k[2])
		out[1] += uint64(m0+k[4]) * uint64(m2+k[6])
		out[2] += uint64(m0+k[8]) * uint64(m2+k[10])
		out[3] += uint64(m0+k[12]) * uint64(m2+k[14])
		out[0] += uint64(m1+k[1]) * uint64(m3+k[3])
		out[1] += uint64(m1+k[5]) * uint64(m3+k[7])
		out[2] += uint64(m1+k[9]) * uint64(m3+k[11])
		out[3] += uint64(m1+k[13]) * uint64(m3+k[15])

		k = k[4:]
		m = m[4:]
	}
}
