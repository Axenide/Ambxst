//go:build gc

// Direct translation of nh-avx2-x86_64.S from github.com/google/adiantum

#define PASS0_SUMS  Y0
#define PASS1_SUMS  Y1
#define PASS2_SUMS  Y2
#define PASS3_SUMS  Y3
#define K0          Y4
#define K0_XMM      X4
#define K1          Y5
#define K1_XMM      X5
#define K2          Y6
#define K2_XMM      X6
#define K3          Y7
#define K3_XMM      X7
#define T0          Y8
#define T1          Y9
#define T2          Y10
#define T2_XMM      X10
#define T3          Y11
#define T3_XMM      X11
#define T4          Y12
#define T5          Y13
#define T6          Y14
#define T7          Y15
#define KEY         DI
#define MESSAGE     SI
#define MESSAGE_LEN DX
#define HASH        CX

#define STRIDE2X(k0, k1, k2, k3) \
	VPADDD   k0, T3, T0;                 \
	VPADDD   k1, T3, T1;                 \
	VPADDD   k2, T3, T2;                 \
	VPADDD   k3, T3, T3;                 \
	VPSHUFD  $0x10, T0, T4;              \
	VPSHUFD  $0x32, T0, T0;              \
	VPSHUFD  $0x10, T1, T5;              \
	VPSHUFD  $0x32, T1, T1;              \
	VPSHUFD  $0x10, T2, T6;              \
	VPSHUFD  $0x32, T2, T2;              \
	VPSHUFD  $0x10, T3, T7;              \
	VPSHUFD  $0x32, T3, T3;              \
	VPMULUDQ T4, T0, T0;                 \
	VPMULUDQ T5, T1, T1;                 \
	VPMULUDQ T6, T2, T2;                 \
	VPMULUDQ T7, T3, T3;                 \
	VPADDQ   T0, PASS0_SUMS, PASS0_SUMS; \
	VPADDQ   T1, PASS1_SUMS, PASS1_SUMS; \
	VPADDQ   T2, PASS2_SUMS, PASS2_SUMS; \
	VPADDQ   T3, PASS3_SUMS, PASS3_SUMS

// func sumAVX2(out *[32]byte, m []byte, key []byte)
TEXT ·sumAVX2(SB), 4, $0-56
	MOVQ out+0(FP), HASH
	MOVQ m_base+8(FP), MESSAGE
	MOVQ m_len+16(FP), MESSAGE_LEN
	MOVQ key_base+32(FP), KEY

	VMOVDQU 0*16(KEY), K0
	VMOVDQU 1*16(KEY), K1
	ADDQ    $32, KEY
	VPXOR   PASS0_SUMS, PASS0_SUMS, PASS0_SUMS
	VPXOR   PASS1_SUMS, PASS1_SUMS, PASS1_SUMS
	VPXOR   PASS2_SUMS, PASS2_SUMS, PASS2_SUMS
	VPXOR   PASS3_SUMS, PASS3_SUMS, PASS3_SUMS

	SUBQ $64, MESSAGE_LEN
	JL   LLOOP4_DONE

LLOOP4:
	VMOVDQU (MESSAGE), T3
	VMOVDQU 0*16(KEY), K2
	VMOVDQU 1*16(KEY), K3
	STRIDE2X(K0, K1, K2, K3)

	VMOVDQU 2*16(MESSAGE), T3
	VMOVDQU 2*16(KEY), K0
	VMOVDQU 3*16(KEY), K1
	STRIDE2X(K2, K3, K0, K1)

	ADDQ $64, MESSAGE
	ADDQ $64, KEY
	SUBQ $64, MESSAGE_LEN
	JGE  LLOOP4

LLOOP4_DONE:
	ANDQ $0x3f, MESSAGE_LEN
	JZ   LDONE

	CMPQ MESSAGE_LEN, $32
	JL   LLAST

	VMOVDQU (MESSAGE), T3
	VMOVDQU 0*16(KEY), K2
	VMOVDQU 1*16(KEY), K3
	STRIDE2X(K0, K1, K2, K3)
	ADDQ    $32, MESSAGE
	ADDQ    $32, KEY
	SUBQ    $32, MESSAGE_LEN
	JZ      LDONE
	VMOVDQA K2, K0
	VMOVDQA K3, K1

LLAST:
	VMOVDQU (MESSAGE), T3_XMM
	VMOVDQA K0_XMM, K0_XMM
	VMOVDQA K1_XMM, K1_XMM
	VMOVDQU 0*16(KEY), K2_XMM
	VMOVDQU 1*16(KEY), K3_XMM
	STRIDE2X(K0, K1, K2, K3)

LDONE:
	VPUNPCKLQDQ PASS1_SUMS, PASS0_SUMS, T0
	VPUNPCKHQDQ PASS1_SUMS, PASS0_SUMS, T1
	VPUNPCKLQDQ PASS3_SUMS, PASS2_SUMS, T2
	VPUNPCKHQDQ PASS3_SUMS, PASS2_SUMS, T3

	VINSERTI128 $0x01, T2_XMM, T0, T4
	VINSERTI128 $0x01, T3_XMM, T1, T5
	VPERM2I128  $0x31, T2, T0, T0
	VPERM2I128  $0x31, T3, T1, T1

	VPADDQ  T5, T4, T4
	VPADDQ  T1, T0, T0
	VPADDQ  T4, T0, T0
	VMOVDQU T0, (HASH)
	RET
