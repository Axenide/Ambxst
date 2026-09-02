package decoder

import (
	"strconv"

	"github.com/makiuchi-d/gozxing"
)

// Version The Version object encapsulates attributes about a particular
// size Data Matrix Code.
type Version struct {
	versionNumber         int
	symbolSizeRows        int
	symbolSizeColumns     int
	dataRegionSizeRows    int
	dataRegionSizeColumns int
	ecBlocks              *ECBlocks
	totalCodewords        int
}

func NewVersion(
	versionNumber, symbolSizeRows, symbolSizeColumns,
	dataRegionSizeRows, dataRegionSizeColumns int, ecBlocks *ECBlocks) *Version {

	this := &Version{}
	this.versionNumber = versionNumber
	this.symbolSizeRows = symbolSizeRows
	this.symbolSizeColumns = symbolSizeColumns
	this.dataRegionSizeRows = dataRegionSizeRows
	this.dataRegionSizeColumns = dataRegionSizeColumns
	this.ecBlocks = ecBlocks

	// Calculate the total number of codewords
	total := 0
	ecCodewords := ecBlocks.getECCodewords()
	ecbArray := ecBlocks.getECBlocks()
	for _, ecBlock := range ecbArray {
		total += ecBlock.getCount() * (ecBlock.getDataCodewords() + ecCodewords)
	}
	this.totalCodewords = total

	return this
}

func (v *Version) getVersionNumber() int {
	return v.versionNumber
}

func (v *Version) getSymbolSizeRows() int {
	return v.symbolSizeRows
}

func (v *Version) getSymbolSizeColumns() int {
	return v.symbolSizeColumns
}

func (v *Version) getDataRegionSizeRows() int {
	return v.dataRegionSizeRows
}

func (v *Version) getDataRegionSizeColumns() int {
	return v.dataRegionSizeColumns
}

func (v *Version) getTotalCodewords() int {
	return v.totalCodewords
}

func (v *Version) getECBlocks() *ECBlocks {
	return v.ecBlocks
}

// getVersionForDimensions Deduces version information from Data Matrix dimensions.
//
// @param numRows Number of rows in modules
// @param numColumns Number of columns in modules
// @return Version for a Data Matrix Code of those dimensions
// @throws FormatException if dimensions do correspond to a valid Data Matrix size
//
func getVersionForDimensions(numRows, numColumns int) (*Version, error) {
	if (numRows&0x01) != 0 || (numColumns&0x01) != 0 {
		return nil, gozxing.NewFormatException("numRows=%v, numCols=%v", numRows, numColumns)
	}

	for _, version := range versions {
		if version.symbolSizeRows == numRows && version.symbolSizeColumns == numColumns {
			return version, nil
		}
	}

	return nil, gozxing.NewFormatException("numRows=%v, numCols=%v", numRows, numColumns)
}

// ECBlocks Encapsulates a set of error-correction blocks in one symbol version.
// Most versions will use blocks of differing sizes within one version,
// so, this encapsulates the parameters for each set of blocks.
// It also holds the number of error-correction codewords per block since it
// will be the same across all blocks within one version.
type ECBlocks struct {
	ecCodewords int
	ecBlocks    []ECB
}

func (ecbs *ECBlocks) getECCodewords() int {
	return ecbs.ecCodewords
}

func (ecbs *ECBlocks) getECBlocks() []ECB {
	return ecbs.ecBlocks
}

// ECB Encapsulates the parameters for one error-correction block in one symbol version.
// This includes the number of data codewords, and the number of times a block with these
// parameters is used consecutively in the Data Matrix code version's format.
type ECB struct {
	count         int
	dataCodewords int
}

func (ecb *ECB) getCount() int {
	return ecb.count
}

func (ecb *ECB) getDataCodewords() int {
	return ecb.dataCodewords
}

func (v *Version) String() string {
	return strconv.Itoa(v.versionNumber)
}

// versions  See ISO 16022:2006 5.5.1 Table 7
var versions = []*Version{
	NewVersion(1, 10, 10, 8, 8,
		&ECBlocks{5, []ECB{{1, 3}}}),
	NewVersion(2, 12, 12, 10, 10,
		&ECBlocks{7, []ECB{{1, 5}}}),
	NewVersion(3, 14, 14, 12, 12,
		&ECBlocks{10, []ECB{{1, 8}}}),
	NewVersion(4, 16, 16, 14, 14,
		&ECBlocks{12, []ECB{{1, 12}}}),
	NewVersion(5, 18, 18, 16, 16,
		&ECBlocks{14, []ECB{{1, 18}}}),
	NewVersion(6, 20, 20, 18, 18,
		&ECBlocks{18, []ECB{{1, 22}}}),
	NewVersion(7, 22, 22, 20, 20,
		&ECBlocks{20, []ECB{{1, 30}}}),
	NewVersion(8, 24, 24, 22, 22,
		&ECBlocks{24, []ECB{{1, 36}}}),
	NewVersion(9, 26, 26, 24, 24,
		&ECBlocks{28, []ECB{{1, 44}}}),
	NewVersion(10, 32, 32, 14, 14,
		&ECBlocks{36, []ECB{{1, 62}}}),
	NewVersion(11, 36, 36, 16, 16,
		&ECBlocks{42, []ECB{{1, 86}}}),
	NewVersion(12, 40, 40, 18, 18,
		&ECBlocks{48, []ECB{{1, 114}}}),
	NewVersion(13, 44, 44, 20, 20,
		&ECBlocks{56, []ECB{{1, 144}}}),
	NewVersion(14, 48, 48, 22, 22,
		&ECBlocks{68, []ECB{{1, 174}}}),
	NewVersion(15, 52, 52, 24, 24,
		&ECBlocks{42, []ECB{{2, 102}}}),
	NewVersion(16, 64, 64, 14, 14,
		&ECBlocks{56, []ECB{{2, 140}}}),
	NewVersion(17, 72, 72, 16, 16,
		&ECBlocks{36, []ECB{{4, 92}}}),
	NewVersion(18, 80, 80, 18, 18,
		&ECBlocks{48, []ECB{{4, 114}}}),
	NewVersion(19, 88, 88, 20, 20,
		&ECBlocks{56, []ECB{{4, 144}}}),
	NewVersion(20, 96, 96, 22, 22,
		&ECBlocks{68, []ECB{{4, 174}}}),
	NewVersion(21, 104, 104, 24, 24,
		&ECBlocks{56, []ECB{{6, 136}}}),
	NewVersion(22, 120, 120, 18, 18,
		&ECBlocks{68, []ECB{{6, 175}}}),
	NewVersion(23, 132, 132, 20, 20,
		&ECBlocks{62, []ECB{{8, 163}}}),
	NewVersion(24, 144, 144, 22, 22,
		&ECBlocks{62, []ECB{{8, 156}, {2, 155}}}),
	NewVersion(25, 8, 18, 6, 16,
		&ECBlocks{7, []ECB{{1, 5}}}),
	NewVersion(26, 8, 32, 6, 14,
		&ECBlocks{11, []ECB{{1, 10}}}),
	NewVersion(27, 12, 26, 10, 24,
		&ECBlocks{14, []ECB{{1, 16}}}),
	NewVersion(28, 12, 36, 10, 16,
		&ECBlocks{18, []ECB{{1, 22}}}),
	NewVersion(29, 16, 36, 14, 16,
		&ECBlocks{24, []ECB{{1, 32}}}),
	NewVersion(30, 16, 48, 14, 22,
		&ECBlocks{28, []ECB{{1, 49}}}),

	// extended forms as specified in
	// ISO 21471:2020 (DMRE) 5.5.1 Table 7
	NewVersion(31, 8, 48, 6, 22,
		&ECBlocks{15, []ECB{{1, 18}}}),
	NewVersion(32, 8, 64, 6, 14,
		&ECBlocks{18, []ECB{{1, 24}}}),
	NewVersion(33, 8, 80, 6, 18,
		&ECBlocks{22, []ECB{{1, 32}}}),
	NewVersion(34, 8, 96, 6, 22,
		&ECBlocks{28, []ECB{{1, 38}}}),
	NewVersion(35, 8, 120, 6, 18,
		&ECBlocks{32, []ECB{{1, 49}}}),
	NewVersion(36, 8, 144, 6, 22,
		&ECBlocks{36, []ECB{{1, 63}}}),
	NewVersion(37, 12, 64, 10, 14,
		&ECBlocks{27, []ECB{{1, 43}}}),
	NewVersion(38, 12, 88, 10, 20,
		&ECBlocks{36, []ECB{{1, 64}}}),
	NewVersion(39, 16, 64, 14, 14,
		&ECBlocks{36, []ECB{{1, 62}}}),
	NewVersion(40, 20, 36, 18, 16,
		&ECBlocks{28, []ECB{{1, 44}}}),
	NewVersion(41, 20, 44, 18, 20,
		&ECBlocks{34, []ECB{{1, 56}}}),
	NewVersion(42, 20, 64, 18, 14,
		&ECBlocks{42, []ECB{{1, 84}}}),
	NewVersion(43, 22, 48, 20, 22,
		&ECBlocks{38, []ECB{{1, 72}}}),
	NewVersion(44, 24, 48, 22, 22,
		&ECBlocks{41, []ECB{{1, 80}}}),
	NewVersion(45, 24, 64, 22, 14,
		&ECBlocks{46, []ECB{{1, 108}}}),
	NewVersion(46, 26, 40, 24, 18,
		&ECBlocks{38, []ECB{{1, 70}}}),
	NewVersion(47, 26, 48, 24, 22,
		&ECBlocks{42, []ECB{{1, 90}}}),
	NewVersion(48, 26, 64, 24, 14,
		&ECBlocks{50, []ECB{{1, 118}}}),
}
