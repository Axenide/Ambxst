// Portions Copyright (c) 2025 Avenge Media LLC
// Licensed under the MIT License. Derived from DankMaterialShell.

package screenshot

type Region struct {
	X      int32 `json:"x"`
	Y      int32 `json:"y"`
	Width  int32 `json:"width"`
	Height int32 `json:"height"`
}

func (r Region) IsEmpty() bool {
	return r.Width <= 0 || r.Height <= 0
}

type Output struct {
	Name            string
	X, Y            int32
	Width           int32
	Height          int32
	Scale           int32
	FractionalScale float64
	Transform       int32
}

type CursorMode int

const (
	CursorOff CursorMode = iota
	CursorOn
)

func tenBitSwapRB(format uint32) bool {
	return format == uint32(FormatARGB2101010) || format == uint32(FormatXRGB2101010)
}

type CaptureResult struct {
	Buffer    *ShmBuffer
	Region    Region
	YInverted bool
	Format    uint32
	Transform int32
}
