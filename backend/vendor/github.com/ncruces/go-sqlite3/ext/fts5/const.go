package fts5

// TokenizeFlag are flags that may be passed as the argument to
// [Tokenizer.Tokenize].
//
// https://sqlite.org/fts5.html#custom_tokenizers
type TokenizeFlag uint32

const (
	TOKENIZE_QUERY    TokenizeFlag = 0x0001
	TOKENIZE_PREFIX   TokenizeFlag = 0x0002
	TOKENIZE_DOCUMENT TokenizeFlag = 0x0004
	TOKENIZE_AUX      TokenizeFlag = 0x0008
)

// TokenizeFlag is a flag may be passed by the tokenizer implementation
// back to FTS5 as an argument to the supplied xToken callback.
//
// https://sqlite.org/fts5.html#custom_tokenizers
type TokenFlag uint32

const (
	TOKEN_COLOCATED TokenFlag = 0x0001 /* Same position as prev. token */
)
