package decoder

import (
	"github.com/makiuchi-d/gozxing"
)

type BitMatrixParser struct {
	mappingBitMatrix  *gozxing.BitMatrix
	readMappingMatrix *gozxing.BitMatrix
	version           *Version
}

// NewBitMatrixParser construct parser
// @param bitMatrix {@link BitMatrix} to parse
// @throws FormatException if dimension is < 8 or > 144 or not 0 mod 2
func NewBitMatrixParser(bitMatrix *gozxing.BitMatrix) (*BitMatrixParser, error) {
	dimension := bitMatrix.GetHeight()
	if dimension < 8 || dimension > 144 || (dimension&0x01) != 0 {
		return nil, gozxing.NewFormatException("dimension = %v", dimension)
	}

	version, e := readVersion(bitMatrix)
	if e != nil {
		return nil, e
	}
	mappingBitMatrix, _ := extractDataRegion(version, bitMatrix)
	readMappingMatrix, _ := gozxing.NewBitMatrix(mappingBitMatrix.GetWidth(), mappingBitMatrix.GetHeight())
	return &BitMatrixParser{
		mappingBitMatrix:  mappingBitMatrix,
		readMappingMatrix: readMappingMatrix,
		version:           version,
	}, nil
}

func (p *BitMatrixParser) GetVersion() *Version {
	return p.version
}

// readVersion Creates the version object based on the dimension of the original bit matrix from
// the datamatrix code.
//
// See ISO 16022:2006 Table 7 - ECC 200 symbol attributes
//
// @param bitMatrix Original {@link BitMatrix} including alignment patterns
// @return {@link Version} encapsulating the Data Matrix Code's "version"
// @throws FormatException if the dimensions of the mapping matrix are not valid
// Data Matrix dimensions.
func readVersion(bitMatrix *gozxing.BitMatrix) (*Version, error) {
	numRows := bitMatrix.GetHeight()
	numColumns := bitMatrix.GetWidth()
	return getVersionForDimensions(numRows, numColumns)
}

// readCodewords Reads the bits in the BitMatrix representing the mapping matrix (No alignment patterns)
// in the correct order in order to reconstitute the codewords bytes contained within the
// Data Matrix Code.
//
// @return bytes encoded within the Data Matrix Code
// @throws FormatException if the exact number of bytes expected is not read
func (p *BitMatrixParser) readCodewords() ([]byte, error) {

	result := make([]byte, p.version.getTotalCodewords())
	resultOffset := 0

	row := 4
	column := 0

	numRows := p.mappingBitMatrix.GetHeight()
	numColumns := p.mappingBitMatrix.GetWidth()

	corner1Read := false
	corner2Read := false
	corner3Read := false
	corner4Read := false

	// Read all of the codewords
	for {
		// Check the four corner cases
		if (row == numRows) && (column == 0) && !corner1Read {
			result[resultOffset] = p.readCorner1(numRows, numColumns)
			resultOffset++
			row -= 2
			column += 2
			corner1Read = true
		} else if (row == numRows-2) && (column == 0) && ((numColumns & 0x03) != 0) && !corner2Read {
			result[resultOffset] = p.readCorner2(numRows, numColumns)
			resultOffset++
			row -= 2
			column += 2
			corner2Read = true
		} else if (row == numRows+4) && (column == 2) && ((numColumns & 0x07) == 0) && !corner3Read {
			result[resultOffset] = p.readCorner3(numRows, numColumns)
			resultOffset++
			row -= 2
			column += 2
			corner3Read = true
		} else if (row == numRows-2) && (column == 0) && ((numColumns & 0x07) == 4) && !corner4Read {
			result[resultOffset] = p.readCorner4(numRows, numColumns)
			resultOffset++
			row -= 2
			column += 2
			corner4Read = true
		} else {
			// Sweep upward diagonally to the right
			for {
				if (row < numRows) && (column >= 0) && !p.readMappingMatrix.Get(column, row) {
					result[resultOffset] = p.readUtah(row, column, numRows, numColumns)
					resultOffset++
				}
				row -= 2
				column += 2
				if !((row >= 0) && (column < numColumns)) {
					break
				}
			}
			row += 1
			column += 3

			// Sweep downward diagonally to the left
			for {
				if (row >= 0) && (column < numColumns) && !p.readMappingMatrix.Get(column, row) {
					result[resultOffset] = p.readUtah(row, column, numRows, numColumns)
					resultOffset++
				}
				row += 2
				column -= 2
				if !((row < numRows) && (column >= 0)) {
					break
				}
			}
			row += 3
			column += 1
		}

		if !((row < numRows) || (column < numColumns)) {
			break
		}
	}

	if t := p.version.getTotalCodewords(); resultOffset != t {
		return nil, gozxing.NewFormatException(
			"resultOffset=%v, totalCodewords=%v", resultOffset, t)
	}
	return result, nil
}

// readModule Reads a bit of the mapping matrix accounting for boundary wrapping.
//
// @param row Row to read in the mapping matrix
// @param column Column to read in the mapping matrix
// @param numRows Number of rows in the mapping matrix
// @param numColumns Number of columns in the mapping matrix
// @return value of the given bit in the mapping matrix
func (p *BitMatrixParser) readModule(row, column, numRows, numColumns int) bool {
	// Adjust the row and column indices based on boundary wrapping
	if row < 0 {
		row += numRows
		column += 4 - ((numRows + 4) & 0x07)
	}
	if column < 0 {
		column += numColumns
		row += 4 - ((numColumns + 4) & 0x07)
	}
	if row >= numRows {
		row -= numRows
	}
	p.readMappingMatrix.Set(column, row)
	return p.mappingBitMatrix.Get(column, row)
}

// readUtah Reads the 8 bits of the standard Utah-shaped pattern.
//
// See ISO 16022:2006, 5.8.1 Figure 6
//
// @param row Current row in the mapping matrix, anchored at the 8th bit (LSB) of the pattern
// @param column Current column in the mapping matrix, anchored at the 8th bit (LSB) of the pattern
// @param numRows Number of rows in the mapping matrix
// @param numColumns Number of columns in the mapping matrix
// @return byte from the utah shape
//
func (p *BitMatrixParser) readUtah(row, column, numRows, numColumns int) byte {
	currentByte := byte(0)
	if p.readModule(row-2, column-2, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(row-2, column-1, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(row-1, column-2, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(row-1, column-1, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(row-1, column, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(row, column-2, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(row, column-1, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(row, column, numRows, numColumns) {
		currentByte |= 1
	}
	return currentByte
}

// readCorner1Reads the 8 bits of the special corner condition 1.
//
// See ISO 16022:2006, Figure F.3
//
// @param numRows Number of rows in the mapping matrix
// @param numColumns Number of columns in the mapping matrix
// @return byte from the Corner condition 1
//
func (p *BitMatrixParser) readCorner1(numRows, numColumns int) byte {
	currentByte := byte(0)
	if p.readModule(numRows-1, 0, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(numRows-1, 1, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(numRows-1, 2, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(0, numColumns-2, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(0, numColumns-1, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(1, numColumns-1, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(2, numColumns-1, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(3, numColumns-1, numRows, numColumns) {
		currentByte |= 1
	}
	return currentByte
}

// readCorner2 Reads the 8 bits of the special corner condition 2.
//
// See ISO 16022:2006, Figure F.4
//
// @param numRows Number of rows in the mapping matrix
// @param numColumns Number of columns in the mapping matrix
// @return byte from the Corner condition 2
func (p *BitMatrixParser) readCorner2(numRows, numColumns int) byte {
	currentByte := byte(0)
	if p.readModule(numRows-3, 0, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(numRows-2, 0, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(numRows-1, 0, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(0, numColumns-4, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(0, numColumns-3, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(0, numColumns-2, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(0, numColumns-1, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(1, numColumns-1, numRows, numColumns) {
		currentByte |= 1
	}
	return currentByte
}

// readCorner3 Reads the 8 bits of the special corner condition 3.
//
// See ISO 16022:2006, Figure F.5
//
// @param numRows Number of rows in the mapping matrix
// @param numColumns Number of columns in the mapping matrix
// @return byte from the Corner condition 3
//
func (p *BitMatrixParser) readCorner3(numRows, numColumns int) byte {
	currentByte := byte(0)
	if p.readModule(numRows-1, 0, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(numRows-1, numColumns-1, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(0, numColumns-3, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(0, numColumns-2, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(0, numColumns-1, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(1, numColumns-3, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(1, numColumns-2, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(1, numColumns-1, numRows, numColumns) {
		currentByte |= 1
	}
	return currentByte
}

// readCorner4 <p>Reads the 8 bits of the special corner condition 4.</p>
//
// See ISO 16022:2006, Figure F.6
//
// @param numRows Number of rows in the mapping matrix
// @param numColumns Number of columns in the mapping matrix
// @return byte from the Corner condition 4
//
func (p *BitMatrixParser) readCorner4(numRows, numColumns int) byte {
	currentByte := byte(0)
	if p.readModule(numRows-3, 0, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(numRows-2, 0, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(numRows-1, 0, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(0, numColumns-2, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(0, numColumns-1, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(1, numColumns-1, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(2, numColumns-1, numRows, numColumns) {
		currentByte |= 1
	}
	currentByte <<= 1
	if p.readModule(3, numColumns-1, numRows, numColumns) {
		currentByte |= 1
	}
	return currentByte
}

// extractDataRegion Extracts the data region from a {@link BitMatrix} that contains alignment patterns.
//
// @param bitMatrix Original {@link BitMatrix} with alignment patterns
// @return BitMatrix that has the alignment patterns removed
//
func extractDataRegion(version *Version, bitMatrix *gozxing.BitMatrix) (*gozxing.BitMatrix, error) {
	symbolSizeRows := version.getSymbolSizeRows()
	symbolSizeColumns := version.getSymbolSizeColumns()

	if bitMatrix.GetHeight() != symbolSizeRows {
		return nil, gozxing.NewFormatException(
			"IllegalArgumentException: Dimension of bitMatrix must match the version size")
	}

	dataRegionSizeRows := version.getDataRegionSizeRows()
	dataRegionSizeColumns := version.getDataRegionSizeColumns()

	numDataRegionsRow := symbolSizeRows / dataRegionSizeRows
	numDataRegionsColumn := symbolSizeColumns / dataRegionSizeColumns

	sizeDataRegionRow := numDataRegionsRow * dataRegionSizeRows
	sizeDataRegionColumn := numDataRegionsColumn * dataRegionSizeColumns

	bitMatrixWithoutAlignment, _ := gozxing.NewBitMatrix(sizeDataRegionColumn, sizeDataRegionRow)
	for dataRegionRow := 0; dataRegionRow < numDataRegionsRow; dataRegionRow++ {
		dataRegionRowOffset := dataRegionRow * dataRegionSizeRows
		for dataRegionColumn := 0; dataRegionColumn < numDataRegionsColumn; dataRegionColumn++ {
			dataRegionColumnOffset := dataRegionColumn * dataRegionSizeColumns
			for i := 0; i < dataRegionSizeRows; i++ {
				readRowOffset := dataRegionRow*(dataRegionSizeRows+2) + 1 + i
				writeRowOffset := dataRegionRowOffset + i
				for j := 0; j < dataRegionSizeColumns; j++ {
					readColumnOffset := dataRegionColumn*(dataRegionSizeColumns+2) + 1 + j
					if bitMatrix.Get(readColumnOffset, readRowOffset) {
						writeColumnOffset := dataRegionColumnOffset + j
						bitMatrixWithoutAlignment.Set(writeColumnOffset, writeRowOffset)
					}
				}
			}
		}
	}
	return bitMatrixWithoutAlignment, nil
}
