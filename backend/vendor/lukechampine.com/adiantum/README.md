adiantum
--------

[![GoDoc](https://godoc.org/lukechampine.com/adiantum?status.svg)](https://godoc.org/lukechampine.com/adiantum)
[![Go Report Card](http://goreportcard.com/badge/lukechampine.com/adiantum)](https://goreportcard.com/report/lukechampine.com/adiantum)

```
go get lukechampine.com/adiantum
```

This repo contains an implementation of [Adiantum](https://github.com/google/adiantum), a tweakable and length-preserving
encryption cipher.

Adiantum is an instance of HBSH, an encryption mode designed for disk
encryption. In addition to being tweakable and length-preserving, HBSH is a
"super-pseudorandom permutation", meaning that changing a single bit of the
plaintext scrambles the entire ciphertext; this is in contrast to the most
common disk encryption mode, XTS, where one bitflip scrambles only 16 bytes of
the ciphertext.

HBSH is a construction, not a primitive. Specifically, it is built from a stream
cipher, a block cipher, and a hash function. The [original paper](https://eprint.iacr.org/2018/720.pdf) provides a proof
that this construction is secure if the underlying primitives are secure.

Adiantum uses XChaCha12 for its stream cipher, AES for its block cipher, and NH
and Poly1305 for hashing. The paper also describes a closely-related instance of
HBSH called HPolyC, which is slower on large messages, but more key-agile and
simpler to implement.

This repo currently contains implementations of Adiantum and HPolyC, with 8, 12,
and 20-round variants. (12 rounds is the standard variant.) You can also
implement your own HBSH variants using the `hbsh` package.


## Usage

```go
import "lukechampine.com/adiantum"

func main() {
    key := make([]byte, 32) // in practice, read this from crypto/rand
    cipher := adiantum.New(key)
    tweak := make([]byte, 12) // can be any length
    plaintext := []byte("Hello, world!")
    ciphertext := cipher.Encrypt(plaintext, tweak)
    recovered := cipher.Decrypt(ciphertext, tweak)
    println(string(recovered)) // Hello, world!
}
```

To use Adiantum for disk encryption, simply set the tweak equal to the disk
sector index. For example, to encrypt *n* consecutive 4096-byte sectors,
increment the tweak by 1 after encrypting each sector.

It is important to understand the threat model for disk encryption.
Specifically, disk encryption is most effective when the attacker only sees one
version of the disk contents. It is less effective when the attacker can sample
the contents at will. This is because writing the same sector to the same
location will result in the same ciphertext. As such, an attacker with multiple
samples can detect if you "undo" a disk write by overwriting a sector with a
previous version of that sector. Worse, an attacker can replace a sector with a
previously-written sector, and it will decrypt just fine. [See
here](https://sockpuppet.org/blog/2014/04/30/you-dont-want-xts/) for a more
detailed critique of disk encryption and some recommended alternatives.


## Benchmarks

Tested on an i5-7600K @ 3.80GHz. Results will likely be slower on non-amd64
architectures.

```
BenchmarkAdiantum/XChaCha8_Encrypt-4      1479 ns/op     2768.92 MB/s      0 allocs/op
BenchmarkAdiantum/XChaCha8_Decrypt-4      1477 ns/op     2772.76 MB/s      0 allocs/op
BenchmarkAdiantum/XChaCha12_Encrypt-4     1748 ns/op     2341.98 MB/s      0 allocs/op
BenchmarkAdiantum/XChaCha12_Decrypt-4     1748 ns/op     2342.57 MB/s      0 allocs/op
BenchmarkAdiantum/XChaCha20_Encrypt-4     2288 ns/op     1789.87 MB/s      0 allocs/op
BenchmarkAdiantum/XChaCha20_Decrypt-4     2283 ns/op     1793.88 MB/s      0 allocs/op

BenchmarkHPolyC/XChaCha8_Encrypt-4        3448 ns/op     1285.53 MB/s      0 allocs/op
BenchmarkHPolyC/XChaCha8_Decrypt-4        3437 ns/op     1289.96 MB/s      0 allocs/op
BenchmarkHPolyC/XChaCha12_Encrypt-4       3719 ns/op     1186.35 MB/s      0 allocs/op
BenchmarkHPolyC/XChaCha12_Decrypt-4       3709 ns/op     1184.61 MB/s      0 allocs/op
BenchmarkHPolyC/XChaCha20_Encrypt-4       4258 ns/op     1026.22 MB/s      0 allocs/op
BenchmarkHPolyC/XChaCha20_Decrypt-4       4245 ns/op     1028.97 MB/s      0 allocs/op
```
