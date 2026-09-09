# Go `adiantum` SQLite VFS

This package wraps an SQLite VFS to offer encryption at rest.

The `"adiantum"` VFS wraps the default SQLite VFS using the
[Adiantum](https://github.com/lukechampine/adiantum)
tweakable and length-preserving encryption.\
In general, any HBSH construction can be used to wrap any VFS.

The default Adiantum construction uses XChaCha12 for its stream cipher,
AES for its block cipher, and NH and Poly1305 for hashing.\
Additionally, we use [Argon2id](https://pkg.go.dev/golang.org/x/crypto/argon2#hdr-Argon2id)
to derive 256-bit keys from plain text where needed.
File contents are encrypted in 4 KiB blocks, matching the
[default](https://sqlite.org/pgszchng2016.html) SQLite page size.

The VFS encrypts all files _except_
[super journals](https://sqlite.org/tempfiles.html#super_journal_files):
these _never_ contain database data, only filenames,
and padding them to the block size is problematic.
Temporary files _are_ encrypted with **random** keys,
as they _may_ contain database data.
To avoid the overhead of encrypting temporary files,
keep them in memory:

    PRAGMA temp_store = memory;

> [!IMPORTANT]
> Adiantum is a cipher composition for disk encryption.
> The standard threat model for disk encryption considers an adversary
> that can read multiple snapshots of a disk.
> The only security property that disk encryption provides
> is that all information such an adversary can obtain
> is whether the data in a sector has or has not changed over time.

The encryption offered by this package is fully deterministic.

This means that an adversary who can get ahold of multiple snapshots
(e.g. backups) of a database file can learn precisely:
which blocks changed, which ones didn't, which got reverted.

This is weaker than other forms of SQLite encryption
that include *some* nondeterminism.
With limited nondeterminism, an adversary can't distinguish between
pages that actually changed, and pages that got reverted;
a `VACUUM` can fully rebuild the database file,
preventing this differential analysis.

> [!CAUTION]
> This package does not claim protect databases against tampering or forgery.

The major practical consequence of the above point is that,
if you're keeping `"adiantum"` encrypted backups of your database,
and want to protect against forgery, you should sign your backups,
and verify signatures before restoring them.

This is weaker than other forms of SQLite encryption
that include page-level [MACs](https://en.wikipedia.org/wiki/Message_authentication_code).
Page-level MACs can protect against forging individual pages,
but can't prevent them from being reverted to former versions of themselves.

> [!TIP]
> The [`"xts"`](../xts/README.md) VFS also offers encryption at rest.
> AES-XTS uses _only_ NIST and FIPS 140 approved cryptographic primitives.