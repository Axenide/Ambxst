package decoder

import (
	"math"
	"strconv"

	errors "golang.org/x/xerrors"

	"github.com/makiuchi-d/gozxing"
)

type Version struct {
	versionNumber           int
	alignmentPatternCenters []int
	ecBlocks                []ECBlocks
	totalCodewords          int
}

var VERSION_DECODE_INFO = []int{
	0x07C94, 0x085BC, 0x09A99, 0x0A4D3, 0x0BBF6,
	0x0C762, 0x0D847, 0x0E60D, 0x0F928, 0x10B78,
	0x1145D, 0x12A17, 0x13532, 0x149A6, 0x15683,
	0x168C9, 0x177EC, 0x18EC4, 0x191E1, 0x1AFAB,
	0x1B08E, 0x1CC1A, 0x1D33F, 0x1ED75, 0x1F250,
	0x209D5, 0x216F0, 0x228BA, 0x2379F, 0x24B0B,
	0x2542E, 0x26A64, 0x27541, 0x28C69,
}

func NewVersion(versionNumber int, alignmentPatternCenters []int, ecBlocks ...ECBlocks) *Version {
	total := 0
	ecCodewords := ecBlocks[0].GetECCodewordsPerBlock()
	ecbArray := ecBlocks[0].GetECBlocks()
	for _, ecBlock := range ecbArray {
		total += ecBlock.GetCount() * (ecBlock.GetDataCodewords() + ecCodewords)
	}
	return &Version{
		versionNumber,
		alignmentPatternCenters,
		ecBlocks,
		total}
}

func (v *Version) GetVersionNumber() int {
	return v.versionNumber
}

func (v *Version) GetAlignmentPatternCenters() []int {
	return v.alignmentPatternCenters
}

func (v *Version) GetTotalCodewords() int {
	return v.totalCodewords
}

func (v *Version) GetDimensionForVersion() int {
	return 17 + 4*v.versionNumber
}

func (v *Version) GetECBlocksForLevel(ecLevel ErrorCorrectionLevel) *ECBlocks {
	switch ecLevel {
	case ErrorCorrectionLevel_L:
		return &v.ecBlocks[0]
	case ErrorCorrectionLevel_M:
		return &v.ecBlocks[1]
	case ErrorCorrectionLevel_Q:
		return &v.ecBlocks[2]
	case ErrorCorrectionLevel_H:
		return &v.ecBlocks[3]
	}
	return nil
}

func Version_GetProvisionalVersionForDimension(dimension int) (*Version, error) {
	if dimension%4 != 1 {
		return nil, errors.Errorf("dimengion = %v", dimension)
	}
	return Version_GetVersionForNumber((dimension - 17) / 4)
}

func Version_GetVersionForNumber(versionNumber int) (*Version, error) {
	if versionNumber < 1 || versionNumber > 40 {
		return nil, errors.Errorf("IllegalArgumentException: versionNumber = %d", versionNumber)
	}
	return VERSIONS[versionNumber-1], nil
}

func Version_decodeVersionInformation(versionBits int) (*Version, error) {
	bestDifference := math.MaxInt32
	bestVersion := 0
	for i, targetVersion := range VERSION_DECODE_INFO {
		if targetVersion == versionBits {
			return Version_GetVersionForNumber(i + 7)
		}
		bitsDifference := FormatInformation_NumBitsDiffering(uint(versionBits), uint(targetVersion))
		if bitsDifference < bestDifference {
			bestVersion = i + 7
			bestDifference = bitsDifference
		}
	}

	if bestDifference <= 3 {
		return Version_GetVersionForNumber(bestVersion)
	}

	return nil, errors.Errorf("we didn't find a close enough match 0x%x", versionBits)
}

func (v *Version) buildFunctionPattern() (*gozxing.BitMatrix, error) {
	dimension := v.GetDimensionForVersion()
	bitMatrix, e := gozxing.NewSquareBitMatrix(dimension)
	if e != nil {
		return nil, e
	}

	bitMatrix.SetRegion(0, 0, 9, 9)
	bitMatrix.SetRegion(dimension-8, 0, 8, 9)
	bitMatrix.SetRegion(0, dimension-8, 9, 8)

	max := len(v.alignmentPatternCenters)
	for x := 0; x < max; x++ {
		i := v.alignmentPatternCenters[x] - 2
		for y := 0; y < max; y++ {
			if (x == 0 && (y == 0 || y == max-1)) || (x == max-1 && y == 0) {
				continue
			}
			bitMatrix.SetRegion(v.alignmentPatternCenters[y]-2, i, 5, 5)
		}
	}

	bitMatrix.SetRegion(6, 9, 1, dimension-17)
	bitMatrix.SetRegion(9, 6, dimension-17, 1)

	if v.versionNumber > 6 {
		bitMatrix.SetRegion(dimension-11, 0, 3, 6)
		bitMatrix.SetRegion(0, dimension-11, 6, 3)
	}

	return bitMatrix, nil
}

type ECBlocks struct {
	ecCodewordsPerBlock int
	ecBlocks            []ECB
}

func (b *ECBlocks) GetECCodewordsPerBlock() int {
	return b.ecCodewordsPerBlock
}

func (b *ECBlocks) GetNumBlocks() int {
	total := 0
	for _, ecBlock := range b.ecBlocks {
		total += ecBlock.GetCount()
	}
	return total
}

func (b *ECBlocks) GetTotalECCodewords() int {
	return b.ecCodewordsPerBlock * b.GetNumBlocks()
}

func (b *ECBlocks) GetECBlocks() []ECB {
	return b.ecBlocks
}

type ECB struct {
	count         int
	dataCodewords int
}

func (e ECB) GetCount() int {
	return e.count
}

func (e ECB) GetDataCodewords() int {
	return e.dataCodewords
}

func (this *Version) String() string {
	if this == nil {
		return ""
	}
	return strconv.Itoa(this.versionNumber)
}

var VERSIONS = []*Version{
	NewVersion(1, []int{},
		ECBlocks{7, []ECB{{1, 19}}},
		ECBlocks{10, []ECB{{1, 16}}},
		ECBlocks{13, []ECB{{1, 13}}},
		ECBlocks{17, []ECB{{1, 9}}}),
	NewVersion(2, []int{6, 18},
		ECBlocks{10, []ECB{{1, 34}}},
		ECBlocks{16, []ECB{{1, 28}}},
		ECBlocks{22, []ECB{{1, 22}}},
		ECBlocks{28, []ECB{{1, 16}}}),
	NewVersion(3, []int{6, 22},
		ECBlocks{15, []ECB{{1, 55}}},
		ECBlocks{26, []ECB{{1, 44}}},
		ECBlocks{18, []ECB{{2, 17}}},
		ECBlocks{22, []ECB{{2, 13}}}),
	NewVersion(4, []int{6, 26},
		ECBlocks{20, []ECB{{1, 80}}},
		ECBlocks{18, []ECB{{2, 32}}},
		ECBlocks{26, []ECB{{2, 24}}},
		ECBlocks{16, []ECB{{4, 9}}}),
	NewVersion(5, []int{6, 30},
		ECBlocks{26, []ECB{{1, 108}}},
		ECBlocks{24, []ECB{{2, 43}}},
		ECBlocks{18, []ECB{{2, 15}, {2, 16}}},
		ECBlocks{22, []ECB{{2, 11}, {2, 12}}}),
	NewVersion(6, []int{6, 34},
		ECBlocks{18, []ECB{{2, 68}}},
		ECBlocks{16, []ECB{{4, 27}}},
		ECBlocks{24, []ECB{{4, 19}}},
		ECBlocks{28, []ECB{{4, 15}}}),
	NewVersion(7, []int{6, 22, 38},
		ECBlocks{20, []ECB{{2, 78}}},
		ECBlocks{18, []ECB{{4, 31}}},
		ECBlocks{18, []ECB{{2, 14}, {4, 15}}},
		ECBlocks{26, []ECB{{4, 13}, {1, 14}}}),
	NewVersion(8, []int{6, 24, 42},
		ECBlocks{24, []ECB{{2, 97}}},
		ECBlocks{22, []ECB{{2, 38}, {2, 39}}},
		ECBlocks{22, []ECB{{4, 18}, {2, 19}}},
		ECBlocks{26, []ECB{{4, 14}, {2, 15}}}),
	NewVersion(9, []int{6, 26, 46},
		ECBlocks{30, []ECB{{2, 116}}},
		ECBlocks{22, []ECB{{3, 36}, {2, 37}}},
		ECBlocks{20, []ECB{{4, 16}, {4, 17}}},
		ECBlocks{24, []ECB{{4, 12}, {4, 13}}}),
	NewVersion(10, []int{6, 28, 50},
		ECBlocks{18, []ECB{{2, 68}, {2, 69}}},
		ECBlocks{26, []ECB{{4, 43}, {1, 44}}},
		ECBlocks{24, []ECB{{6, 19}, {2, 20}}},
		ECBlocks{28, []ECB{{6, 15}, {2, 16}}}),
	NewVersion(11, []int{6, 30, 54},
		ECBlocks{20, []ECB{{4, 81}}},
		ECBlocks{30, []ECB{{1, 50}, {4, 51}}},
		ECBlocks{28, []ECB{{4, 22}, {4, 23}}},
		ECBlocks{24, []ECB{{3, 12}, {8, 13}}}),
	NewVersion(12, []int{6, 32, 58},
		ECBlocks{24, []ECB{{2, 92}, {2, 93}}},
		ECBlocks{22, []ECB{{6, 36}, {2, 37}}},
		ECBlocks{26, []ECB{{4, 20}, {6, 21}}},
		ECBlocks{28, []ECB{{7, 14}, {4, 15}}}),
	NewVersion(13, []int{6, 34, 62},
		ECBlocks{26, []ECB{{4, 107}}},
		ECBlocks{22, []ECB{{8, 37}, {1, 38}}},
		ECBlocks{24, []ECB{{8, 20}, {4, 21}}},
		ECBlocks{22, []ECB{{12, 11}, {4, 12}}}),
	NewVersion(14, []int{6, 26, 46, 66},
		ECBlocks{30, []ECB{{3, 115}, {1, 116}}},
		ECBlocks{24, []ECB{{4, 40}, {5, 41}}},
		ECBlocks{20, []ECB{{11, 16}, {5, 17}}},
		ECBlocks{24, []ECB{{11, 12}, {5, 13}}}),
	NewVersion(15, []int{6, 26, 48, 70},
		ECBlocks{22, []ECB{{5, 87}, {1, 88}}},
		ECBlocks{24, []ECB{{5, 41}, {5, 42}}},
		ECBlocks{30, []ECB{{5, 24}, {7, 25}}},
		ECBlocks{24, []ECB{{11, 12}, {7, 13}}}),
	NewVersion(16, []int{6, 26, 50, 74},
		ECBlocks{24, []ECB{{5, 98}, {1, 99}}},
		ECBlocks{28, []ECB{{7, 45}, {3, 46}}},
		ECBlocks{24, []ECB{{15, 19}, {2, 20}}},
		ECBlocks{30, []ECB{{3, 15}, {13, 16}}}),
	NewVersion(17, []int{6, 30, 54, 78},
		ECBlocks{28, []ECB{{1, 107}, {5, 108}}},
		ECBlocks{28, []ECB{{10, 46}, {1, 47}}},
		ECBlocks{28, []ECB{{1, 22}, {15, 23}}},
		ECBlocks{28, []ECB{{2, 14}, {17, 15}}}),
	NewVersion(18, []int{6, 30, 56, 82},
		ECBlocks{30, []ECB{{5, 120}, {1, 121}}},
		ECBlocks{26, []ECB{{9, 43}, {4, 44}}},
		ECBlocks{28, []ECB{{17, 22}, {1, 23}}},
		ECBlocks{28, []ECB{{2, 14}, {19, 15}}}),
	NewVersion(19, []int{6, 30, 58, 86},
		ECBlocks{28, []ECB{{3, 113}, {4, 114}}},
		ECBlocks{26, []ECB{{3, 44}, {11, 45}}},
		ECBlocks{26, []ECB{{17, 21}, {4, 22}}},
		ECBlocks{26, []ECB{{9, 13}, {16, 14}}}),
	NewVersion(20, []int{6, 34, 62, 90},
		ECBlocks{28, []ECB{{3, 107}, {5, 108}}},
		ECBlocks{26, []ECB{{3, 41}, {13, 42}}},
		ECBlocks{30, []ECB{{15, 24}, {5, 25}}},
		ECBlocks{28, []ECB{{15, 15}, {10, 16}}}),
	NewVersion(21, []int{6, 28, 50, 72, 94},
		ECBlocks{28, []ECB{{4, 116}, {4, 117}}},
		ECBlocks{26, []ECB{{17, 42}}},
		ECBlocks{28, []ECB{{17, 22}, {6, 23}}},
		ECBlocks{30, []ECB{{19, 16}, {6, 17}}}),
	NewVersion(22, []int{6, 26, 50, 74, 98},
		ECBlocks{28, []ECB{{2, 111}, {7, 112}}},
		ECBlocks{28, []ECB{{17, 46}}},
		ECBlocks{30, []ECB{{7, 24}, {16, 25}}},
		ECBlocks{24, []ECB{{34, 13}}}),
	NewVersion(23, []int{6, 30, 54, 78, 102},
		ECBlocks{30, []ECB{{4, 121}, {5, 122}}},
		ECBlocks{28, []ECB{{4, 47}, {14, 48}}},
		ECBlocks{30, []ECB{{11, 24}, {14, 25}}},
		ECBlocks{30, []ECB{{16, 15}, {14, 16}}}),
	NewVersion(24, []int{6, 28, 54, 80, 106},
		ECBlocks{30, []ECB{{6, 117}, {4, 118}}},
		ECBlocks{28, []ECB{{6, 45}, {14, 46}}},
		ECBlocks{30, []ECB{{11, 24}, {16, 25}}},
		ECBlocks{30, []ECB{{30, 16}, {2, 17}}}),
	NewVersion(25, []int{6, 32, 58, 84, 110},
		ECBlocks{26, []ECB{{8, 106}, {4, 107}}},
		ECBlocks{28, []ECB{{8, 47}, {13, 48}}},
		ECBlocks{30, []ECB{{7, 24}, {22, 25}}},
		ECBlocks{30, []ECB{{22, 15}, {13, 16}}}),
	NewVersion(26, []int{6, 30, 58, 86, 114},
		ECBlocks{28, []ECB{{10, 114}, {2, 115}}},
		ECBlocks{28, []ECB{{19, 46}, {4, 47}}},
		ECBlocks{28, []ECB{{28, 22}, {6, 23}}},
		ECBlocks{30, []ECB{{33, 16}, {4, 17}}}),
	NewVersion(27, []int{6, 34, 62, 90, 118},
		ECBlocks{30, []ECB{{8, 122}, {4, 123}}},
		ECBlocks{28, []ECB{{22, 45}, {3, 46}}},
		ECBlocks{30, []ECB{{8, 23}, {26, 24}}},
		ECBlocks{30, []ECB{{12, 15}, {28, 16}}}),
	NewVersion(28, []int{6, 26, 50, 74, 98, 122},
		ECBlocks{30, []ECB{{3, 117}, {10, 118}}},
		ECBlocks{28, []ECB{{3, 45}, {23, 46}}},
		ECBlocks{30, []ECB{{4, 24}, {31, 25}}},
		ECBlocks{30, []ECB{{11, 15}, {31, 16}}}),
	NewVersion(29, []int{6, 30, 54, 78, 102, 126},
		ECBlocks{30, []ECB{{7, 116}, {7, 117}}},
		ECBlocks{28, []ECB{{21, 45}, {7, 46}}},
		ECBlocks{30, []ECB{{1, 23}, {37, 24}}},
		ECBlocks{30, []ECB{{19, 15}, {26, 16}}}),
	NewVersion(30, []int{6, 26, 52, 78, 104, 130},
		ECBlocks{30, []ECB{{5, 115}, {10, 116}}},
		ECBlocks{28, []ECB{{19, 47}, {10, 48}}},
		ECBlocks{30, []ECB{{15, 24}, {25, 25}}},
		ECBlocks{30, []ECB{{23, 15}, {25, 16}}}),
	NewVersion(31, []int{6, 30, 56, 82, 108, 134},
		ECBlocks{30, []ECB{{13, 115}, {3, 116}}},
		ECBlocks{28, []ECB{{2, 46}, {29, 47}}},
		ECBlocks{30, []ECB{{42, 24}, {1, 25}}},
		ECBlocks{30, []ECB{{23, 15}, {28, 16}}}),
	NewVersion(32, []int{6, 34, 60, 86, 112, 138},
		ECBlocks{30, []ECB{{17, 115}}},
		ECBlocks{28, []ECB{{10, 46}, {23, 47}}},
		ECBlocks{30, []ECB{{10, 24}, {35, 25}}},
		ECBlocks{30, []ECB{{19, 15}, {35, 16}}}),
	NewVersion(33, []int{6, 30, 58, 86, 114, 142},
		ECBlocks{30, []ECB{{17, 115}, {1, 116}}},
		ECBlocks{28, []ECB{{14, 46}, {21, 47}}},
		ECBlocks{30, []ECB{{29, 24}, {19, 25}}},
		ECBlocks{30, []ECB{{11, 15}, {46, 16}}}),
	NewVersion(34, []int{6, 34, 62, 90, 118, 146},
		ECBlocks{30, []ECB{{13, 115}, {6, 116}}},
		ECBlocks{28, []ECB{{14, 46}, {23, 47}}},
		ECBlocks{30, []ECB{{44, 24}, {7, 25}}},
		ECBlocks{30, []ECB{{59, 16}, {1, 17}}}),
	NewVersion(35, []int{6, 30, 54, 78, 102, 126, 150},
		ECBlocks{30, []ECB{{12, 121}, {7, 122}}},
		ECBlocks{28, []ECB{{12, 47}, {26, 48}}},
		ECBlocks{30, []ECB{{39, 24}, {14, 25}}},
		ECBlocks{30, []ECB{{22, 15}, {41, 16}}}),
	NewVersion(36, []int{6, 24, 50, 76, 102, 128, 154},
		ECBlocks{30, []ECB{{6, 121}, {14, 122}}},
		ECBlocks{28, []ECB{{6, 47}, {34, 48}}},
		ECBlocks{30, []ECB{{46, 24}, {10, 25}}},
		ECBlocks{30, []ECB{{2, 15}, {64, 16}}}),
	NewVersion(37, []int{6, 28, 54, 80, 106, 132, 158},
		ECBlocks{30, []ECB{{17, 122}, {4, 123}}},
		ECBlocks{28, []ECB{{29, 46}, {14, 47}}},
		ECBlocks{30, []ECB{{49, 24}, {10, 25}}},
		ECBlocks{30, []ECB{{24, 15}, {46, 16}}}),
	NewVersion(38, []int{6, 32, 58, 84, 110, 136, 162},
		ECBlocks{30, []ECB{{4, 122}, {18, 123}}},
		ECBlocks{28, []ECB{{13, 46}, {32, 47}}},
		ECBlocks{30, []ECB{{48, 24}, {14, 25}}},
		ECBlocks{30, []ECB{{42, 15}, {32, 16}}}),
	NewVersion(39, []int{6, 26, 54, 82, 110, 138, 166},
		ECBlocks{30, []ECB{{20, 117}, {4, 118}}},
		ECBlocks{28, []ECB{{40, 47}, {7, 48}}},
		ECBlocks{30, []ECB{{43, 24}, {22, 25}}},
		ECBlocks{30, []ECB{{10, 15}, {67, 16}}}),
	NewVersion(40, []int{6, 30, 58, 86, 114, 142, 170},
		ECBlocks{30, []ECB{{19, 118}, {6, 119}}},
		ECBlocks{28, []ECB{{18, 47}, {31, 48}}},
		ECBlocks{30, []ECB{{34, 24}, {34, 25}}},
		ECBlocks{30, []ECB{{20, 15}, {61, 16}}}),
}
