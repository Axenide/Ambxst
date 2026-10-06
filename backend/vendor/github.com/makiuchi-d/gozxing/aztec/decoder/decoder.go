package decoder

import (
	"fmt"
	"strings"

	"golang.org/x/text/encoding"
	"golang.org/x/text/encoding/charmap"
	"golang.org/x/text/transform"

	"github.com/makiuchi-d/gozxing"
	"github.com/makiuchi-d/gozxing/aztec/detector"
	"github.com/makiuchi-d/gozxing/common"
	"github.com/makiuchi-d/gozxing/common/reedsolomon"
)

type Table int

const (
	TableUPPER = Table(iota)
	TableLOWER
	TableMIXED
	TableDIGIT
	TablePUNCT
	TableBINARY
)

var (
	UPPER_TABLE = []string{
		"CTRL_PS", " ", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P",
		"Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "CTRL_LL", "CTRL_ML", "CTRL_DL", "CTRL_BS",
	}

	LOWER_TABLE = []string{
		"CTRL_PS", " ", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p",
		"q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "CTRL_US", "CTRL_ML", "CTRL_DL", "CTRL_BS",
	}

	MIXED_TABLE = []string{
		"CTRL_PS", " ", "\001", "\002", "\003", "\004", "\005", "\006", "\007", "\b", "\t", "\n",
		"\013", "\f", "\r", "\033", "\034", "\035", "\036", "\037", "@", "\\", "^", "_",
		"`", "|", "~", "\177", "CTRL_LL", "CTRL_UL", "CTRL_PL", "CTRL_BS",
	}

	PUNCT_TABLE = []string{
		"FLG(n)", "\r", "\r\n", ". ", ", ", ": ", "!", "\"", "#", "$", "%", "&", "'", "(", ")",
		"*", "+", ",", "-", ".", "/", ":", ";", "<", "=", ">", "?", "[", "]", "{", "}", "CTRL_UL",
	}

	DIGIT_TABLE = []string{
		"CTRL_PS", " ", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ",", ".", "CTRL_UL", "CTRL_US",
	}

	DEFAULT_ENCODING encoding.Encoding = charmap.ISO8859_1
)

// Detector The main class which implements Aztec Code decoding -- as opposed to locating and extracting the Aztec Code from an image.
type Decoder struct {
	ddata *detector.AztecDetectorResult
}

func NewDecoder() *Decoder {
	return &Decoder{}
}

func (this *Decoder) Decode(detectorResult *detector.AztecDetectorResult) (*common.DecoderResult, error) {
	this.ddata = detectorResult
	matrix := detectorResult.GetBits()
	rawbits := this.extractBits(matrix)
	correctedBits, err := this.correctBits(rawbits)
	if err != nil {
		return nil, gozxing.WrapFormatException(err)
	}
	rawBytes := convertBoolArrayToByteArray(correctedBits.correctBits)
	result, e := this.getEncodedData(correctedBits.correctBits)
	if e != nil {
		return nil, gozxing.WrapFormatException(e)
	}
	decoderResult := common.NewDecoderResult(rawBytes, result, nil, fmt.Sprintf("%d%%", correctedBits.ecLevel))
	decoderResult.SetNumBits(len(correctedBits.correctBits))
	return decoderResult, nil
}

// HighLevelDecode This method is used for testing the high-level encoder
func (this *Decoder) HighLevelDecode(correctedBits []bool) (string, error) {
	return this.getEncodedData(correctedBits)
}

// getEncodedData Gets the string encoded in the aztec code bits
//
// @return the decoded string
//
func (this *Decoder) getEncodedData(correctedBits []bool) (string, error) {
	endIndex := len(correctedBits)
	latchTable := TableUPPER // table most recently latched to
	shiftTable := TableUPPER // table to use for the next read

	// Final decoded string result
	// (correctedBits-5) / 4 is an upper bound on the size (all-digit result)
	result := make([]byte, 0, (len(correctedBits)-5)/4)

	// Intermediary buffer of decoded bytes, which is decoded into a string and flushed
	// when character encoding changes (ECI) or input ends.
	decodedBytes := make([]byte, 0)
	encoding := DEFAULT_ENCODING

	index := 0
	for index < endIndex {
		if shiftTable == TableBINARY {
			if endIndex-index < 5 {
				break
			}
			length := readCode(correctedBits, index, 5)
			index += 5
			if length == 0 {
				if endIndex-index < 11 {
					break
				}
				length = readCode(correctedBits, index, 11) + 31
				index += 11
			}
			for charCount := 0; charCount < length; charCount++ {
				if endIndex-index < 8 {
					index = endIndex // Force outer loop to exit
					break
				}
				code := readCode(correctedBits, index, 8)
				decodedBytes = append(decodedBytes, byte(code))
				index += 8
			}
			// Go back to whatever mode we had been in
			shiftTable = latchTable
		} else {
			size := 5
			if shiftTable == TableDIGIT {
				size = 4
			}
			if endIndex-index < size {
				break
			}
			code := readCode(correctedBits, index, size)
			index += size
			str, e := getCharacter(shiftTable, code)
			if e != nil {
				return string(result), e
			}
			if str == "FLG(n)" {
				if endIndex-index < 3 {
					break
				}
				n := readCode(correctedBits, index, 3)
				index += 3
				// flush bytes before changing character set
				result, _, e = transform.Append(encoding.NewDecoder(), result, decodedBytes)
				if e != nil {
					return string(result), e
				}
				decodedBytes = decodedBytes[:0]
				switch n {
				case 0:
					result = append(result, 29) // translate FNC1 as ASCII 29
					break
				case 7:
					return string(result), gozxing.NewFormatException("FLG(7) is reserved and illegal")
				default:
					// ECI is decimal integer encoded as 1-6 codes in DIGIT mode
					eci := 0
					if endIndex-index < 4*n {
						break
					}
					for n > 0 {
						n--
						nextDigit := readCode(correctedBits, index, 4)
						index += 4
						if nextDigit < 2 || nextDigit > 11 {
							return string(result), gozxing.NewFormatException("Not a decimal digit")
						}
						eci = eci*10 + (nextDigit - 2)
					}
					charsetECI, e := common.GetCharacterSetECIByValue(eci)
					if e != nil {
						return string(result), gozxing.WrapFormatException(e)
					}
					encoding = charsetECI.GetCharset()
				}
				// Go back to whatever mode we had been in
				shiftTable = latchTable
			} else if strings.HasPrefix(str, "CTRL_") {
				// Table changes
				// ISO/IEC 24778:2008 prescribes ending a shift sequence in the mode from which it was invoked.
				// That's including when that mode is a shift.
				// Our test case dlusbs.png for issue #642 exercises that.
				latchTable = shiftTable // Latch the current mode, so as to return to Upper after U/S B/S
				shiftTable = getTable(str[5])
				if str[6] == 'L' {
					latchTable = shiftTable
				}
			} else {
				// Though stored as a table of strings for convenience, codes actually represent 1 or 2 *bytes*.
				b := []byte(str)
				decodedBytes = append(decodedBytes, b...)
				// Go back to whatever mode we had been in
				shiftTable = latchTable
			}
		}
	}
	result, _, e := transform.Append(encoding.NewDecoder(), result, decodedBytes)
	if e != nil {
		// can't happen
		return string(result), gozxing.WrapFormatException(e)
	}
	return string(result), nil
}

// getTable gets the table corresponding to the char passed
//
func getTable(t byte) Table {
	switch t {
	case 'L':
		return TableLOWER
	case 'P':
		return TablePUNCT
	case 'M':
		return TableMIXED
	case 'D':
		return TableDIGIT
	case 'B':
		return TableBINARY
	case 'U':
	default:
	}
	return TableUPPER
}

// getCharacter Gets the character (or string) corresponding to the passed code in the given table
//
// @param table the table used
// @param code the code of the character
//
func getCharacter(table Table, code int) (string, error) {
	var tbl []string
	switch table {
	case TableUPPER:
		tbl = UPPER_TABLE
	case TableLOWER:
		tbl = LOWER_TABLE
	case TableMIXED:
		tbl = MIXED_TABLE
	case TablePUNCT:
		tbl = PUNCT_TABLE
	case TableDIGIT:
		tbl = DIGIT_TABLE
	default:
		// Should not reach here.
		return "", gozxing.NewFormatException("IllegalStateException: Bad table")
	}
	if code >= len(tbl) {
		return "", gozxing.NewFormatException("OutOfRange: code(%v) > %v", code, len(tbl))
	}
	return tbl[code], nil
}

type correctedBitsResult struct {
	correctBits []bool
	ecLevel     int
}

// correctBits Performs RS error correction on an array of bits.</p>
//
// @return the corrected array
// @throws FormatException if the input contains too many errors
//
func (this *Decoder) correctBits(rawbits []bool) (*correctedBitsResult, error) {
	var gf *reedsolomon.GenericGF
	var codewordSize int

	if this.ddata.GetNbLayers() <= 2 {
		codewordSize = 6
		gf = reedsolomon.GenericGF_AZTEC_DATA_6
	} else if this.ddata.GetNbLayers() <= 8 {
		codewordSize = 8
		gf = reedsolomon.GenericGF_AZTEC_DATA_8
	} else if this.ddata.GetNbLayers() <= 22 {
		codewordSize = 10
		gf = reedsolomon.GenericGF_AZTEC_DATA_10
	} else {
		codewordSize = 12
		gf = reedsolomon.GenericGF_AZTEC_DATA_12
	}

	numDataCodewords := this.ddata.GetNbDatablocks()
	numCodewords := len(rawbits) / codewordSize
	if numCodewords < numDataCodewords {
		return nil, gozxing.NewFormatException("numCodewords (%v) < numDataCodewords (%v)", numCodewords, numDataCodewords)
	}
	offset := len(rawbits) % codewordSize

	dataWords := make([]int, numCodewords)
	for i := 0; i < numCodewords; i, offset = i+1, offset+codewordSize {
		dataWords[i] = readCode(rawbits, offset, codewordSize)
	}

	rsDecoder := reedsolomon.NewReedSolomonDecoder(gf)
	if ex := rsDecoder.Decode(dataWords, numCodewords-numDataCodewords); ex != nil {
		return nil, gozxing.WrapFormatException(ex)
	}

	// Now perform the unstuffing operation.
	// First, count how many bits are going to be thrown out as stuffing
	mask := (1 << codewordSize) - 1
	stuffedBits := 0
	for i := 0; i < numDataCodewords; i++ {
		dataWord := dataWords[i]
		if dataWord == 0 || dataWord == mask {
			return nil, gozxing.NewFormatException("dataWord = %v, mask = %v", dataWord, mask)
		} else if dataWord == 1 || dataWord == mask-1 {
			stuffedBits++
		}
	}
	// Now, actually unpack the bits and remove the stuffing
	correctedBits := make([]bool, numDataCodewords*codewordSize-stuffedBits)
	index := 0
	for i := 0; i < numDataCodewords; i++ {
		dataWord := dataWords[i]
		if dataWord == 1 || dataWord == mask-1 {
			// next codewordSize-1 bits are all zeros or all ones
			v := dataWord > 1
			for j := index; j < index+codewordSize-1; j++ {
				correctedBits[j] = v
			}
			index += codewordSize - 1
		} else {
			for bit := codewordSize - 1; bit >= 0; bit-- {
				correctedBits[index] = (dataWord & (1 << bit)) != 0
				index++
			}
		}
	}

	return &correctedBitsResult{
		correctBits: correctedBits,
		ecLevel:     100 * (numCodewords - numDataCodewords) / numCodewords,
	}, nil
}

// extractBits Gets the array of bits from an Aztec Code matrix
//
// @return the array of bits
//
func (this *Decoder) extractBits(matrix *gozxing.BitMatrix) []bool {
	compact := this.ddata.IsCompact()
	layers := this.ddata.GetNbLayers()
	baseMatrixSize := layers * 4 // not including alignment lines
	if compact {
		baseMatrixSize += 11
	} else {
		baseMatrixSize += 14
	}
	alignmentMap := make([]int, baseMatrixSize)
	rawbits := make([]bool, totalBitsInLayer(layers, compact))

	if compact {
		for i := 0; i < len(alignmentMap); i++ {
			alignmentMap[i] = i
		}
	} else {
		matrixSize := baseMatrixSize + 1 + 2*((baseMatrixSize/2-1)/15)
		origCenter := baseMatrixSize / 2
		center := matrixSize / 2
		for i := 0; i < origCenter; i++ {
			newOffset := i + i/15
			alignmentMap[origCenter-i-1] = center - newOffset - 1
			alignmentMap[origCenter+i] = center + newOffset + 1
		}
	}
	for i, rowOffset := 0, 0; i < layers; i++ {
		rowSize := (layers - i) * 4
		if compact {
			rowSize += 9
		} else {
			rowSize += 12
		}
		// The top-left most point of this layer is <low, low> (not including alignment lines)
		low := i * 2
		// The bottom-right most point of this layer is <high, high> (not including alignment lines)
		high := baseMatrixSize - 1 - low
		// We pull bits from the two 2 x rowSize columns and two rowSize x 2 rows
		for j := 0; j < rowSize; j++ {
			columnOffset := j * 2
			for k := 0; k < 2; k++ {
				// left column
				rawbits[rowOffset+columnOffset+k] =
					matrix.Get(alignmentMap[low+k], alignmentMap[low+j])
				// bottom row
				rawbits[rowOffset+2*rowSize+columnOffset+k] =
					matrix.Get(alignmentMap[low+j], alignmentMap[high-k])
				// right column
				rawbits[rowOffset+4*rowSize+columnOffset+k] =
					matrix.Get(alignmentMap[high-k], alignmentMap[high-j])
				// top row
				rawbits[rowOffset+6*rowSize+columnOffset+k] =
					matrix.Get(alignmentMap[high-j], alignmentMap[low+k])
			}
		}
		rowOffset += rowSize * 8
	}
	return rawbits
}

// readCode Reads a code of given length and at given index in an array of bits
func readCode(rawbits []bool, startIndex, length int) int {
	res := 0
	for i := startIndex; i < startIndex+length; i++ {
		res <<= 1
		if rawbits[i] {
			res |= 0x01
		}
	}
	return res
}

// readByte Reads a code of length 8 in an array of bits, padding with zeros
func readByte(rawbites []bool, startIndex int) byte {
	n := len(rawbites) - startIndex
	if n >= 8 {
		return byte(readCode(rawbites, startIndex, 8))
	}
	return byte(readCode(rawbites, startIndex, n) << (8 - n))
}

// convertBoolArrayToByteArray Packs a bit array into bytes, most significant bit first
func convertBoolArrayToByteArray(boolArr []bool) []byte {
	byteArr := make([]byte, (len(boolArr)+7)/8)
	for i := 0; i < len(byteArr); i++ {
		byteArr[i] = readByte(boolArr, 8*i)
	}
	return byteArr
}

func totalBitsInLayer(layers int, compact bool) int {
	n := 112
	if compact {
		n = 88
	}
	return (n + 16*layers) * layers
}
