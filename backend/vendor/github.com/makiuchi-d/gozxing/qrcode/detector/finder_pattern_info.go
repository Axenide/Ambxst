package detector

type FinderPatternInfo struct {
	bottomLeft *FinderPattern
	topLeft    *FinderPattern
	topRight   *FinderPattern
}

func NewFinderPatternInfo(bottomLeft, topLeft, topRight *FinderPattern) *FinderPatternInfo {
	return &FinderPatternInfo{
		bottomLeft: bottomLeft,
		topLeft:    topLeft,
		topRight:   topRight,
	}
}

func (f *FinderPatternInfo) GetBottomLeft() *FinderPattern {
	return f.bottomLeft
}

func (f *FinderPatternInfo) GetTopLeft() *FinderPattern {
	return f.topLeft
}
func (f *FinderPatternInfo) GetTopRight() *FinderPattern {
	return f.topRight
}
