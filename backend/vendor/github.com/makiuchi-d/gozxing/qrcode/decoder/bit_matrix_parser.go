package decoder

import (
	"github.com/makiuchi-d/gozxing"
)

type BitMatrixParser struct {
	bitMatrix        *gozxing.BitMatrix
	parsedVersion    *Version
	parsedFormatInfo *FormatInformation
	mirror           bool
}

func NewBitMatrixParser(bitMatrix *gozxing.BitMatrix) (*BitMatrixParser, error) {
	dimension := bitMatrix.GetHeight()
	if dimension < 21 || (dimension&0x03) != 1 {
		return nil, gozxing.NewFormatException("dimension = %v", dimension)
	}
	return &BitMatrixParser{bitMatrix: bitMatrix}, nil
}

func (this *BitMatrixParser) ReadFormatInformation() (*FormatInformation, error) {
	if this.parsedFormatInfo != nil {
		return this.parsedFormatInfo, nil
	}

	// Read top-left format info bits
	formatInfoBits1 := 0
	for i := 0; i < 6; i++ {
		formatInfoBits1 = this.copyBit(i, 8, formatInfoBits1)
	}
	// .. and skip a bit in the timing pattern ...
	formatInfoBits1 = this.copyBit(7, 8, formatInfoBits1)
	formatInfoBits1 = this.copyBit(8, 8, formatInfoBits1)
	formatInfoBits1 = this.copyBit(8, 7, formatInfoBits1)
	// .. and skip a bit in the timing pattern ...
	for j := 5; j >= 0; j-- {
		formatInfoBits1 = this.copyBit(8, j, formatInfoBits1)
	}

	// Read the top-right/bottom-left pattern too
	dimension := this.bitMatrix.GetHeight()
	formatInfoBits2 := 0
	jMin := dimension - 7
	for j := dimension - 1; j >= jMin; j-- {
		formatInfoBits2 = this.copyBit(8, j, formatInfoBits2)
	}
	for i := dimension - 8; i < dimension; i++ {
		formatInfoBits2 = this.copyBit(i, 8, formatInfoBits2)
	}

	this.parsedFormatInfo = FormatInformation_DecodeFormatInformation(uint(formatInfoBits1), uint(formatInfoBits2))
	if this.parsedFormatInfo != nil {
		return this.parsedFormatInfo, nil
	}
	return nil, gozxing.NewFormatException("failed to parse format info")
}

func (this *BitMatrixParser) ReadVersion() (*Version, error) {
	if this.parsedVersion != nil {
		return this.parsedVersion, nil
	}

	dimension := this.bitMatrix.GetHeight()

	provisionalVersion := (dimension - 17) / 4
	if provisionalVersion <= 6 {
		return Version_GetVersionForNumber(provisionalVersion)
	}

	// Read top-right version info: 3 wide by 6 tall
	versionBits := 0
	ijMin := dimension - 11
	for j := 5; j >= 0; j-- {
		for i := dimension - 9; i >= ijMin; i-- {
			versionBits = this.copyBit(i, j, versionBits)
		}
	}
	theParsedVersion, e := Version_decodeVersionInformation(versionBits)
	if e == nil && theParsedVersion != nil && theParsedVersion.GetDimensionForVersion() == dimension {
		this.parsedVersion = theParsedVersion
		return theParsedVersion, nil
	}

	// Hmm, failed. Try bottom left: 6 wide by 3 tall
	versionBits = 0
	for i := 5; i >= 0; i-- {
		for j := dimension - 9; j >= ijMin; j-- {
			versionBits = this.copyBit(i, j, versionBits)
		}
	}
	theParsedVersion, e = Version_decodeVersionInformation(versionBits)
	if e == nil && theParsedVersion != nil && theParsedVersion.GetDimensionForVersion() == dimension {
		this.parsedVersion = theParsedVersion
		return theParsedVersion, nil
	}

	return nil, gozxing.WrapFormatException(e)
}

func (this *BitMatrixParser) copyBit(i, j, versionBits int) int {
	var bit bool
	if this.mirror {
		bit = this.bitMatrix.Get(j, i)
	} else {
		bit = this.bitMatrix.Get(i, j)
	}
	if bit {
		return (versionBits << 1) | 0x1
	}
	return versionBits << 1
}

func (this *BitMatrixParser) ReadCodewords() ([]byte, error) {

	formatInfo, e := this.ReadFormatInformation()
	if e != nil {
		return nil, e
	}
	version, e := this.ReadVersion()
	if e != nil {
		return nil, gozxing.WrapFormatException(e)
	}

	// Get the data mask for the format used in this QR Code. This will exclude
	// some bits from reading as we wind through the bit matrix.
	dataMask := DataMaskValues[formatInfo.GetDataMask()]
	dimension := this.bitMatrix.GetHeight()
	dataMask.UnmaskBitMatrix(this.bitMatrix, dimension)

	functionPattern, e := version.buildFunctionPattern()
	if e != nil {
		return nil, gozxing.WrapFormatException(e)
	}

	readingUp := true
	result := make([]byte, version.GetTotalCodewords())
	resultOffset := 0
	currentByte := 0
	bitsRead := 0
	// Read columns in pairs, from right to left
	for j := dimension - 1; j > 0; j -= 2 {
		if j == 6 {
			// Skip whole column with vertical alignment pattern;
			// saves time and makes the other code proceed more cleanly
			j--
		}
		// Read alternatingly from bottom to top then top to bottom
		for count := 0; count < dimension; count++ {
			i := count
			if readingUp {
				i = dimension - 1 - count
			}
			for col := 0; col < 2; col++ {
				// Ignore bits covered by the function pattern
				if !functionPattern.Get(j-col, i) {
					// Read a bit
					bitsRead++
					currentByte <<= 1
					if this.bitMatrix.Get(j-col, i) {
						currentByte |= 1
					}
					// If we've made a whole byte, save it off
					if bitsRead == 8 {
						result[resultOffset] = byte(currentByte)
						resultOffset++
						bitsRead = 0
						currentByte = 0
					}
				}
			}
		}
		readingUp = !readingUp // readingUp ^= true; // switch directions
	}
	if resultOffset != version.GetTotalCodewords() {
		return nil, gozxing.NewFormatException(
			"resultOffset=%v, totalCodeWords=%v", resultOffset, version.GetTotalCodewords())
	}
	return result, nil
}

func (this *BitMatrixParser) Remask() {
	if this.parsedFormatInfo == nil {
		return // We have no format information, and have no data mask
	}
	dataMask := DataMaskValues[this.parsedFormatInfo.GetDataMask()]
	dimension := this.bitMatrix.GetHeight()
	dataMask.UnmaskBitMatrix(this.bitMatrix, dimension)
}

func (this *BitMatrixParser) SetMirror(mirror bool) {
	this.parsedVersion = nil
	this.parsedFormatInfo = nil
	this.mirror = mirror
}

func (this *BitMatrixParser) Mirror() {
	for x := 0; x < this.bitMatrix.GetWidth(); x++ {
		for y := x + 1; y < this.bitMatrix.GetHeight(); y++ {
			if this.bitMatrix.Get(x, y) != this.bitMatrix.Get(y, x) {
				this.bitMatrix.Flip(y, x)
				this.bitMatrix.Flip(x, y)
			}
		}
	}
}
