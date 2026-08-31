package encoder

import (
	"fmt"
	"math"
	"strconv"
	"unicode/utf8"

	textencoding "golang.org/x/text/encoding"
	"golang.org/x/text/encoding/unicode"

	"github.com/makiuchi-d/gozxing"
	"github.com/makiuchi-d/gozxing/common"
	"github.com/makiuchi-d/gozxing/common/reedsolomon"
	"github.com/makiuchi-d/gozxing/qrcode/decoder"
)

var (
	Encoder_DEFAULT_BYTE_MODE_ENCODING textencoding.Encoding = unicode.UTF8 // original default is "ISO-8859-1"
)

var alphanumericTable = []int{
	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, // 0x00-0x0f
	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, // 0x10-0x1f
	36, -1, -1, -1, 37, 38, -1, -1, -1, -1, 39, 40, -1, 41, 42, 43, // 0x20-0x2f
	0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 44, -1, -1, -1, -1, -1, // 0x30-0x3f
	-1, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, // 0x40-0x4f
	25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, -1, -1, -1, -1, -1, // 0x50-0x5f
}

// calculateMaskPenalty The mask penalty calculation is complicated.
// See Table 21 of JISX0510:2004 (p.45) for details.
// Basically it applies four rules and summate all penalties.
func calculateMaskPenalty(matrix *ByteMatrix) int {
	return MaskUtil_applyMaskPenaltyRule1(matrix) +
		MaskUtil_applyMaskPenaltyRule2(matrix) +
		MaskUtil_applyMaskPenaltyRule3(matrix) +
		MaskUtil_applyMaskPenaltyRule4(matrix)
}

func Encoder_encodeWithoutHint(content string, ecLevel decoder.ErrorCorrectionLevel) (*QRCode, gozxing.WriterException) {
	return Encoder_encode(content, ecLevel, nil)
}

func Encoder_encode(content string, ecLevel decoder.ErrorCorrectionLevel, hints map[gozxing.EncodeHintType]interface{}) (*QRCode, gozxing.WriterException) {
	// Determine what character encoding has been specified by the caller, if any
	encoding := Encoder_DEFAULT_BYTE_MODE_ENCODING
	encodingHint, hasEncodingHint := hints[gozxing.EncodeHintType_CHARACTER_SET]
	if hasEncodingHint {
		if eci, ok := common.GetCharacterSetECIByName(fmt.Sprintf("%v", encodingHint)); ok {
			encoding = eci.GetCharset()
		} else {
			return nil, gozxing.NewWriterException(encodingHint)
		}
	}

	// Pick an encoding mode appropriate for the content. Note that this will not attempt to use
	// multiple modes / segments even if that were more efficient. Twould be nice.
	mode := chooseMode(content, encoding)

	// This will store the header information, like mode and
	// length, as well as "header" segments like an ECI segment.
	headerBits := gozxing.NewEmptyBitArray()

	// Append ECI segment if applicable
	if mode == decoder.Mode_BYTE && hasEncodingHint {
		eci, ok := common.GetCharacterSetECI(encoding)
		if ok && eci != nil {
			appendECI(eci, headerBits)
		}
	}

	// Append the FNC1 mode header for GS1 formatted data if applicable
	gs1FormatHint, hasGS1FormatHint := hints[gozxing.EncodeHintType_GS1_FORMAT]
	if hasGS1FormatHint {
		appendGS1, ok := gs1FormatHint.(bool)
		if !ok {
			s, ok := gs1FormatHint.(string)
			if ok {
				appendGS1, _ = strconv.ParseBool(s)
			}
		}
		if appendGS1 {
			// GS1 formatted codes are prefixed with a FNC1 in first position mode header
			appendModeInfo(decoder.Mode_FNC1_FIRST_POSITION, headerBits)
		}
	}

	// (With ECI in place,) Write the mode marker
	appendModeInfo(mode, headerBits)

	// Collect data within the main segment, separately, to count its size if needed. Don't add it to
	// main payload yet.
	dataBits := gozxing.NewEmptyBitArray()
	e := appendBytes(content, mode, dataBits, encoding)
	if e != nil {
		return nil, e
	}

	var version *decoder.Version
	if versionHint, ok := hints[gozxing.EncodeHintType_QR_VERSION]; ok {
		versionNumber, ok := versionHint.(int)
		if !ok {
			if s, ok := versionHint.(string); ok {
				versionNumber, _ = strconv.Atoi(s)
			}
		}
		var e error
		version, e = decoder.Version_GetVersionForNumber(versionNumber)
		if e != nil {
			return nil, gozxing.WrapWriterException(e)
		}
		bitsNeeded := calculateBitsNeeded(mode, headerBits, dataBits, version)
		if !willFit(bitsNeeded, version, ecLevel) {
			return nil, gozxing.NewWriterException("Data too big for requested version")
		}
	} else {
		version, e = recommendVersion(ecLevel, mode, headerBits, dataBits)
		if e != nil {
			return nil, e
		}
	}

	headerAndDataBits := gozxing.NewEmptyBitArray()
	headerAndDataBits.AppendBitArray(headerBits)
	// Find "length" of main segment and write it
	numLetters := len(content)
	if mode == decoder.Mode_BYTE {
		numLetters = dataBits.GetSizeInBytes()
	} else if mode == decoder.Mode_KANJI {
		numLetters = utf8.RuneCountInString(content)
	}

	e = appendLengthInfo(numLetters, version, mode, headerAndDataBits)
	if e != nil {
		return nil, e
	}
	// Put data together into the overall payload
	headerAndDataBits.AppendBitArray(dataBits)

	ecBlocks := version.GetECBlocksForLevel(ecLevel)
	numDataBytes := version.GetTotalCodewords() - ecBlocks.GetTotalECCodewords()

	// Terminate the bits properly.
	e = terminateBits(numDataBytes, headerAndDataBits)
	if e != nil {
		return nil, e
	}

	// Interleave data bits with error correction code.
	finalBits, e := interleaveWithECBytes(
		headerAndDataBits, version.GetTotalCodewords(), numDataBytes, ecBlocks.GetNumBlocks())
	if e != nil {
		return nil, e
	}

	qrCode := NewQRCode()

	qrCode.SetECLevel(ecLevel)
	qrCode.SetMode(mode)
	qrCode.SetVersion(version)

	//  Choose the mask pattern and set to "qrCode".
	dimension := version.GetDimensionForVersion()
	matrix := NewByteMatrix(dimension, dimension)

	// Enable manual selection of the pattern to be used via hint
	maskPattern := -1
	if hintMaskPattern, ok := hints[gozxing.EncodeHintType_QR_MASK_PATTERN]; ok {
		switch mask := hintMaskPattern.(type) {
		case int:
			maskPattern = mask
		case string:
			if m, e := strconv.Atoi(mask); e == nil {
				maskPattern = m
			}
		}
		if !QRCode_IsValidMaskPattern(maskPattern) {
			maskPattern = -1
		}
	}

	if maskPattern == -1 {
		maskPattern, e = chooseMaskPattern(finalBits, ecLevel, version, matrix)
		if e != nil {
			return nil, e
		}
	}
	qrCode.SetMaskPattern(maskPattern)

	// Build the matrix and set it to "qrCode".
	_ = MatrixUtil_buildMatrix(finalBits, ecLevel, version, maskPattern, matrix)
	qrCode.SetMatrix(matrix)

	return qrCode, nil
}

// recommendVersion  Decides the smallest version of QR code that will contain all of the provided data.
// @throws WriterException if the data cannot fit in any version
func recommendVersion(ecLevel decoder.ErrorCorrectionLevel, mode *decoder.Mode,
	headerBits *gozxing.BitArray, dataBits *gozxing.BitArray) (*decoder.Version, gozxing.WriterException) {
	// Hard part: need to know version to know how many bits length takes. But need to know how many
	// bits it takes to know version. First we take a guess at version by assuming version will be
	// the minimum, 1:
	version1, _ := decoder.Version_GetVersionForNumber(1)
	provisionalBitsNeeded := calculateBitsNeeded(mode, headerBits, dataBits, version1)
	provisionalVersion, e := chooseVersion(provisionalBitsNeeded, ecLevel)
	if e != nil {
		return nil, e
	}

	// Use that guess to calculate the right version. I am still not sure this works in 100% of cases.
	bitsNeeded := calculateBitsNeeded(mode, headerBits, dataBits, provisionalVersion)
	return chooseVersion(bitsNeeded, ecLevel)
}

func calculateBitsNeeded(
	mode *decoder.Mode,
	headerBits *gozxing.BitArray,
	dataBits *gozxing.BitArray,
	version *decoder.Version) int {
	return headerBits.GetSize() + mode.GetCharacterCountBits(version) + dataBits.GetSize()
}

// getAlphanumericCode returns the code point of the table used in alphanumeric mode or
// if there is no corresponding code in the table.
func getAlphanumericCode(code uint8) int {
	if int(code) < len(alphanumericTable) {
		return alphanumericTable[code]
	}
	return -1
}

// chooseMode Choose the best mode by examining the content. Note that 'encoding' is used as a hint;
// if it is Shift_JIS, and the input is only double-byte Kanji, then we return {@link Mode#KANJI}.
func chooseMode(content string, encoding textencoding.Encoding) *decoder.Mode {
	if common.StringUtils_SHIFT_JIS_CHARSET == encoding && isOnlyDoubleByteKanji(content) {
		// Choose Kanji mode if all input are double-byte characters
		return decoder.Mode_KANJI
	}
	hasNumeric := false
	hasAlphanumeric := false
	for i := 0; i < len(content); i++ {
		c := content[i]
		if c >= '0' && c <= '9' {
			hasNumeric = true
		} else if getAlphanumericCode(c) != -1 {
			hasAlphanumeric = true
		} else {
			return decoder.Mode_BYTE
		}
	}
	if hasAlphanumeric {
		return decoder.Mode_ALPHANUMERIC
	}
	if hasNumeric {
		return decoder.Mode_NUMERIC
	}
	return decoder.Mode_BYTE
}

func isOnlyDoubleByteKanji(content string) bool {
	enc := common.StringUtils_SHIFT_JIS_CHARSET.NewEncoder()
	bytes, e := enc.Bytes([]byte(content))
	if e != nil {
		return false
	}

	length := len(bytes)
	if length%2 != 0 {
		return false
	}
	for i := 0; i < length; i += 2 {
		byte1 := bytes[i] & 0xFF
		if (byte1 < 0x81 || byte1 > 0x9F) && (byte1 < 0xE0 || byte1 > 0xEB) {
			return false
		}
	}
	return true
}

func chooseMaskPattern(bits *gozxing.BitArray, ecLevel decoder.ErrorCorrectionLevel,
	version *decoder.Version, matrix *ByteMatrix) (int, gozxing.WriterException) {

	minPenalty := math.MaxInt32 // Lower penalty is better.
	bestMaskPattern := -1
	// We try all mask patterns to choose the best one.
	for maskPattern := 0; maskPattern < QRCode_NUM_MASK_PATERNS; maskPattern++ {
		e := MatrixUtil_buildMatrix(bits, ecLevel, version, maskPattern, matrix)
		if e != nil {
			return -1, gozxing.WrapWriterException(e)
		}
		penalty := calculateMaskPenalty(matrix)
		if penalty < minPenalty {
			minPenalty = penalty
			bestMaskPattern = maskPattern
		}
	}
	return bestMaskPattern, nil
}

func chooseVersion(numInputBits int, ecLevel decoder.ErrorCorrectionLevel) (*decoder.Version, gozxing.WriterException) {
	for versionNum := 1; versionNum <= 40; versionNum++ {
		version, _ := decoder.Version_GetVersionForNumber(versionNum)
		if willFit(numInputBits, version, ecLevel) {
			return version, nil
		}
	}
	return nil, gozxing.NewWriterException("Data too big")
}

// willFit returns true if the number of input bits will fit in a code with the specified version and
// error correction level.
func willFit(numInputBits int, version *decoder.Version, ecLevel decoder.ErrorCorrectionLevel) bool {
	// In the following comments, we use numbers of Version 7-H.
	// numBytes = 196
	numBytes := version.GetTotalCodewords()
	// getNumECBytes = 130
	ecBlocks := version.GetECBlocksForLevel(ecLevel)
	numEcBytes := ecBlocks.GetTotalECCodewords()
	// getNumDataBytes = 196 - 130 = 66
	numDataBytes := numBytes - numEcBytes
	totalInputBytes := (numInputBits + 7) / 8
	return numDataBytes >= totalInputBytes
}

// terminateBits Terminate bits as described in 8.4.8 and 8.4.9 of JISX0510:2004 (p.24).
func terminateBits(numDataBytes int, bits *gozxing.BitArray) gozxing.WriterException {
	capacity := numDataBytes * 8
	if bits.GetSize() > capacity {
		return gozxing.NewWriterException(
			"data bits cannot fit in the QR Code %v > %v", bits.GetSize(), capacity)
	}
	for i := 0; i < 4 && bits.GetSize() < capacity; i++ {
		bits.AppendBit(false)
	}
	// Append termination bits. See 8.4.8 of JISX0510:2004 (p.24) for details.
	// If the last byte isn't 8-bit aligned, we'll add padding bits.
	numBitsInLastByte := bits.GetSize() & 0x07
	if numBitsInLastByte > 0 {
		for i := numBitsInLastByte; i < 8; i++ {
			bits.AppendBit(false)
		}
	}
	// If we have more space, we'll fill the space with padding patterns defined in 8.4.9 (p.24).
	numPaddingBytes := numDataBytes - bits.GetSizeInBytes()
	for i := 0; i < numPaddingBytes; i++ {
		v := 0x11
		if (i & 0x1) == 0 {
			v = 0xEC
		}
		_ = bits.AppendBits(v, 8)
	}
	if bits.GetSize() != capacity {
		return gozxing.NewWriterException("bits.GetSize()=%d, capacity=&d", bits.GetSize(), capacity)
	}
	return nil
}

// getNumDataBytesAndNumECBytesForBlockID Get number of data bytes and number of
// error correction bytes for block id "blockID".
// Returns are "numDataBytesInBlock", and "numECBytesInBlock".
// See table 12 in 8.5.1 of JISX0510:2004 (p.30)
func getNumDataBytesAndNumECBytesForBlockID(numTotalBytes, numDataBytes, numRSBlocks, blockID int) (int, int, gozxing.WriterException) {
	if blockID >= numRSBlocks {
		return 0, 0, gozxing.NewWriterException("Block ID too large")
	}
	// numRsBlocksInGroup2 = 196 % 5 = 1
	numRsBlocksInGroup2 := numTotalBytes % numRSBlocks
	// numRsBlocksInGroup1 = 5 - 1 = 4
	numRsBlocksInGroup1 := numRSBlocks - numRsBlocksInGroup2
	// numTotalBytesInGroup1 = 196 / 5 = 39
	numTotalBytesInGroup1 := numTotalBytes / numRSBlocks
	// numTotalBytesInGroup2 = 39 + 1 = 40
	numTotalBytesInGroup2 := numTotalBytesInGroup1 + 1
	// numDataBytesInGroup1 = 66 / 5 = 13
	numDataBytesInGroup1 := numDataBytes / numRSBlocks
	// numDataBytesInGroup2 = 13 + 1 = 14
	numDataBytesInGroup2 := numDataBytesInGroup1 + 1
	// numEcBytesInGroup1 = 39 - 13 = 26
	numEcBytesInGroup1 := numTotalBytesInGroup1 - numDataBytesInGroup1
	// numEcBytesInGroup2 = 40 - 14 = 26
	numEcBytesInGroup2 := numTotalBytesInGroup2 - numDataBytesInGroup2
	// Sanity checks.
	// 26 = 26
	if numEcBytesInGroup1 != numEcBytesInGroup2 {
		return 0, 0, gozxing.NewWriterException("EC bytes mismatch")
	}
	// 5 = 4 + 1.
	if numRSBlocks != numRsBlocksInGroup1+numRsBlocksInGroup2 {
		return 0, 0, gozxing.NewWriterException("RS blocks mismatch")
	}
	// 196 = (13 + 26) * 4 + (14 + 26) * 1
	if numTotalBytes !=
		((numDataBytesInGroup1+numEcBytesInGroup1)*numRsBlocksInGroup1)+
			((numDataBytesInGroup2+numEcBytesInGroup2)*numRsBlocksInGroup2) {
		return 0, 0, gozxing.NewWriterException("Total bytes mismatch")
	}

	if blockID < numRsBlocksInGroup1 {
		return numDataBytesInGroup1, numEcBytesInGroup1, nil
	}
	return numDataBytesInGroup2, numEcBytesInGroup2, nil
}

// interleaveWithECBytes Interleave "bits" with corresponding error correction bytes.
// On success, store the result in "result".
// The interleave rule is complicated. See 8.6 of JISX0510:2004 (p.37) for details.
func interleaveWithECBytes(bits *gozxing.BitArray, numTotalBytes, numDataBytes, numRSBlocks int) (*gozxing.BitArray, gozxing.WriterException) {

	// "bits" must have "getNumDataBytes" bytes of data.
	if bits.GetSizeInBytes() != numDataBytes {
		return nil, gozxing.NewWriterException("Number of bits and data bytes does not match")
	}

	// Step 1.  Divide data bytes into blocks and generate error correction bytes for them. We'll
	// store the divided data bytes blocks and error correction bytes blocks into "blocks".
	dataBytesOffset := 0
	maxNumDataBytes := 0
	maxNumEcBytes := 0

	// Since, we know the number of reedsolmon blocks, we can initialize the vector with the number.
	blocks := make([]*BlockPair, 0)

	for i := 0; i < numRSBlocks; i++ {
		numDataBytesInBlock, numEcBytesInBlock, e := getNumDataBytesAndNumECBytesForBlockID(
			numTotalBytes, numDataBytes, numRSBlocks, i)
		if e != nil {
			return nil, e
		}

		size := numDataBytesInBlock
		dataBytes := make([]byte, size)
		bits.ToBytes(8*dataBytesOffset, dataBytes, 0, size)
		ecBytes, e := generateECBytes(dataBytes, numEcBytesInBlock)
		if e != nil {
			return nil, e
		}
		blocks = append(blocks, NewBlockPair(dataBytes, ecBytes))

		if maxNumDataBytes < size {
			maxNumDataBytes = size
		}
		if maxNumEcBytes < len(ecBytes) {
			maxNumEcBytes = len(ecBytes)
		}
		dataBytesOffset += numDataBytesInBlock
	}
	if numDataBytes != dataBytesOffset {
		return nil, gozxing.NewWriterException("Data bytes does not match offset")
	}

	result := gozxing.NewEmptyBitArray()

	// First, place data blocks.
	for i := 0; i < maxNumDataBytes; i++ {
		for _, block := range blocks {
			dataBytes := block.GetDataBytes()
			if i < len(dataBytes) {
				_ = result.AppendBits(int(dataBytes[i]), 8)
			}
		}
	}
	// Then, place error correction blocks.
	for i := 0; i < maxNumEcBytes; i++ {
		for _, block := range blocks {
			ecBytes := block.GetErrorCorrectionBytes()
			if i < len(ecBytes) {
				_ = result.AppendBits(int(ecBytes[i]), 8)
			}
		}
	}
	if numTotalBytes != result.GetSizeInBytes() { // Should be same.
		return nil, gozxing.NewWriterException(
			"Interleaving error: %v  and %v differ", numTotalBytes, result.GetSizeInBytes())
	}

	return result, nil
}

func generateECBytes(dataBytes []byte, numEcBytesInBlock int) ([]byte, gozxing.WriterException) {
	numDataBytes := len(dataBytes)
	toEncode := make([]int, numDataBytes+numEcBytesInBlock)
	for i := 0; i < numDataBytes; i++ {
		toEncode[i] = int(dataBytes[i]) & 0xFF
	}
	e := reedsolomon.NewReedSolomonEncoder(reedsolomon.GenericGF_QR_CODE_FIELD_256).Encode(toEncode, numEcBytesInBlock)
	if e != nil {
		return nil, gozxing.WrapWriterException(e)
	}

	ecBytes := make([]byte, numEcBytesInBlock)
	for i := 0; i < numEcBytesInBlock; i++ {
		ecBytes[i] = byte(toEncode[numDataBytes+i])
	}
	return ecBytes, nil
}

// appendModeInfo Append mode info. On success, store the result in "bits".
func appendModeInfo(mode *decoder.Mode, bits *gozxing.BitArray) {
	_ = bits.AppendBits(mode.GetBits(), 4)
}

// appendLengthInfo Append length info. On success, store the result in "bits".
func appendLengthInfo(numLetters int, version *decoder.Version, mode *decoder.Mode, bits *gozxing.BitArray) gozxing.WriterException {
	numBits := mode.GetCharacterCountBits(version)
	if numLetters >= (1 << uint(numBits)) {
		return gozxing.NewWriterException(
			"%v is bigger than %v", numLetters, (1 << uint(numBits)))
	}
	_ = bits.AppendBits(numLetters, numBits)
	return nil
}

// appendBytes Append "bytes" in "mode" mode (encoding) into "bits".
//  On success, store the result in "bits".
func appendBytes(content string, mode *decoder.Mode, bits *gozxing.BitArray, encoding textencoding.Encoding) gozxing.WriterException {
	switch mode {
	case decoder.Mode_NUMERIC:
		appendNumericBytes(content, bits)
		return nil
	case decoder.Mode_ALPHANUMERIC:
		return appendAlphanumericBytes(content, bits)
	case decoder.Mode_BYTE:
		return append8BitBytes(content, bits, encoding)
	case decoder.Mode_KANJI:
		return appendKanjiBytes(content, bits)
	default:
		return gozxing.NewWriterException("Invalid mode: %v", mode)
	}
}

func appendNumericBytes(content string, bits *gozxing.BitArray) {
	length := len(content)
	i := 0
	for i < length {
		num1 := int(content[i]) - '0'
		if i+2 < length {
			// Encode three numeric letters in ten bits.
			num2 := int(content[i+1]) - '0'
			num3 := int(content[i+2]) - '0'
			_ = bits.AppendBits(num1*100+num2*10+num3, 10)
			i += 3
		} else if i+1 < length {
			// Encode two numeric letters in seven bits.
			num2 := int(content[i+1]) - '0'
			_ = bits.AppendBits(num1*10+num2, 7)
			i += 2
		} else {
			// Encode one numeric letter in four bits.
			_ = bits.AppendBits(num1, 4)
			i++
		}
	}
}

func appendAlphanumericBytes(content string, bits *gozxing.BitArray) gozxing.WriterException {
	length := len(content)
	i := 0
	for i < length {
		code1 := getAlphanumericCode(content[i])
		if code1 == -1 {
			return gozxing.NewWriterException("appendAlphanumericBytes")
		}
		if i+1 < length {
			code2 := getAlphanumericCode(content[i+1])
			if code2 == -1 {
				return gozxing.NewWriterException("appendAlphanumericBytes")
			}
			// Encode two alphanumeric letters in 11 bits.
			_ = bits.AppendBits(code1*45+code2, 11)
			i += 2
		} else {
			// Encode one alphanumeric letter in six bits.
			_ = bits.AppendBits(code1, 6)
			i++
		}
	}
	return nil
}

func append8BitBytes(content string, bits *gozxing.BitArray, encoding textencoding.Encoding) gozxing.WriterException {
	bytes := []byte(content)

	var e error
	bytes, e = encoding.NewEncoder().Bytes([]byte(content))
	if e != nil {
		return gozxing.WrapWriterException(e)
	}

	for _, b := range bytes {
		_ = bits.AppendBits(int(b), 8)
	}
	return nil
}

func appendKanjiBytes(content string, bits *gozxing.BitArray) gozxing.WriterException {
	enc := common.StringUtils_SHIFT_JIS_CHARSET.NewEncoder()
	bytes, e := enc.Bytes([]byte(content))
	if e != nil {
		return gozxing.WrapWriterException(e)
	}
	if len(bytes)%2 != 0 {
		return gozxing.NewWriterException("Kanji byte size not even")
	}
	maxI := len(bytes) - 1 // bytes.length must be even
	for i := 0; i < maxI; i += 2 {
		byte1 := int(bytes[i]) & 0xFF
		byte2 := int(bytes[i+1]) & 0xFF
		code := (byte1 << 8) | byte2
		subtracted := -1
		if code >= 0x8140 && code <= 0x9ffc {
			subtracted = code - 0x8140
		} else if code >= 0xe040 && code <= 0xebbf {
			subtracted = code - 0xc140
		}
		if subtracted == -1 {
			return gozxing.NewWriterException("Invalid byte sequence")
		}
		encoded := ((subtracted >> 8) * 0xc0) + (subtracted & 0xff)
		_ = bits.AppendBits(encoded, 13)
	}
	return nil
}

func appendECI(eci *common.CharacterSetECI, bits *gozxing.BitArray) {
	_ = bits.AppendBits(decoder.Mode_ECI.GetBits(), 4)
	// This is correct for values up to 127, which is all we need now.
	_ = bits.AppendBits(eci.GetValue(), 8)
}
