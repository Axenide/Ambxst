package encoder

import (
	"math/bits"

	errors "golang.org/x/xerrors"

	"github.com/makiuchi-d/gozxing"
	"github.com/makiuchi-d/gozxing/qrcode/decoder"
)

var (
	matrixUtil_POSITION_DETECTION_PATTERN = [][]int8{
		{1, 1, 1, 1, 1, 1, 1},
		{1, 0, 0, 0, 0, 0, 1},
		{1, 0, 1, 1, 1, 0, 1},
		{1, 0, 1, 1, 1, 0, 1},
		{1, 0, 1, 1, 1, 0, 1},
		{1, 0, 0, 0, 0, 0, 1},
		{1, 1, 1, 1, 1, 1, 1},
	}

	matrixUtil_POSITION_ADJUSTMENT_PATTERN = [][]int8{
		{1, 1, 1, 1, 1},
		{1, 0, 0, 0, 1},
		{1, 0, 1, 0, 1},
		{1, 0, 0, 0, 1},
		{1, 1, 1, 1, 1},
	}

	// From Appendix E. Table 1, JIS0510X:2004 (p 71). The table was double-checked by komatsu.
	matrixUtil_POSITION_ADJUSTMENT_PATTERN_COORDINATE_TABLE = [][]int{
		{-1, -1, -1, -1, -1, -1, -1},   // Version 1
		{6, 18, -1, -1, -1, -1, -1},    // Version 2
		{6, 22, -1, -1, -1, -1, -1},    // Version 3
		{6, 26, -1, -1, -1, -1, -1},    // Version 4
		{6, 30, -1, -1, -1, -1, -1},    // Version 5
		{6, 34, -1, -1, -1, -1, -1},    // Version 6
		{6, 22, 38, -1, -1, -1, -1},    // Version 7
		{6, 24, 42, -1, -1, -1, -1},    // Version 8
		{6, 26, 46, -1, -1, -1, -1},    // Version 9
		{6, 28, 50, -1, -1, -1, -1},    // Version 10
		{6, 30, 54, -1, -1, -1, -1},    // Version 11
		{6, 32, 58, -1, -1, -1, -1},    // Version 12
		{6, 34, 62, -1, -1, -1, -1},    // Version 13
		{6, 26, 46, 66, -1, -1, -1},    // Version 14
		{6, 26, 48, 70, -1, -1, -1},    // Version 15
		{6, 26, 50, 74, -1, -1, -1},    // Version 16
		{6, 30, 54, 78, -1, -1, -1},    // Version 17
		{6, 30, 56, 82, -1, -1, -1},    // Version 18
		{6, 30, 58, 86, -1, -1, -1},    // Version 19
		{6, 34, 62, 90, -1, -1, -1},    // Version 20
		{6, 28, 50, 72, 94, -1, -1},    // Version 21
		{6, 26, 50, 74, 98, -1, -1},    // Version 22
		{6, 30, 54, 78, 102, -1, -1},   // Version 23
		{6, 28, 54, 80, 106, -1, -1},   // Version 24
		{6, 32, 58, 84, 110, -1, -1},   // Version 25
		{6, 30, 58, 86, 114, -1, -1},   // Version 26
		{6, 34, 62, 90, 118, -1, -1},   // Version 27
		{6, 26, 50, 74, 98, 122, -1},   // Version 28
		{6, 30, 54, 78, 102, 126, -1},  // Version 29
		{6, 26, 52, 78, 104, 130, -1},  // Version 30
		{6, 30, 56, 82, 108, 134, -1},  // Version 31
		{6, 34, 60, 86, 112, 138, -1},  // Version 32
		{6, 30, 58, 86, 114, 142, -1},  // Version 33
		{6, 34, 62, 90, 118, 146, -1},  // Version 34
		{6, 30, 54, 78, 102, 126, 150}, // Version 35
		{6, 24, 50, 76, 102, 128, 154}, // Version 36
		{6, 28, 54, 80, 106, 132, 158}, // Version 37
		{6, 32, 58, 84, 110, 136, 162}, // Version 38
		{6, 26, 54, 82, 110, 138, 166}, // Version 39
		{6, 30, 58, 86, 114, 142, 170}, // Version 40
	}

	// Type info cells at the left top corner.
	matrixUtil_TYPE_INFO_COORDINATES = [][]int{
		{8, 0},
		{8, 1},
		{8, 2},
		{8, 3},
		{8, 4},
		{8, 5},
		{8, 7},
		{8, 8},
		{7, 8},
		{5, 8},
		{4, 8},
		{3, 8},
		{2, 8},
		{1, 8},
		{0, 8},
	}

	// From Appendix D in JISX0510:2004 (p. 67)
	matrixUtil_VERSION_INFO_POLY = 0x1f25 // 1 1111 0010 0101

	// From Appendix C in JISX0510:2004 (p.65).
	matrixUtil_TYPE_INFO_POLY         = 0x537
	matrixUtil_TYPE_INFO_MASK_PATTERN = 0x5412
)

// MatrixUtil_clearMatrix Set all cells to -1.
// -1 means that the cell is empty (not set yet).
func clearMatrix(matrix *ByteMatrix) {
	matrix.Clear(-1)
}

// MatrixUtil_buildMatrix Build 2D matrix of QR Code from
// "dataBits" with "ecLevel", "version" and "getMaskPattern".
// On success, store the result in "matrix" and return true.
func MatrixUtil_buildMatrix(
	dataBits *gozxing.BitArray,
	ecLevel decoder.ErrorCorrectionLevel,
	version *decoder.Version,
	maskPattern int,
	matrix *ByteMatrix) error {

	clearMatrix(matrix)

	e := embedBasicPatterns(version, matrix)
	if e == nil {
		// Type information appear with any version.
		e = embedTypeInfo(ecLevel, maskPattern, matrix)
	}
	if e == nil {
		// Version info appear if version >= 7.
		e = maybeEmbedVersionInfo(version, matrix)
	}
	if e == nil {
		// Data should be embedded at end.
		e = embedDataBits(dataBits, maskPattern, matrix)
	}
	return e
}

// embedBasicPatterns Embed basic patterns. On success, modify the matrix and return true.
// The basic patterns are:
// - Position detection patterns
// - Timing patterns
// - Dark dot at the left bottom corner
// - Position adjustment patterns, if need be
func embedBasicPatterns(version *decoder.Version, matrix *ByteMatrix) gozxing.WriterException {
	// Let's get started with embedding big squares at corners.
	e := embedPositionDetectionPatternsAndSeparators(matrix)
	if e != nil {
		return e
	}
	// Then, embed the dark dot at the left bottom corner.
	e = embedDarkDotAtLeftBottomCorner(matrix)
	if e != nil {
		return e
	}
	// Position adjustment patterns appear if version >= 2.
	maybeEmbedPositionAdjustmentPatterns(version, matrix)

	// Timing patterns should be embedded after position adj. patterns.
	embedTimingPatterns(matrix)

	return nil
}

// embedTypeInfo Embed type information. On success, modify the matrix.
func embedTypeInfo(ecLevel decoder.ErrorCorrectionLevel, maskPattern int, matrix *ByteMatrix) gozxing.WriterException {
	typeInfoBits := gozxing.NewEmptyBitArray()

	e := makeTypeInfoBits(ecLevel, maskPattern, typeInfoBits)
	if e != nil {
		return e
	}

	for i := 0; i < typeInfoBits.GetSize(); i++ {
		// Place bits in LSB to MSB order.  LSB (least significant bit) is the last value in
		// "typeInfoBits".
		bit := typeInfoBits.Get(typeInfoBits.GetSize() - 1 - i)

		// Type info bits at the left top corner. See 8.9 of JISX0510:2004 (p.46).
		coordinates := matrixUtil_TYPE_INFO_COORDINATES[i]
		x1 := coordinates[0]
		y1 := coordinates[1]
		matrix.SetBool(x1, y1, bit)

		var x2, y2 int
		if i < 8 {
			// Right top corner.
			x2 = matrix.GetWidth() - i - 1
			y2 = 8
		} else {
			// Left bottom corner.
			x2 = 8
			y2 = matrix.GetHeight() - 7 + (i - 8)
			matrix.SetBool(x2, y2, bit)
		}
		matrix.SetBool(x2, y2, bit)
	}

	return nil
}

// maybeEmbedVersionInfo Embed version information if need be.
// On success, modify the matrix and return true.
// See 8.10 of JISX0510:2004 (p.47) for how to embed version information.
func maybeEmbedVersionInfo(version *decoder.Version, matrix *ByteMatrix) gozxing.WriterException {
	if version.GetVersionNumber() < 7 { // Version info is necessary if version >= 7.
		return nil // Don't need version info.
	}
	versionInfoBits := gozxing.NewEmptyBitArray()
	e := makeVersionInfoBits(version, versionInfoBits)
	if e != nil {
		return e
	}

	bitIndex := 6*3 - 1 // It will decrease from 17 to 0.
	for i := 0; i < 6; i++ {
		for j := 0; j < 3; j++ {
			// Place bits in LSB (least significant bit) to MSB order.
			bit := versionInfoBits.Get(bitIndex)
			bitIndex--
			// Left bottom corner.
			matrix.SetBool(i, matrix.GetHeight()-11+j, bit)
			// Right bottom corner.
			matrix.SetBool(matrix.GetHeight()-11+j, i, bit)
		}
	}
	return nil
}

// embedDataBits Embed "dataBits" using "getMaskPattern".
// On success, modify the matrix and return true.
// For debugging purposes, it skips masking process if "getMaskPattern" is -1.
// See 8.7 of JISX0510:2004 (p.38) for how to embed data bits.
func embedDataBits(dataBits *gozxing.BitArray, maskPattern int, matrix *ByteMatrix) gozxing.WriterException {
	bitIndex := 0
	direction := -1
	// Start from the right bottom cell.
	x := matrix.GetWidth() - 1
	y := matrix.GetHeight() - 1
	for x > 0 {
		// Skip the vertical timing pattern.
		if x == 6 {
			x -= 1
		}
		for y >= 0 && y < matrix.GetHeight() {
			for i := 0; i < 2; i++ {
				xx := x - i
				// Skip the cell if it's not empty.
				if !isEmpty(matrix.Get(xx, y)) {
					continue
				}
				var bit bool
				if bitIndex < dataBits.GetSize() {
					bit = dataBits.Get(bitIndex)
					bitIndex++
				} else {
					// Padding bit. If there is no bit left, we'll fill the left cells with 0, as described
					// in 8.4.9 of JISX0510:2004 (p. 24).
					bit = false
				}

				// Skip masking if mask_pattern is -1.
				if maskPattern != -1 {
					maskBit, e := MaskUtil_getDataMaskBit(maskPattern, xx, y)
					if e != nil {
						return gozxing.WrapWriterException(e)
					}
					if maskBit {
						bit = !bit
					}
				}
				matrix.SetBool(xx, y, bit)
			}
			y += direction
		}
		direction = -direction // Reverse the direction.
		y += direction
		x -= 2 // Move to the left.
	}
	// All bits should be consumed.
	if bitIndex != dataBits.GetSize() {
		return gozxing.NewWriterException(
			"Not all bits consumed: %v/%v", bitIndex, dataBits.GetSize())
	}
	return nil
}

// findMSBSet Return the position of the most significant bit set (to one) in the "value".
// The most significant bit is position 32. If there is no bit set, return 0. Examples:
// - findMSBSet(0) => 0
// - findMSBSet(1) => 1
// - findMSBSet(255) => 8
func findMSBSet(value int) int {
	return 32 - bits.LeadingZeros32(uint32(value))
}

// calculateBCHCode Calculate BCH (Bose-Chaudhuri-Hocquenghem) code for "value" using polynomial "poly".
// The BCH code is used for encoding type information and version information.
// Example: Calculation of version information of 7.
// f(x) is created from 7.
//   - 7 = 000111 in 6 bits
//   - f(x) = x^2 + x^1 + x^0
// g(x) is given by the standard (p. 67)
//   - g(x) = x^12 + x^11 + x^10 + x^9 + x^8 + x^5 + x^2 + 1
// Multiply f(x) by x^(18 - 6)
//   - f'(x) = f(x) * x^(18 - 6)
//   - f'(x) = x^14 + x^13 + x^12
// Calculate the remainder of f'(x) / g(x)
//         x^2
//         __________________________________________________
//   g(x) )x^14 + x^13 + x^12
//         x^14 + x^13 + x^12 + x^11 + x^10 + x^7 + x^4 + x^2
//         --------------------------------------------------
//                              x^11 + x^10 + x^7 + x^4 + x^2
//
// The remainder is x^11 + x^10 + x^7 + x^4 + x^2
// Encode it in binary: 110010010100
// The return value is 0xc94 (1100 1001 0100)
//
// Since all coefficients in the polynomials are 1 or 0, we can do the calculation by bit
// operations. We don't care if coefficients are positive or negative.
func calculateBCHCode(value, poly int) (int, error) {
	if poly == 0 {
		return 0, errors.New("IllegalArgumentException: 0 polynomial")
	}
	// If poly is "1 1111 0010 0101" (version info poly), msbSetInPoly is 13. We'll subtract 1
	// from 13 to make it 12.
	msbSetInPoly := findMSBSet(poly)

	value <<= uint(msbSetInPoly - 1)
	// Do the division business using exclusive-or operations.
	for findMSBSet(value) >= msbSetInPoly {
		value ^= poly << uint(findMSBSet(value)-msbSetInPoly)
	}
	// Now the "value" is the remainder (i.e. the BCH code)
	return value, nil
}

// maskTypeInfoBits Make bit vector of type information.
// On success, store the result in "bits" and return true.
// Encode error correction level and mask pattern. See 8.9 of JISX0510:2004 (p.45) for details.
func makeTypeInfoBits(ecLevel decoder.ErrorCorrectionLevel, maskPattern int, bits *gozxing.BitArray) gozxing.WriterException {
	if !QRCode_IsValidMaskPattern(maskPattern) {
		return gozxing.NewWriterException("Invalid mask pattern")
	}
	typeInfo := (ecLevel.GetBits() << 3) | maskPattern
	bits.AppendBits(typeInfo, 5)

	bchCode, _ := calculateBCHCode(typeInfo, matrixUtil_TYPE_INFO_POLY)
	bits.AppendBits(bchCode, 10)

	maskBits := gozxing.NewEmptyBitArray()
	maskBits.AppendBits(matrixUtil_TYPE_INFO_MASK_PATTERN, 15)
	bits.Xor(maskBits)

	if bits.GetSize() != 15 { // Just in case.
		return gozxing.NewWriterException(
			"should not happen but we got: %v", bits.GetSize())
	}

	return nil
}

// makeVersionInfoBits Make bit vector of version information.
// On success, store the result in "bits" and return true.
// See 8.10 of JISX0510:2004 (p.45) for details.
func makeVersionInfoBits(version *decoder.Version, bits *gozxing.BitArray) gozxing.WriterException {
	bits.AppendBits(version.GetVersionNumber(), 6)
	bchCode, _ := calculateBCHCode(version.GetVersionNumber(), matrixUtil_VERSION_INFO_POLY)
	bits.AppendBits(bchCode, 12)

	if bits.GetSize() != 18 { // Just in case.
		return gozxing.NewWriterException(
			"should not happen but we got: %v", bits.GetSize())
	}

	return nil
}

// isEmpty Check if "value" is empty.
func isEmpty(value int8) bool {
	return value == -1
}

func embedTimingPatterns(matrix *ByteMatrix) {
	// -8 is for skipping position detection patterns (size 7), and two horizontal/vertical
	// separation patterns (size 1). Thus, 8 = 7 + 1.
	for i := 8; i < matrix.GetWidth()-8; i++ {
		bit := int8((i + 1) % 2)
		// Horizontal line.
		if isEmpty(matrix.Get(i, 6)) {
			matrix.Set(i, 6, bit)
		}
		// Vertical line.
		if isEmpty(matrix.Get(6, i)) {
			matrix.Set(6, i, bit)
		}
	}
}

// embedDarkDotAtLeftBottomCorner Embed the lonely dark dot at left bottom corner. JISX0510:2004 (p.46)
func embedDarkDotAtLeftBottomCorner(matrix *ByteMatrix) gozxing.WriterException {
	if matrix.Get(8, matrix.GetHeight()-8) == 0 {
		return gozxing.NewWriterException("embedDarkDotAtLeftBottomCorner")
	}
	matrix.Set(8, matrix.GetHeight()-8, 1)
	return nil
}

func embedHorizontalSeparationPattern(xStart, yStart int, matrix *ByteMatrix) gozxing.WriterException {
	for x := 0; x < 8; x++ {
		if !isEmpty(matrix.Get(xStart+x, yStart)) {
			return gozxing.NewWriterException(
				"embedHorizontalSeparationPattern(%d, %d)", xStart, yStart)
		}
		matrix.Set(xStart+x, yStart, 0)
	}
	return nil
}

func embedVerticalSeparationPattern(xStart, yStart int, matrix *ByteMatrix) gozxing.WriterException {
	for y := 0; y < 7; y++ {
		if !isEmpty(matrix.Get(xStart, yStart+y)) {
			return gozxing.NewWriterException(
				"embedVerticalSeparationPattern(%d, %d)", xStart, yStart)
		}
		matrix.Set(xStart, yStart+y, 0)
	}
	return nil
}

func embedPositionAdjustmentPattern(xStart, yStart int, matrix *ByteMatrix) {
	for y := 0; y < 5; y++ {
		patternY := matrixUtil_POSITION_ADJUSTMENT_PATTERN[y]
		for x := 0; x < 5; x++ {
			matrix.Set(xStart+x, yStart+y, patternY[x])
		}
	}
}

func embedPositionDetectionPattern(xStart, yStart int, matrix *ByteMatrix) {
	for y := 0; y < 7; y++ {
		patternY := matrixUtil_POSITION_DETECTION_PATTERN[y]
		for x := 0; x < 7; x++ {
			matrix.Set(xStart+x, yStart+y, patternY[x])
		}
	}
}

// embedPositionDetectionPatternsAndSeparators Embed position detection patterns and
// surrounding vertical/horizontal separators.
func embedPositionDetectionPatternsAndSeparators(matrix *ByteMatrix) gozxing.WriterException {
	// Embed three big squares at corners.
	pdpWidth := len(matrixUtil_POSITION_DETECTION_PATTERN[0])
	// Left top corner.
	embedPositionDetectionPattern(0, 0, matrix)
	// Right top corner.
	embedPositionDetectionPattern(matrix.GetWidth()-pdpWidth, 0, matrix)
	// Left bottom corner.
	embedPositionDetectionPattern(0, matrix.GetWidth()-pdpWidth, matrix)

	// Embed horizontal separation patterns around the squares.
	hspWidth := 8
	// Left top corner.
	e := embedHorizontalSeparationPattern(0, hspWidth-1, matrix)
	if e == nil {
		// Right top corner.
		e = embedHorizontalSeparationPattern(matrix.GetWidth()-hspWidth, hspWidth-1, matrix)
	}
	if e == nil {
		// Left bottom corner.
		e = embedHorizontalSeparationPattern(0, matrix.GetWidth()-hspWidth, matrix)
	}

	// Embed vertical separation patterns around the squares.
	vspSize := 7
	if e == nil {
		// Left top corner.
		e = embedVerticalSeparationPattern(vspSize, 0, matrix)
	}
	if e == nil {
		// Right top corner.
		e = embedVerticalSeparationPattern(matrix.GetHeight()-vspSize-1, 0, matrix)
	}
	if e == nil {
		// Left bottom corner.
		e = embedVerticalSeparationPattern(vspSize, matrix.GetHeight()-vspSize, matrix)
	}

	return e
}

// maybeEmbedPositionAdjustmentPatterns Embed position adjustment patterns if need be.
func maybeEmbedPositionAdjustmentPatterns(version *decoder.Version, matrix *ByteMatrix) {
	if version.GetVersionNumber() < 2 { // The patterns appear if version >= 2
		return
	}
	index := version.GetVersionNumber() - 1
	coordinates := matrixUtil_POSITION_ADJUSTMENT_PATTERN_COORDINATE_TABLE[index]
	for _, y := range coordinates {
		if y >= 0 {
			for _, x := range coordinates {
				if x >= 0 && isEmpty(matrix.Get(x, y)) {
					// If the cell is unset, we embed the position adjustment pattern here.
					// -2 is necessary since the x/y coordinates point to the center of the pattern, not the
					// left top corner.
					embedPositionAdjustmentPattern(x-2, y-2, matrix)
				}
			}
		}
	}
}
