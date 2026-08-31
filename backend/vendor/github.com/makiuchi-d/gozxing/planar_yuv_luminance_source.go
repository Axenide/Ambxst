package gozxing

import (
	errors "golang.org/x/xerrors"
)

const thumbnailScaleFactor = 2

type PlanarYUVLuminanceSource struct {
	LuminanceSourceBase
	yuvData    []byte
	dataWidth  int
	dataHeight int
	left       int
	top        int
}

func NewPlanarYUVLuminanceSource(yuvData []byte,
	dataWidth, dataHeight, left, top, width, height int,
	reverseHorizontal bool) (LuminanceSource, error) {

	if left+width > dataWidth || top+height > dataHeight {
		return nil, errors.New("IllegalArgumentException: Crop rectangle does not fit within image data")
	}

	yuvsrc := &PlanarYUVLuminanceSource{
		LuminanceSourceBase{width, height},
		yuvData,
		dataWidth,
		dataHeight,
		left,
		top,
	}
	if reverseHorizontal {
		yuvsrc.reverseHorizontal(width, height)
	}
	return yuvsrc, nil
}

func (this *PlanarYUVLuminanceSource) Invert() LuminanceSource {
	return LuminanceSourceInvert(this)
}

func (this *PlanarYUVLuminanceSource) String() string {
	return LuminanceSourceString(this)
}

func (this *PlanarYUVLuminanceSource) GetRow(y int, row []byte) ([]byte, error) {
	if y < 0 || y >= this.GetHeight() {
		return nil, errors.Errorf("IllegalArgumentException: Requested row is outside the image: %v", y)
	}
	width := this.GetWidth()
	if row == nil || len(row) < width {
		row = make([]byte, width)
	}
	offset := (y+this.top)*this.dataWidth + this.left
	copy(row, this.yuvData[offset:offset+width])
	return row, nil
}

func (this *PlanarYUVLuminanceSource) GetMatrix() []byte {
	width := this.GetWidth()
	height := this.GetHeight()

	// If the caller asks for the entire underlying image, save the copy and give them the
	// original data. The docs specifically warn that result.length must be ignored.
	if width == this.dataWidth && height == this.dataHeight {
		return this.yuvData
	}

	area := width * height
	matrix := make([]byte, area)
	inputOffset := this.top*this.dataWidth + this.left

	// If the width matches the full width of the underlying data, perform a single copy.
	if width == this.dataWidth {
		copy(matrix, this.yuvData[inputOffset:inputOffset+area])
		return matrix
	}

	// Otherwise copy one cropped row at a time.
	for y := 0; y < height; y++ {
		outputOffset := y * width
		copy(matrix[outputOffset:], this.yuvData[inputOffset:inputOffset+width])
		inputOffset += this.dataWidth
	}
	return matrix
}

func (this *PlanarYUVLuminanceSource) IsCropSupported() bool {
	return true
}

func (this *PlanarYUVLuminanceSource) Crop(left, top, width, height int) (LuminanceSource, error) {
	return NewPlanarYUVLuminanceSource(
		this.yuvData,
		this.dataWidth,
		this.dataHeight,
		this.left+left,
		this.top+top,
		width,
		height,
		false)
}

func (this *PlanarYUVLuminanceSource) RenderThumbnail() []uint {
	width := this.GetThumbnailWidth()
	height := this.GetThumbnailHeight()
	pixels := make([]uint, width*height)
	yuv := this.yuvData
	inputOffset := this.top*this.dataWidth + this.left

	for y := 0; y < height; y++ {
		outputOffset := y * width
		for x := 0; x < width; x++ {
			grey := uint(yuv[inputOffset+x*thumbnailScaleFactor]) & 0xff
			pixels[outputOffset+x] = 0xFF000000 | (grey * 0x00010101)
		}
		inputOffset += this.dataWidth * thumbnailScaleFactor
	}
	return pixels
}

// GetThumbnailWidth return width of image from {@link #renderThumbnail()}
func (this *PlanarYUVLuminanceSource) GetThumbnailWidth() int {
	return this.GetWidth() / thumbnailScaleFactor
}

// GetThumbnailHeight return height of image from {@link #renderThumbnail()}
func (this *PlanarYUVLuminanceSource) GetThumbnailHeight() int {
	return this.GetHeight() / thumbnailScaleFactor
}

func (this *PlanarYUVLuminanceSource) reverseHorizontal(width, height int) {
	yuvData := this.yuvData
	for y, rowStart := 0, this.top*this.dataWidth+this.left; y < height; y, rowStart = y+1, rowStart+this.dataWidth {
		middle := rowStart + width/2
		for x1, x2 := rowStart, rowStart+width-1; x1 < middle; x1, x2 = x1+1, x2-1 {
			yuvData[x1], yuvData[x2] = yuvData[x2], yuvData[x1]
		}
	}
}
