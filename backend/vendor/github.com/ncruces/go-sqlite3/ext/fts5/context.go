package fts5

import (
	"iter"

	"github.com/ncruces/go-sqlite3/util/sql3util"
)

// Context is the context in which an [ExtensionFunction] executes.
// It is in no way related to a Go [context.Context].
//
// https://sqlite.org/fts5.html#custom_auxiliary_functions_api_overview
type Context struct {
	env  *env
	pFts int32
}

// ColumnCount returns the number of columns in the table.
//
// https://sqlite.org/fts5.html#xColumnCount
func (c Context) ColumnCount() int {
	return int(c.env.Xfts5_xColumnCount(c.pFts))
}

// RowCount returns the number of rows in the table.
//
// https://sqlite.org/fts5.html#xRowCount
func (c Context) RowCount() (int64, error) {
	defer c.env.StackMark()()
	ptr := c.env.StackAlloc(8)
	rc := c.env.Xfts5_xRowCount(c.pFts, int32(ptr))
	if rc != 0 {
		return 0, sql3util.CodeToError(rc)
	}
	return int64(c.env.Read64(ptr)), nil
}

// ColumnTotalSize returns the total number of tokens in a column.
//
// https://sqlite.org/fts5.html#xColumnTotalSize
func (c Context) ColumnTotalSize(col int) (int64, error) {
	defer c.env.StackMark()()
	ptr := c.env.StackAlloc(8)
	rc := c.env.Xfts5_xColumnTotalSize(c.pFts, int32(col), int32(ptr))
	if rc != 0 {
		return 0, sql3util.CodeToError(rc)
	}
	return int64(c.env.Read64(ptr)), nil
}

// PhraseCount returns the number of phrases in the current query.
//
// https://sqlite.org/fts5.html#xPhraseCount
func (c Context) PhraseCount() int {
	return int(c.env.Xfts5_xPhraseCount(c.pFts))
}

// PhraseSize returns the number of tokens in the given phrase.
//
// https://sqlite.org/fts5.html#xPhraseSize
func (c Context) PhraseSize(phrase int) int {
	return int(c.env.Xfts5_xPhraseSize(c.pFts, int32(phrase)))
}

// InstCount returns the number of occurrences of
// all phrases within the query within the current row.
//
// https://sqlite.org/fts5.html#xInstCount
func (c Context) InstCount() (int, error) {
	defer c.env.StackMark()()
	ptr := c.env.StackAlloc(intlen)
	rc := c.env.Xfts5_xInstCount(c.pFts, int32(ptr))
	if rc != 0 {
		return 0, sql3util.CodeToError(rc)
	}
	return int(int32(c.env.Read32(ptr))), nil
}

// Inst returns the details of phrase match idx within the current row.
//
// https://sqlite.org/fts5.html#xInst
func (c Context) Inst(idx int) (phrase, col, off int, err error) {
	defer c.env.StackMark()()
	pPhrase := c.env.StackAlloc(intlen)
	pCol := c.env.StackAlloc(intlen)
	pOff := c.env.StackAlloc(intlen)

	rc := c.env.Xfts5_xInst(c.pFts, int32(idx), int32(pPhrase), int32(pCol), int32(pOff))
	if rc != 0 {
		return 0, 0, 0, sql3util.CodeToError(rc)
	}

	phrase = int(int32(c.env.Read32(pPhrase)))
	col = int(int32(c.env.Read32(pCol)))
	off = int(int32(c.env.Read32(pOff)))
	return
}

// RowID returns the rowid of the current row.
//
// https://sqlite.org/fts5.html#xRowid
func (c Context) RowID() int64 {
	return int64(c.env.Xfts5_xRowid(c.pFts))
}

// ColumnText returns the text of a column.
//
// https://sqlite.org/fts5.html#xColumnText
func (c Context) ColumnText(col int) (string, error) {
	defer c.env.StackMark()()
	pz := c.env.StackAlloc(ptrlen)
	pn := c.env.StackAlloc(intlen)

	rc := c.env.Xfts5_xColumnText(c.pFts, int32(col), int32(pz), int32(pn))
	if rc != 0 {
		return "", sql3util.CodeToError(rc)
	}

	if n := int32(c.env.Read32(pn)); n > 0 {
		return string(c.env.Bytes(ptr_t(c.env.Read32(pz)), int64(n))), nil
	}
	return "", nil
}

// ColumnSize returns the number of tokens in a column.
//
// https://sqlite.org/fts5.html#xColumnSize
func (c Context) ColumnSize(col int) (int, error) {
	defer c.env.StackMark()()
	ptr := c.env.StackAlloc(intlen)
	rc := c.env.Xfts5_xColumnSize(c.pFts, int32(col), int32(ptr))
	if rc != 0 {
		return 0, sql3util.CodeToError(rc)
	}
	return int(int32(c.env.Read32(ptr))), nil
}

// SetAuxdata sets the extension function's auxiliary data.
//
// https://sqlite.org/fts5.html#xSetAuxdata
func (c Context) SetAuxdata(aux any) error {
	var handle ptr_t
	if aux != nil {
		handle = c.env.AddHandle(aux)
	}
	rc := c.env.Xfts5_xSetAuxdata(c.pFts, int32(handle))
	return sql3util.CodeToError(rc)
}

// GetAuxdata gets the extension function's auxiliary data.
//
// https://sqlite.org/fts5.html#xGetAuxdata
func (c Context) GetAuxdata(clear bool) any {
	var b int32
	if clear {
		b = 1
	}
	if handle := c.env.Xfts5_xGetAuxdata(c.pFts, b); handle != 0 {
		return c.env.GetHandle(ptr_t(handle))
	}
	return nil
}

// PhraseIter returns a single-use iterator over
// all instances of a query phrase within the current row.
//
// https://sqlite.org/fts5.html#xPhraseFirst
func (c Context) PhraseIter(phrase int) (iter.Seq2[int, int], error) {
	pIt := c.env.New(16)
	rc := c.env.Xfts5_xPhraseFirst(c.pFts, int32(phrase), int32(pIt))
	if rc != 0 {
		c.env.Free(pIt)
		return nil, sql3util.CodeToError(rc)
	}

	return func(yield func(int, int) bool) {
		defer func() {
			c.env.Free(pIt)
			pIt = 0
		}()
		for pIt != 0 {
			column := int32(c.env.Read32(pIt + 8))
			offset := int32(c.env.Read32(pIt + 12))
			if column < 0 || !yield(int(column), int(offset)) {
				break
			}
			c.env.Xfts5_xPhraseNext(c.pFts, int32(pIt))
		}
	}, nil
}

// PhraseIterColumn returns a single-use iterator over
// the set of columns in the current row that contain
// one or more instances of a specified phrase.
//
// https://sqlite.org/fts5.html#xPhraseFirstColumn
func (c Context) PhraseIterColumn(phrase int) (iter.Seq[int], error) {
	pIt := c.env.New(16)
	rc := c.env.Xfts5_xPhraseFirstColumn(c.pFts, int32(phrase), int32(pIt))
	if rc != 0 {
		c.env.Free(pIt)
		return nil, sql3util.CodeToError(rc)
	}

	return func(yield func(int) bool) {
		defer func() {
			c.env.Free(pIt)
			pIt = 0
		}()
		for pIt != 0 {
			column := int32(c.env.Read32(pIt + 8))
			if column < 0 || !yield(int(column)) {
				break
			}
			c.env.Xfts5_xPhraseNextColumn(c.pFts, int32(pIt))
		}
	}, nil
}

// QueryToken returns a token from the current query.
//
// https://sqlite.org/fts5.html#xQueryToken
func (c Context) QueryToken(phrase, token int) (string, error) {
	defer c.env.StackMark()()
	ppToken := c.env.StackAlloc(ptrlen)
	pnToken := c.env.StackAlloc(intlen)

	rc := c.env.Xfts5_xQueryToken(c.pFts, int32(phrase), int32(token), int32(ppToken), int32(pnToken))
	if rc != 0 {
		return "", sql3util.CodeToError(rc)
	}

	if n := int32(c.env.Read32(pnToken)); n > 0 {
		return string(c.env.Bytes(ptr_t(c.env.Read32(ppToken)), int64(n))), nil
	}
	return "", nil
}

// InstToken returns a token from a phrase hit of the current query.
//
// https://sqlite.org/fts5.html#xInstToken
func (c Context) InstToken(idx, token int) (string, error) {
	defer c.env.StackMark()()
	ppToken := c.env.StackAlloc(ptrlen)
	pnToken := c.env.StackAlloc(intlen)

	rc := c.env.Xfts5_xInstToken(c.pFts, int32(idx), int32(token), int32(ppToken), int32(pnToken))
	if rc != 0 {
		return "", sql3util.CodeToError(rc)
	}

	if n := int32(c.env.Read32(pnToken)); n > 0 {
		return string(c.env.Bytes(ptr_t(c.env.Read32(ppToken)), int64(n))), nil
	}
	return "", nil
}

// ColumnLocale returns the locale of a column.
//
// https://sqlite.org/fts5.html#xColumnLocale
func (c Context) ColumnLocale(col int) (string, error) {
	defer c.env.StackMark()()
	pz := c.env.StackAlloc(ptrlen)
	pn := c.env.StackAlloc(intlen)

	rc := c.env.Xfts5_xColumnLocale(c.pFts, int32(col), int32(pz), int32(pn))
	if rc != 0 {
		return "", sql3util.CodeToError(rc)
	}

	if n := int32(c.env.Read32(pn)); n > 0 {
		return string(c.env.Bytes(ptr_t(c.env.Read32(pz)), int64(n))), nil
	}
	return "", nil
}

// Tokenize tokenizes text using the tokenizer of the table.
//
// https://sqlite.org/fts5.html#xTokenize_v2
func (c Context) Tokenize(text, locale string, token TokenCallback) error {
	var handle, pText, pLoc ptr_t
	defer func() {
		c.env.Free(pText)
		c.env.Free(pLoc)
		c.env.DelHandle(handle)
	}()

	pText = c.env.NewString(text)
	pLoc = c.env.NewString(locale)
	handle = c.env.AddHandle(token)

	rc := c.env.Xfts5_xTokenize_v2(c.pFts,
		int32(pText), int32(len(text)),
		int32(pLoc), int32(len(locale)),
		int32(handle))
	return sql3util.CodeToError(rc)
}
