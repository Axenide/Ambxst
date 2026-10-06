// Package fts5 provides the fts5 extension.
//
// https://sqlite.org/fts5.html
package fts5

import (
	"github.com/ncruces/go-sqlite3"
	"github.com/ncruces/go-sqlite3-wasm/v5/fts5"
	"github.com/ncruces/go-sqlite3/internal/sqlite3_wrap"
	"github.com/ncruces/go-sqlite3/util/sql3util"
)

// Register registers the fts5 extension.
func Register(db *sqlite3.Conn) error {
	return RegisterCustom(db, nil)
}

// Register registers the fts5 extension,
// allowing you to register custom tokenizers,
// using [API.CreateTokenizer].
func RegisterCustom(db *sqlite3.Conn, init func(*API) error) error {
	var api API
	err := sqlite3.ExtensionInit(db, func(e *sqlite3.ExtEnv) *fts5.Module {
		api.env = env{ExtEnv: e}
		api.env.Module = fts5.New(&api.env)
		return api.env.Module
	}, fts5.DylinkInfo)
	if err == nil && init != nil {
		return init(&api)
	}
	return err
}

// API exposes methods to extend FTS5.
//
// https://sqlite.org/fts5.html#extending_fts5
type API struct{ env env }

// CreateTokenizer registers a [Tokenizer].
// If fn returns an [io.Closer], it will be called to free resources.
//
// https://sqlite.org/fts5.html#custom_tokenizers
func (a *API) CreateTokenizer(name string, fn TokenizerConstructor) error {
	ptr := a.env.NewString(name)
	defer a.env.Free(ptr)

	var handle ptr_t
	if fn != nil {
		handle = a.env.AddHandle(fn)
	}

	rc := a.env.Xfts5_xCreateTokenizer_v2(int32(ptr), int32(handle))
	return sql3util.CodeToError(rc)
}

// CreateFunction registers a [ExtensionFunction].
//
// https://sqlite.org/fts5.html#custom_auxiliary_functions
func (a *API) CreateFunction(name string, fn ExtensionFunction) error {
	ptr := a.env.NewString(name)
	defer a.env.Free(ptr)

	var handle ptr_t
	if fn != nil {
		handle = a.env.AddHandle(fn)
	}

	rc := a.env.Xfts5_xCreateFunction(int32(ptr), int32(handle))
	return sql3util.CodeToError(rc)
}

// TokenizerConstructor allocates and initializes a [Tokenizer] instance.
//
// https://sqlite.org/fts5.html#custom_tokenizers
type TokenizerConstructor func(arg []string) (Tokenizer, error)

// Tokenizer is the interface implemented by tokenizer instances.
//
// https://sqlite.org/fts5.html#custom_tokenizers
type Tokenizer interface {
	// This function is expected to tokenize text.
	// For each token in the input string, the supplied callback must be invoked.
	Tokenize(flags TokenizeFlag, text, locale string, xToken TokenCallback) error
}

// TokenCallback is a callback invoked to emit a token.
// For tokens that are substrings of the input text,
// token can be an empty string, enabling zero copy tokenization.
//
// https://sqlite.org/fts5.html#custom_tokenizers
type TokenCallback func(tflags TokenFlag, token string, start, end int) error

// ExtensionFunction is a custom auxiliary function.
//
// https://sqlite.org/fts5.html#custom_auxiliary_functions
type ExtensionFunction func(fts Context, ctx sqlite3.Context, arg ...sqlite3.Value)

type env struct {
	*sqlite3.ExtEnv
	*fts5.Module
}

func (e *env) Xgo_fts5_create(pApp, azArg, nArg, pOut int32) int32 {
	arg := make([]string, nArg)
	for i := range nArg {
		ptr := ptr_t(e.Memory.Read32(ptr_t(azArg + i*ptrlen)))
		arg[i] = e.ReadString(ptr, 1e6)
	}

	fn := e.GetHandle(ptr_t(pApp)).(TokenizerConstructor)
	t, err := fn(arg)

	var handle ptr_t
	if t != nil {
		handle = e.AddHandle(t)
	}
	e.Write32(ptr_t(pOut), uint32(handle))
	return sql3util.ErrorToCode(err)
}

func (e *env) Xgo_fts5_tokenize(pTok, pCtx, flags, pText, nText, pLocale, nLocale, xToken int32) int32 {
	var locale string
	tok := e.GetHandle(ptr_t(pTok)).(Tokenizer)
	text := string(e.Bytes(ptr_t(pText), int64(nText)))
	if pLocale != 0 {
		locale = string(e.Bytes(ptr_t(pLocale), int64(nLocale)))
	}

	var ptr ptr_t
	var buf []byte
	defer func() { e.Free(ptr) }()

	err := tok.Tokenize(TokenizeFlag(flags), text, locale, func(tflags TokenFlag, token string, start, end int) error {
		if len(token) > len(buf) {
			want := int64(len(buf))
			want += want >> 1
			want = max(want, int64(len(token)))
			ptr = e.Realloc(ptr, want)
			buf = e.Bytes(ptr, want)
		}

		tok := int32(ptr)
		siz := int32(len(token))
		if token != "" {
			copy(buf, token)
		} else {
			tok = pText + int32(start)
			siz = int32(end - start)
		}

		rc := e.Xfts5_xToken(xToken, pCtx, int32(tflags), tok, siz, int32(start), int32(end))
		return sql3util.CodeToError(rc)
	})
	return sql3util.ErrorToCode(err)
}

func (e *env) Xgo_fts5_function(pApp, pFts, pCtx, nVal, apVal int32) {
	e.CallWithContextValues(pCtx, nVal, apVal, func(ctx sqlite3.Context, arg ...sqlite3.Value) {
		fn := e.GetHandle(ptr_t(pApp)).(ExtensionFunction)
		fn(Context{e, pFts}, ctx, arg...)
	})
}

func (e *env) Xgo_fts5_token(pApp, tflags, pToken, nToken, iStart, iEnd int32) int32 {
	fn := e.GetHandle(ptr_t(pApp)).(TokenCallback)
	token := string(e.Bytes(ptr_t(pToken), int64(nToken)))
	err := fn(TokenFlag(tflags), token, int(iStart), int(iEnd))
	return sql3util.ErrorToCode(err)
}

const (
	ptrlen = sqlite3_wrap.PtrLen
	intlen = sqlite3_wrap.IntLen
)

type ptr_t = sqlite3_wrap.Ptr_t
