//go:build gc

#define Dst DI
#define Src SI
#define N   DX
#define Key BX
#define Sum0 R10
#define Sum1 R11
#define Sum2 R12
#define Sum3 R13

#define ROUND(m0, k0, m1, k1, s) \
	MOVL  m0*4(Src), R8; \
	ADDL  k0*4(Key), R8; \
	MOVL  m1*4(Src), R9; \
	ADDL  k1*4(Key), R9; \
	IMULQ R8, R9;        \
	ADDQ  R9, s

// func sumAsm(out *[32]byte, m []byte, key []byte)
TEXT ·sumAsm(SB), 4, $0-56
	MOVQ out+0(FP), Dst
	MOVQ m_base+8(FP), Src
	MOVQ m_len+16(FP), N
	MOVQ key_base+32(FP), Key

	// initialize sums to 0
	XORQ Sum0, Sum0
	XORQ Sum1, Sum1
	XORQ Sum2, Sum2
	XORQ Sum3, Sum3

NH_LOOP:
	// process next 16 bytes
	ROUND( 0,  0, 2,  2, Sum0)
	ROUND( 0,  4, 2,  6, Sum1)
	ROUND( 0,  8, 2, 10, Sum2)
	ROUND( 0, 12, 2, 14, Sum3)
	ROUND( 1,  1, 3,  3, Sum0)
	ROUND( 1,  5, 3,  7, Sum1)
	ROUND( 1,  9, 3, 11, Sum2)
	ROUND( 1, 13, 3, 15, Sum3)

	// advance pointers
	ADDQ $16, Src
	ADDQ $16, Key
	SUBQ $16, N
	JNZ  NH_LOOP

	// copy sums to out
	MOVQ Sum0, 0*8(Dst)
	MOVQ Sum1, 1*8(Dst)
	MOVQ Sum2, 2*8(Dst)
	MOVQ Sum3, 3*8(Dst)
	RET
