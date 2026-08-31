package encoder

// SymbolShapeHint Enumeration for DataMatrix symbol shape hint.
// It can be used to force square or rectangular symbols.
type SymbolShapeHint int

const (
	SymbolShapeHint_FORCE_NONE = SymbolShapeHint(iota)
	SymbolShapeHint_FORCE_SQUARE
	SymbolShapeHint_FORCE_RECTANGLE
)
