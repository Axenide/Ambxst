package gozxing

import (
	errors "golang.org/x/xerrors"
)

type LuminanceSource interface {
	/**
	 * Fetches one row of luminance data from the underlying platform's bitmap. Values range from
	 * 0 (black) to 255 (white). Because Java does not have an unsigned byte type, callers will have
	 * to bitwise and with 0xff for each value. It is preferable for implementations of this method
	 * to only fetch this row rather than the whole image, since no 2D Readers may be installed and
	 * getMatrix() may never be called.
	 *
	 * @param y The row to fetch, which must be in [0,getHeight())
	 * @param row An optional preallocated array. If null or too small, it will be ignored.
	 *            Always use the returned object, and ignore the .length of the array.
	 * @return An array containing the luminance data.
	 */
	GetRow(y int, row []byte) ([]byte, error)

	/**
	 * Fetches luminance data for the underlying bitmap. Values should be fetched using:
	 * {@code int luminance = array[y * width + x] & 0xff}
	 *
	 * @return A row-major 2D array of luminance values. Do not use result.length as it may be
	 *         larger than width * height bytes on some platforms. Do not modify the contents
	 *         of the result.
	 */
	GetMatrix() []byte

	/**
	 * @return The width of the bitmap.
	 */
	GetWidth() int

	/**
	 * @return The height of the bitmap.
	 */
	GetHeight() int

	/**
	 * @return Whether this subclass supports cropping.
	 */
	IsCropSupported() bool

	/**
	 * Returns a new object with cropped image data. Implementations may keep a reference to the
	 * original data rather than a copy. Only callable if isCropSupported() is true.
	 *
	 * @param left The left coordinate, which must be in [0,getWidth())
	 * @param top The top coordinate, which must be in [0,getHeight())
	 * @param width The width of the rectangle to crop.
	 * @param height The height of the rectangle to crop.
	 * @return A cropped version of this object.
	 */
	Crop(left, top, width, height int) (LuminanceSource, error)

	/**
	 * @return Whether this subclass supports counter-clockwise rotation.
	 */
	IsRotateSupported() bool

	/**
	 * @return a wrapper of this {@code LuminanceSource} which inverts the luminances it returns -- black becomes
	 *  white and vice versa, and each value becomes (255-value).
	 */
	Invert() LuminanceSource

	/**
	 * Returns a new object with rotated image data by 90 degrees counterclockwise.
	 * Only callable if {@link #isRotateSupported()} is true.
	 *
	 * @return A rotated version of this object.
	 */
	RotateCounterClockwise() (LuminanceSource, error)

	/**
	 * Returns a new object with rotated image data by 45 degrees counterclockwise.
	 * Only callable if {@link #isRotateSupported()} is true.
	 *
	 * @return A rotated version of this object.
	 */
	RotateCounterClockwise45() (LuminanceSource, error)

	String() string
}

type LuminanceSourceBase struct {
	Width  int
	Height int
}

func (this *LuminanceSourceBase) GetWidth() int {
	return this.Width
}

func (this *LuminanceSourceBase) GetHeight() int {
	return this.Height
}

func (this *LuminanceSourceBase) IsCropSupported() bool {
	return false
}

func (this *LuminanceSourceBase) Crop(left, top, width, height int) (LuminanceSource, error) {
	return nil, errors.New("UnsupportedOperationException: This luminance source does not support cropping")
}

func (this *LuminanceSourceBase) IsRotateSupported() bool {
	return false
}

func (this *LuminanceSourceBase) RotateCounterClockwise() (LuminanceSource, error) {
	return nil, errors.New("UnsupportedOperationException: This luminance source does not support rotation by 90 degrees")
}

func (this *LuminanceSourceBase) RotateCounterClockwise45() (LuminanceSource, error) {
	return nil, errors.New("UnsupportedOperationException: This luminance source does not support rotation by 45 degrees")
}

func LuminanceSourceInvert(this LuminanceSource) LuminanceSource {
	return NewInvertedLuminanceSource(this)
}

func LuminanceSourceString(this LuminanceSource) string {
	width := this.GetWidth()
	height := this.GetHeight()
	row := make([]byte, width)
	result := make([]byte, 0, height*(width+1))

	for y := 0; y < height; y++ {
		row, _ = this.GetRow(y, row)
		for x := 0; x < width; x++ {
			luminance := row[x] & 0xFF
			var c byte
			if luminance < 0x40 {
				c = '#'
			} else if luminance < 0x80 {
				c = '+'
			} else if luminance < 0xC0 {
				c = '.'
			} else {
				c = ' '
			}
			result = append(result, c)
		}
		result = append(result, '\n')
	}
	return string(result)
}
