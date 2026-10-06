package sql3util

import (
	"bytes"
	_ "embed"
	"encoding/binary"
	"strings"

	parser "github.com/ncruces/go-sqlite3-wasm/v5/parser"
	"github.com/ncruces/go-sqlite3/internal/errutil"
)

// ParseTable parses a [CREATE] or [ALTER TABLE] command.
//
// [CREATE]: https://sqlite.org/lang_createtable.html
// [ALTER TABLE]: https://sqlite.org/lang_altertable.html
func ParseTable(sql string) (_ *Table, err error) {
	mod := parser.New()
	mem := mod.Xmemory().Slice()
	sqlp := mod.Xmalloc(int32(len(sql) + 1))
	errp := mod.Xmalloc(4)
	copy((*mem)[sqlp:], sql)
	res := mod.Xsql3parse_table(sqlp, int32(len(sql)), errp)

	c := binary.LittleEndian.Uint32((*mem)[errp:])
	switch c {
	case _MEMORY:
		panic(errutil.OOMErr)
	case _SYNTAX:
		return nil, errutil.ErrorString("sql3parse: invalid syntax")
	case _UNSUPPORTEDSQL:
		return nil, errutil.ErrorString("sql3parse: unsupported SQL")
	}

	var tab Table
	tab.load(*mem, uint32(res), uint32(sqlp), sql)
	return &tab, nil
}

// Table holds metadata about a table.
type Table struct {
	Name           string
	Schema         string
	Comment        string
	IsTemporary    bool
	IsIfNotExists  bool
	IsWithoutRowID bool
	IsStrict       bool
	Columns        []Column
	Constraints    []TableConstraint
	Type           StatementType
	CurrentName    string
	NewName        string
}

func (t *Table) load(mem []byte, ptr, sqlp uint32, sql string) uint32 {
	t.Name = loadIdentifier(mem, ptr+0, sqlp, sql)
	t.Schema = loadIdentifier(mem, ptr+8, sqlp, sql)
	t.Comment = loadString(mem, ptr+16, sqlp, sql)

	t.IsTemporary = loadBool(mem, ptr+24)
	t.IsIfNotExists = loadBool(mem, ptr+25)
	t.IsWithoutRowID = loadBool(mem, ptr+26)
	t.IsStrict = loadBool(mem, ptr+27)

	t.Columns = loadSlice(mem, ptr+28, func(ptr uint32, ret *Column) uint32 {
		p := binary.LittleEndian.Uint32(mem[ptr:])
		ret.load(mem, p, sqlp, sql)
		return 4
	})

	t.Constraints = loadSlice(mem, ptr+36, func(ptr uint32, ret *TableConstraint) uint32 {
		p := binary.LittleEndian.Uint32(mem[ptr:])
		ret.load(mem, p, sqlp, sql)
		return 4
	})

	t.Type = loadEnum[StatementType](mem, ptr+44)
	t.CurrentName = loadIdentifier(mem, ptr+48, sqlp, sql)
	t.NewName = loadIdentifier(mem, ptr+56, sqlp, sql)
	return 64
}

// TableConstraint holds metadata about a table key constraint.
type TableConstraint struct {
	Type ConstraintType
	Name string
	// Type is TABLECONSTRAINT_PRIMARYKEY or TABLECONSTRAINT_UNIQUE
	IndexedColumns  []IdxColumn
	ConflictClause  ConflictClause
	IsAutoIncrement bool
	// Type is TABLECONSTRAINT_CHECK
	CheckExpr string
	// Type is TABLECONSTRAINT_FOREIGNKEY
	ForeignKeyNames  []string
	ForeignKeyClause *ForeignKey
}

func (c *TableConstraint) load(mem []byte, ptr, sqlp uint32, sql string) uint32 {
	c.Type = loadEnum[ConstraintType](mem, ptr+0)
	c.Name = loadIdentifier(mem, ptr+4, sqlp, sql)
	switch c.Type {
	case TABLECONSTRAINT_PRIMARYKEY, TABLECONSTRAINT_UNIQUE:
		c.IndexedColumns = loadSlice(mem, ptr+12, func(ptr uint32, ret *IdxColumn) uint32 {
			return ret.load(mem, ptr, sqlp, sql)
		})
		c.ConflictClause = loadEnum[ConflictClause](mem, ptr+20)
		c.IsAutoIncrement = loadBool(mem, ptr+24)
	case TABLECONSTRAINT_CHECK:
		c.CheckExpr = loadString(mem, ptr+28, sqlp, sql)
	case TABLECONSTRAINT_FOREIGNKEY:
		c.ForeignKeyNames = loadSlice(mem, ptr+36, func(ptr uint32, ret *string) uint32 {
			*ret = loadIdentifier(mem, ptr, sqlp, sql)
			return 8
		})
		if ptr := binary.LittleEndian.Uint32(mem[ptr+44:]); ptr != 0 {
			c.ForeignKeyClause = &ForeignKey{}
			c.ForeignKeyClause.load(mem, ptr, sqlp, sql)
		}
	}
	return 28
}

// Column holds metadata about a column.
type Column struct {
	Name                     string
	Type                     string
	Length                   string
	Comment                  string
	IsPrimaryKey             bool
	IsAutoIncrement          bool
	IsNotNull                bool
	IsUnique                 bool
	PKConstraintName         string
	PKOrder                  OrderClause
	PKConflictClause         ConflictClause
	NotNullConstraintName    string
	NotNullConflictClause    ConflictClause
	UniqueConstraintName     string
	UniqueConflictClause     ConflictClause
	CheckConstraints         []CheckConstraint
	DefaultConstraintName    string
	DefaultExpr              string
	CollateConstraintName    string
	CollateName              string
	ForeignKeyConstraintName string
	ForeignKeyClause         *ForeignKey
	GeneratedConstraintName  string
	GeneratedExpr            string
	GeneratedType            GenType
}

func (c *Column) load(mem []byte, ptr, sqlp uint32, sql string) uint32 {
	c.Name = loadIdentifier(mem, ptr+0, sqlp, sql)
	c.Type = loadString(mem, ptr+8, sqlp, sql)
	c.Length = loadString(mem, ptr+16, sqlp, sql)
	c.Comment = loadString(mem, ptr+24, sqlp, sql)

	c.IsPrimaryKey = loadBool(mem, ptr+32)
	c.IsAutoIncrement = loadBool(mem, ptr+33)
	c.IsNotNull = loadBool(mem, ptr+34)
	c.IsUnique = loadBool(mem, ptr+35)

	c.PKConstraintName = loadIdentifier(mem, ptr+36, sqlp, sql)
	c.PKOrder = loadEnum[OrderClause](mem, ptr+44)
	c.PKConflictClause = loadEnum[ConflictClause](mem, ptr+48)

	c.NotNullConstraintName = loadIdentifier(mem, ptr+52, sqlp, sql)
	c.NotNullConflictClause = loadEnum[ConflictClause](mem, ptr+60)

	c.UniqueConstraintName = loadIdentifier(mem, ptr+64, sqlp, sql)
	c.UniqueConflictClause = loadEnum[ConflictClause](mem, ptr+72)

	c.CheckConstraints = loadSlice(mem, ptr+76, func(ptr uint32, ret *CheckConstraint) uint32 {
		return ret.load(mem, ptr, sqlp, sql)
	})

	c.DefaultConstraintName = loadIdentifier(mem, ptr+84, sqlp, sql)
	c.DefaultExpr = loadString(mem, ptr+92, sqlp, sql)

	c.CollateConstraintName = loadIdentifier(mem, ptr+100, sqlp, sql)
	c.CollateName = loadIdentifier(mem, ptr+108, sqlp, sql)

	c.ForeignKeyConstraintName = loadIdentifier(mem, ptr+116, sqlp, sql)
	if p := binary.LittleEndian.Uint32(mem[ptr+124:]); p != 0 {
		c.ForeignKeyClause = &ForeignKey{}
		c.ForeignKeyClause.load(mem, p, sqlp, sql)
	}

	c.GeneratedConstraintName = loadIdentifier(mem, ptr+128, sqlp, sql)
	c.GeneratedExpr = loadString(mem, ptr+136, sqlp, sql)
	c.GeneratedType = loadEnum[GenType](mem, ptr+144)
	return 148
}

// CheckConstraint holds metadata about a check constraint.
type CheckConstraint struct {
	Name string
	Expr string
}

func (c *CheckConstraint) load(mem []byte, ptr, sqlp uint32, sql string) uint32 {
	c.Name = loadIdentifier(mem, ptr+0, sqlp, sql)
	c.Expr = loadString(mem, ptr+8, sqlp, sql)
	return 16
}

// ForeignKey holds metadata about a foreign key constraint.
type ForeignKey struct {
	Table       string
	ColumnNames []string
	OnDelete    FKAction
	OnUpdate    FKAction
	Match       string
	Deferrable  FKDefType
}

func (f *ForeignKey) load(mem []byte, ptr, sqlp uint32, sql string) uint32 {
	f.Table = loadIdentifier(mem, ptr+0, sqlp, sql)

	f.ColumnNames = loadSlice(mem, ptr+8, func(ptr uint32, ret *string) uint32 {
		*ret = loadIdentifier(mem, ptr, sqlp, sql)
		return 8
	})

	f.OnDelete = loadEnum[FKAction](mem, ptr+16)
	f.OnUpdate = loadEnum[FKAction](mem, ptr+20)
	f.Match = loadIdentifier(mem, ptr+24, sqlp, sql)
	f.Deferrable = loadEnum[FKDefType](mem, ptr+32)
	return 36
}

// IdxColumn holds metadata about an indexed column.
type IdxColumn struct {
	Name        string
	CollateName string
	Order       OrderClause
}

func (c *IdxColumn) load(mem []byte, ptr, sqlp uint32, sql string) uint32 {
	c.Name = loadIdentifier(mem, ptr+0, sqlp, sql)
	c.CollateName = loadIdentifier(mem, ptr+8, sqlp, sql)
	c.Order = loadEnum[OrderClause](mem, ptr+16)
	return 20
}

func loadString(mem []byte, ptr, sqlp uint32, sql string) string {
	off := binary.LittleEndian.Uint32(mem[ptr+0:])
	if off == 0 {
		return ""
	}
	cnt := binary.LittleEndian.Uint32(mem[ptr+4:])

	if uint(off+cnt-sqlp) >= uint(len(sql)) {
		return string(mem[off : off+cnt])
	}

	return sql[off-sqlp : off+cnt-sqlp]
}

func loadIdentifier(mem []byte, ptr, sqlp uint32, sql string) string {
	off := binary.LittleEndian.Uint32(mem[ptr+0:])
	if off == 0 {
		return ""
	}
	cnt := binary.LittleEndian.Uint32(mem[ptr+4:])

	if uint(off+cnt-sqlp) >= uint(len(sql)) {
		return string(mem[off : off+cnt])
	}

	var old, new string
	str := sql[off-sqlp : off+cnt-sqlp]
	switch sql[off-sqlp-1] {
	default:
		return str
	case '`':
		old, new = "``", "`"
	case '"':
		old, new = `""`, `"`
	case '\'':
		old, new = `''`, `'`
	}
	return strings.ReplaceAll(str, old, new)
}

func loadSlice[T any](mem []byte, ptr uint32, fn func(uint32, *T) uint32) []T {
	ref := binary.LittleEndian.Uint32(mem[ptr+4:])
	if ref == 0 {
		return nil
	}
	cnt := binary.LittleEndian.Uint32(mem[ptr+0:])
	ret := make([]T, cnt)
	for i := range ret {
		ref += fn(ref, &ret[i])
	}
	return ret
}

func loadEnum[T ~uint32](mem []byte, ptr uint32) T {
	val := binary.LittleEndian.Uint32(mem[ptr:])
	return T(val)
}

func loadBool(mem []byte, ptr uint32) bool {
	val := mem[ptr]
	return val != 0
}

type libc struct{ memory *[]byte }

func (l *libc) Init(m *parser.Module) { l.memory = m.Xmemory().Slice() }

func (l *libc) Xstrlen(v0 int32) int32 {
	return int32(bytes.IndexByte((*l.memory)[v0:], 0))
}
