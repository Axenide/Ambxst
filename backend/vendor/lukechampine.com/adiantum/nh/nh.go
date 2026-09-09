package nh // import "lukechampine.com/adiantum/nh"

// Sum computes the NH hash of m with the specified key and places the result in
// out. The key must be at least 48 bytes larger than the message.
func Sum(out *[32]byte, m []byte, key []byte) {
	if len(m)%16 != 0 {
		panic("nh: Message must be a multiple of 16 bytes")
	} else if len(key) < len(m)+48 {
		panic("nh: Key must be at least 48 bytes longer than message")
	}
	sum(out, m, key)
}
