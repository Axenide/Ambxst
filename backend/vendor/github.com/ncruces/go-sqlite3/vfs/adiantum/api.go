// Package adiantum wraps an SQLite VFS to offer encryption at rest.
//
// The "adiantum" [vfs.VFS] wraps the default VFS using the
// Adiantum tweakable, length-preserving encryption.
//
// Importing package adiantum registers that VFS:
//
//	import _ "github.com/ncruces/go-sqlite3/vfs/adiantum"
//
// To open an encrypted database you need to provide key material.
//
// The simplest way to do that is to specify the key through an [URI] parameter:
//
//   - key: key material in binary (32 bytes)
//   - hexkey: key material in hex (64 hex digits)
//   - textkey: key material in text (any length)
//
// However, this makes your key easily accessible to other parts of
// your application (e.g. through [vfs.Filename.URIParameters]).
//
// To avoid this, invoke any of the following PRAGMAs
// immediately after opening a connection:
//
//	PRAGMA key='D41d8cD98f00b204e9800998eCf8427e';
//	PRAGMA hexkey='e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
//	PRAGMA textkey='your-secret-key';
//
// For an ATTACH-ed database, you must specify the schema name:
//
//	ATTACH DATABASE 'demo.db' AS demo;
//	PRAGMA demo.textkey='your-secret-key';
//
// [URI]: https://sqlite.org/uri.html
package adiantum

import (
	"lukechampine.com/adiantum/hbsh"

	"github.com/ncruces/go-sqlite3/vfs"
)

func init() {
	vfs.Register("adiantum", Wrap(vfs.Find(""), nil))
}

// Wrap wraps a base VFS to create an encrypting VFS,
// possibly using a custom HBSH cipher construction.
//
// To use the default Adiantum construction, set cipher to nil.
//
// The default construction uses a 32 byte key/hexkey.
// If a textkey is provided, the default KDF is Argon2id
// with 64 MiB of memory, 3 iterations, and 4 threads.
func Wrap(base vfs.VFS, cipher HBSHCreator) vfs.VFS {
	if cipher == nil {
		cipher = adiantumCreator{}
	}
	return &hbshVFS{
		VFS:  base,
		init: cipher,
	}
}

// HBSHCreator creates an [hbsh.HBSH] cipher
// given key material.
type HBSHCreator interface {
	// KDF derives an HBSH key from a secret.
	// If no secret is given, a random key is generated.
	KDF(secret string) (key []byte)

	// HBSH creates an HBSH cipher given a key.
	// If key is not appropriate, nil is returned.
	HBSH(key []byte) *hbsh.HBSH
}
