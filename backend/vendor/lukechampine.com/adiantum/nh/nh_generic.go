//go:build !(386 || amd64 || arm || arm64 || mipsle || mips64le || ppc64le || riscv || riscv64 || wasm)

package nh

import "encoding/binary"

func sum(out *[32]byte, m []byte, key []byte) {
	var k [16]uint32
	for i := 4; i < 16; i++ {
		k[i] = binary.LittleEndian.Uint32(key[:4])
		key = key[4:]
	}

	var sums [4]uint64
	for len(m) >= 16 && len(key) >= 16 {
		k[0] = k[4]
		k[1] = k[5]
		k[2] = k[6]
		k[3] = k[7]
		k[4] = k[8]
		k[5] = k[9]
		k[6] = k[10]
		k[7] = k[11]
		k[8] = k[12]
		k[9] = k[13]
		k[10] = k[14]
		k[11] = k[15]
		k[12] = binary.LittleEndian.Uint32(key[0:4])
		k[13] = binary.LittleEndian.Uint32(key[4:8])
		k[14] = binary.LittleEndian.Uint32(key[8:12])
		k[15] = binary.LittleEndian.Uint32(key[12:16])

		m0 := binary.LittleEndian.Uint32(m[0:4])
		m1 := binary.LittleEndian.Uint32(m[4:8])
		m2 := binary.LittleEndian.Uint32(m[8:12])
		m3 := binary.LittleEndian.Uint32(m[12:16])

		sums[0] += uint64(m0+k[0]) * uint64(m2+k[2])
		sums[1] += uint64(m0+k[4]) * uint64(m2+k[6])
		sums[2] += uint64(m0+k[8]) * uint64(m2+k[10])
		sums[3] += uint64(m0+k[12]) * uint64(m2+k[14])
		sums[0] += uint64(m1+k[1]) * uint64(m3+k[3])
		sums[1] += uint64(m1+k[5]) * uint64(m3+k[7])
		sums[2] += uint64(m1+k[9]) * uint64(m3+k[11])
		sums[3] += uint64(m1+k[13]) * uint64(m3+k[15])

		key = key[16:]
		m = m[16:]
	}

	for i := range sums {
		binary.LittleEndian.PutUint64(out[i*8:], sums[i])
	}
}
