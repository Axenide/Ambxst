//go:build gc

// Direct translation of nh-sse2-x86_64.S from github.com/google/adiantum

#define PASS0_SUMS  X0
#define PASS1_SUMS  X1
#define PASS2_SUMS  X2
#define PASS3_SUMS  X3
#define K0          X4
#define K1          X5
#define K2          X6
#define K3          X7
#define T0          X8
#define T1          X9
#define T2          X10
#define T3          X11
#define T4          X12
#define T5          X13
#define T6          X14
#define T7          X15
#define KEY         DI
#define MESSAGE     SI
#define MESSAGE_LEN	DX
#define HASH        CX

#define STRIDE(k0, k1, k2, k3, offset) \
	MOVOU   offset(MESSAGE), T1; \
	MOVOU   offset(KEY), k3;     \
	MOVO    T1, T2;              \
	MOVO    T1, T3;              \
	PADDD   T1, k0;              \
	PADDD   k1, T1;              \
	PADDD   k2, T2;              \
	PADDD   k3, T3;              \
	PSHUFD  $0x10, k0, T4;       \
	PSHUFD  $0x32, k0, k0;       \
	PSHUFD  $0x10, T1, T5;       \
	PSHUFD  $0x32, T1, T1;       \
	PSHUFD  $0x10, T2, T6;       \
	PSHUFD  $0x32, T2, T2;       \
	PSHUFD  $0x10, T3, T7;       \
	PSHUFD  $0x32, T3, T3;       \
	PMULULQ T4, k0;              \
	PMULULQ T5, T1;              \
	PMULULQ T6, T2;              \
	PMULULQ T7, T3;              \
	PADDQ   k0, PASS0_SUMS;      \
	PADDQ   T1, PASS1_SUMS;      \
	PADDQ   T2, PASS2_SUMS;      \
	PADDQ   T3, PASS3_SUMS

// func sumSSE2(out *[32]byte, m []byte, key []byte)
TEXT ·sumSSE2(SB), 4, $0-56
	MOVQ out+0(FP), HASH
	MOVQ m_base+8(FP), MESSAGE
	MOVQ m_len+16(FP), MESSAGE_LEN
	MOVQ key_base+32(FP), KEY

	MOVOU 0*16(KEY), K0
	MOVOU 1*16(KEY), K1
	MOVOU 2*16(KEY), K2
	ADDQ  $48, KEY
	PXOR  PASS0_SUMS, PASS0_SUMS
	PXOR  PASS1_SUMS, PASS1_SUMS
	PXOR  PASS2_SUMS, PASS2_SUMS
	PXOR  PASS3_SUMS, PASS3_SUMS

	SUBQ $64, MESSAGE_LEN
	JL   LLOOP4_DONE

LLOOP4:
	STRIDE(K0, K1, K2, K3, 0*16)
	STRIDE(K1, K2, K3, K0, 1*16)
	STRIDE(K2, K3, K0, K1, 2*16)
	STRIDE(K3, K0, K1, K2, 3*16)
	ADDQ $64, KEY
	ADDQ $64, MESSAGE
	SUBQ $64, MESSAGE_LEN
	JGE  LLOOP4

LLOOP4_DONE:
	ANDQ $0x3f, MESSAGE_LEN
	JZ   LDONE
	STRIDE(K0, K1, K2, K3, 0*16)

	SUBQ $16, MESSAGE_LEN
	JZ   LDONE
	STRIDE(K1, K2, K3, K0, 1*16)

	SUBQ $16, MESSAGE_LEN
	JZ   LDONE
	STRIDE(K2, K3, K0, K1, 2*16)

LDONE:
	MOVO       PASS0_SUMS, T0
	MOVO       PASS2_SUMS, T1
	PUNPCKLQDQ PASS1_SUMS, T0
	PUNPCKLQDQ PASS3_SUMS, T1
	PUNPCKHQDQ PASS1_SUMS, PASS0_SUMS
	PUNPCKHQDQ PASS3_SUMS, PASS2_SUMS
	PADDQ      PASS0_SUMS, T0
	PADDQ      PASS2_SUMS, T1
	MOVOU      T0, 0*16(HASH)
	MOVOU      T1, 1*16(HASH)
	RET
