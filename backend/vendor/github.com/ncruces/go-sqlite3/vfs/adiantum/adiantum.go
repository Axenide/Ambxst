package adiantum

import (
	"crypto/rand"

	"golang.org/x/crypto/argon2"

	"lukechampine.com/adiantum"
	"lukechampine.com/adiantum/hbsh"
)

// This variable can be replaced with -ldflags:
//
//	go build -ldflags="-X github.com/ncruces/go-sqlite3/vfs/adiantum.pepper=adiantum"
var pepper = "github.com/ncruces/go-sqlite3/vfs/adiantum"

type adiantumCreator struct{}

func (adiantumCreator) HBSH(key []byte) *hbsh.HBSH {
	if len(key) != 32 {
		return nil
	}
	return adiantum.New(key)
}

func (adiantumCreator) KDF(text string) []byte {
	if text == "" {
		key := make([]byte, 32)
		rand.Read(key)
		return key
	}
	return argon2.IDKey([]byte(text), []byte(pepper), 3, 64*1024, 4, 32)
}
