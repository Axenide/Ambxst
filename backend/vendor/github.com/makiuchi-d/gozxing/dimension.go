package gozxing

import (
	"fmt"

	errors "golang.org/x/xerrors"
)

type Dimension struct {
	width  int
	height int
}

func NewDimension(width, height int) (*Dimension, error) {
	if width < 0 || height < 0 {
		return nil, errors.New("IllegalArgumentException")
	}
	return &Dimension{width, height}, nil
}

func (this *Dimension) GetWidth() int {
	return this.width
}

func (this *Dimension) GetHeight() int {
	return this.height
}

func (this *Dimension) Equals(other *Dimension) bool {
	return this.width == other.width && this.height == other.height
}

func (this *Dimension) HashCode() int {
	return this.width*32713 + this.height
}

func (this *Dimension) String() string {
	return fmt.Sprintf("%dx%d", this.width, this.height)
}
