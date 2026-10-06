package oned

// Decodes Code 128 barcodes.

import (
	"strconv"

	"github.com/makiuchi-d/gozxing"
)

var code128CODE_PATTERNS = [][]int{
	{2, 1, 2, 2, 2, 2}, // 0
	{2, 2, 2, 1, 2, 2},
	{2, 2, 2, 2, 2, 1},
	{1, 2, 1, 2, 2, 3},
	{1, 2, 1, 3, 2, 2},
	{1, 3, 1, 2, 2, 2}, // 5
	{1, 2, 2, 2, 1, 3},
	{1, 2, 2, 3, 1, 2},
	{1, 3, 2, 2, 1, 2},
	{2, 2, 1, 2, 1, 3},
	{2, 2, 1, 3, 1, 2}, // 10
	{2, 3, 1, 2, 1, 2},
	{1, 1, 2, 2, 3, 2},
	{1, 2, 2, 1, 3, 2},
	{1, 2, 2, 2, 3, 1},
	{1, 1, 3, 2, 2, 2}, // 15
	{1, 2, 3, 1, 2, 2},
	{1, 2, 3, 2, 2, 1},
	{2, 2, 3, 2, 1, 1},
	{2, 2, 1, 1, 3, 2},
	{2, 2, 1, 2, 3, 1}, // 20
	{2, 1, 3, 2, 1, 2},
	{2, 2, 3, 1, 1, 2},
	{3, 1, 2, 1, 3, 1},
	{3, 1, 1, 2, 2, 2},
	{3, 2, 1, 1, 2, 2}, // 25
	{3, 2, 1, 2, 2, 1},
	{3, 1, 2, 2, 1, 2},
	{3, 2, 2, 1, 1, 2},
	{3, 2, 2, 2, 1, 1},
	{2, 1, 2, 1, 2, 3}, // 30
	{2, 1, 2, 3, 2, 1},
	{2, 3, 2, 1, 2, 1},
	{1, 1, 1, 3, 2, 3},
	{1, 3, 1, 1, 2, 3},
	{1, 3, 1, 3, 2, 1}, // 35
	{1, 1, 2, 3, 1, 3},
	{1, 3, 2, 1, 1, 3},
	{1, 3, 2, 3, 1, 1},
	{2, 1, 1, 3, 1, 3},
	{2, 3, 1, 1, 1, 3}, // 40
	{2, 3, 1, 3, 1, 1},
	{1, 1, 2, 1, 3, 3},
	{1, 1, 2, 3, 3, 1},
	{1, 3, 2, 1, 3, 1},
	{1, 1, 3, 1, 2, 3}, // 45
	{1, 1, 3, 3, 2, 1},
	{1, 3, 3, 1, 2, 1},
	{3, 1, 3, 1, 2, 1},
	{2, 1, 1, 3, 3, 1},
	{2, 3, 1, 1, 3, 1}, // 50
	{2, 1, 3, 1, 1, 3},
	{2, 1, 3, 3, 1, 1},
	{2, 1, 3, 1, 3, 1},
	{3, 1, 1, 1, 2, 3},
	{3, 1, 1, 3, 2, 1}, // 55
	{3, 3, 1, 1, 2, 1},
	{3, 1, 2, 1, 1, 3},
	{3, 1, 2, 3, 1, 1},
	{3, 3, 2, 1, 1, 1},
	{3, 1, 4, 1, 1, 1}, // 60
	{2, 2, 1, 4, 1, 1},
	{4, 3, 1, 1, 1, 1},
	{1, 1, 1, 2, 2, 4},
	{1, 1, 1, 4, 2, 2},
	{1, 2, 1, 1, 2, 4}, // 65
	{1, 2, 1, 4, 2, 1},
	{1, 4, 1, 1, 2, 2},
	{1, 4, 1, 2, 2, 1},
	{1, 1, 2, 2, 1, 4},
	{1, 1, 2, 4, 1, 2}, // 70
	{1, 2, 2, 1, 1, 4},
	{1, 2, 2, 4, 1, 1},
	{1, 4, 2, 1, 1, 2},
	{1, 4, 2, 2, 1, 1},
	{2, 4, 1, 2, 1, 1}, // 75
	{2, 2, 1, 1, 1, 4},
	{4, 1, 3, 1, 1, 1},
	{2, 4, 1, 1, 1, 2},
	{1, 3, 4, 1, 1, 1},
	{1, 1, 1, 2, 4, 2}, // 80
	{1, 2, 1, 1, 4, 2},
	{1, 2, 1, 2, 4, 1},
	{1, 1, 4, 2, 1, 2},
	{1, 2, 4, 1, 1, 2},
	{1, 2, 4, 2, 1, 1}, // 85
	{4, 1, 1, 2, 1, 2},
	{4, 2, 1, 1, 1, 2},
	{4, 2, 1, 2, 1, 1},
	{2, 1, 2, 1, 4, 1},
	{2, 1, 4, 1, 2, 1}, // 90
	{4, 1, 2, 1, 2, 1},
	{1, 1, 1, 1, 4, 3},
	{1, 1, 1, 3, 4, 1},
	{1, 3, 1, 1, 4, 1},
	{1, 1, 4, 1, 1, 3}, // 95
	{1, 1, 4, 3, 1, 1},
	{4, 1, 1, 1, 1, 3},
	{4, 1, 1, 3, 1, 1},
	{1, 1, 3, 1, 4, 1},
	{1, 1, 4, 1, 3, 1}, // 100
	{3, 1, 1, 1, 4, 1},
	{4, 1, 1, 1, 3, 1},
	{2, 1, 1, 4, 1, 2},
	{2, 1, 1, 2, 1, 4},
	{2, 1, 1, 2, 3, 2}, // 105
	{2, 3, 3, 1, 1, 1, 2},
}

const (
	code128MAX_AVG_VARIANCE        = 0.25
	code128MAX_INDIVIDUAL_VARIANCE = 0.7

	code128CODE_SHIFT = 98

	code128CODE_CODE_C = 99
	code128CODE_CODE_B = 100
	code128CODE_CODE_A = 101

	code128CODE_FNC_1   = 102
	code128CODE_FNC_2   = 97
	code128CODE_FNC_3   = 96
	code128CODE_FNC_4_A = 101
	code128CODE_FNC_4_B = 100

	code128CODE_START_A = 103
	code128CODE_START_B = 104
	code128CODE_START_C = 105
	code128CODE_STOP    = 106
)

type code128Reader struct {
	*OneDReader
}

func NewCode128Reader() gozxing.Reader {
	this := &code128Reader{}
	this.OneDReader = NewOneDReader(this)
	return this
}

func code128FindStartPattern(row *gozxing.BitArray) ([]int, error) {
	width := row.GetSize()
	rowOffset := row.GetNextSet(0)

	counterPosition := 0
	counters := make([]int, 6)
	patternStart := rowOffset
	isWhite := false
	patternLength := len(counters)

	for i := rowOffset; i < width; i++ {
		if row.Get(i) != isWhite {
			counters[counterPosition]++
		} else {
			if counterPosition == patternLength-1 {
				bestVariance := float64(code128MAX_AVG_VARIANCE)
				bestMatch := -1
				for startCode := code128CODE_START_A; startCode <= code128CODE_START_C; startCode++ {
					variance := PatternMatchVariance(counters, code128CODE_PATTERNS[startCode],
						code128MAX_INDIVIDUAL_VARIANCE)
					if variance < bestVariance {
						bestVariance = variance
						bestMatch = startCode
					}
				}
				// Look for whitespace before start pattern, >= 50% of width of start pattern
				if bestMatch >= 0 {
					if b, _ := row.IsRange(max(0, patternStart-(i-patternStart)/2), patternStart, false); b {
						return []int{patternStart, i, bestMatch}, nil
					}
				}
				patternStart += counters[0] + counters[1]
				copy(counters, counters[2:2+counterPosition-1])
				counters[counterPosition-1] = 0
				counters[counterPosition] = 0
				counterPosition--
			} else {
				counterPosition++
			}
			counters[counterPosition] = 1
			isWhite = !isWhite
		}
	}
	return nil, gozxing.NewNotFoundException()
}

func code128DecodeCode(row *gozxing.BitArray, counters []int, rowOffset int) (int, error) {
	e := RecordPattern(row, rowOffset, counters)
	if e != nil {
		return 0, gozxing.WrapNotFoundException(e)
	}
	bestVariance := float64(code128MAX_AVG_VARIANCE) // worst variance we'll accept
	bestMatch := -1
	for d := 0; d < len(code128CODE_PATTERNS); d++ {
		pattern := code128CODE_PATTERNS[d]
		variance := PatternMatchVariance(counters, pattern, code128MAX_INDIVIDUAL_VARIANCE)
		if variance < bestVariance {
			bestVariance = variance
			bestMatch = d
		}
	}
	// TODO We're overlooking the fact that the STOP pattern has 7 values, not 6.
	if bestMatch >= 0 {
		return bestMatch, nil
	} else {
		return 0, gozxing.NewNotFoundException()
	}
}

func (*code128Reader) DecodeRow(rowNumber int, row *gozxing.BitArray, hints map[gozxing.DecodeHintType]interface{}) (*gozxing.Result, error) {

	_, convertFNC1 := hints[gozxing.DecodeHintType_ASSUME_GS1]

	symbologyModifier := 0

	startPatternInfo, e := code128FindStartPattern(row)
	if e != nil {
		return nil, e
	}
	startCode := startPatternInfo[2]

	rawCodes := make([]byte, 0, 20)
	rawCodes = append(rawCodes, byte(startCode))

	var codeSet int
	switch startCode {
	case code128CODE_START_A:
		codeSet = code128CODE_CODE_A
		break
	case code128CODE_START_B:
		codeSet = code128CODE_CODE_B
		break
	case code128CODE_START_C:
		codeSet = code128CODE_CODE_C
		break
	default:
		return nil, gozxing.NewFormatException("startCode = %d", startCode)
	}

	done := false
	isNextShifted := false

	result := make([]byte, 0, 20)

	lastStart := startPatternInfo[0]
	nextStart := startPatternInfo[1]
	counters := make([]int, 6)

	lastCode := 0
	code := 0
	checksumTotal := startCode
	multiplier := 0
	lastCharacterWasPrintable := true
	upperMode := false
	shiftUpperMode := false

	for !done {

		unshift := isNextShifted
		isNextShifted = false

		// Save off last code
		lastCode = code

		// Decode another code from image
		code, e = code128DecodeCode(row, counters, nextStart)
		if e != nil {
			return nil, e
		}

		rawCodes = append(rawCodes, byte(code))

		// Remember whether the last code was printable or not (excluding CODE_STOP)
		if code != code128CODE_STOP {
			lastCharacterWasPrintable = true
		}

		// Add to checksum computation (if not CODE_STOP of course)
		if code != code128CODE_STOP {
			multiplier++
			checksumTotal += multiplier * code
		}

		// Advance to where the next code will to start
		lastStart = nextStart
		for _, counter := range counters {
			nextStart += counter
		}

		// Take care of illegal start codes
		switch code {
		case code128CODE_START_A, code128CODE_START_B, code128CODE_START_C:
			return nil, gozxing.NewFormatException("code = %d", code)
		}

		switch codeSet {

		case code128CODE_CODE_A:
			if code < 64 {
				if shiftUpperMode == upperMode {
					result = append(result, byte(' '+code))
				} else {
					result = append(result, byte(' '+code+128))
				}
				shiftUpperMode = false
			} else if code < 96 {
				if shiftUpperMode == upperMode {
					result = append(result, byte(code-64))
				} else {
					result = append(result, byte(code+64))
				}
				shiftUpperMode = false
			} else {
				// Don't let CODE_STOP, which always appears, affect whether whether we think the last
				// code was printable or not.
				if code != code128CODE_STOP {
					lastCharacterWasPrintable = false
				}
				switch code {
				case code128CODE_FNC_1:
					if len(result) == 0 { // FNC1 at first or second character determines the symbology
						symbologyModifier = 1
					} else if len(result) == 1 {
						symbologyModifier = 2
					}
					if convertFNC1 {
						if len(result) == 0 {
							// GS1 specification 5.4.3.7. and 5.4.6.4. If the first char after the start code
							// is FNC1 then this is GS1-128. We add the symbology identifier.
							result = append(result, []byte("]C1")...)
						} else {
							// GS1 specification 5.4.7.5. Every subsequent FNC1 is returned as ASCII 29 (GS)
							result = append(result, 29)
						}
					}
					break
				case code128CODE_FNC_2:
					symbologyModifier = 4
					break
				case code128CODE_FNC_3:
					// do nothing?
					break
				case code128CODE_FNC_4_A:
					if !upperMode && shiftUpperMode {
						upperMode = true
						shiftUpperMode = false
					} else if upperMode && shiftUpperMode {
						upperMode = false
						shiftUpperMode = false
					} else {
						shiftUpperMode = true
					}
					break
				case code128CODE_SHIFT:
					isNextShifted = true
					codeSet = code128CODE_CODE_B
					break
				case code128CODE_CODE_B:
					codeSet = code128CODE_CODE_B
					break
				case code128CODE_CODE_C:
					codeSet = code128CODE_CODE_C
					break
				case code128CODE_STOP:
					done = true
					break
				}
			}
			break
		case code128CODE_CODE_B:
			if code < 96 {
				if shiftUpperMode == upperMode {
					result = append(result, byte(' '+code))
				} else {
					result = append(result, byte(' '+code+128))
				}
				shiftUpperMode = false
			} else {
				if code != code128CODE_STOP {
					lastCharacterWasPrintable = false
				}
				switch code {
				case code128CODE_FNC_1:
					if len(result) == 0 { // FNC1 at first or second character determines the symbology
						symbologyModifier = 1
					} else if len(result) == 1 {
						symbologyModifier = 2
					}
					if convertFNC1 {
						if len(result) == 0 {
							// GS1 specification 5.4.3.7. and 5.4.6.4. If the first char after the start code
							// is FNC1 then this is GS1-128. We add the symbology identifier.
							result = append(result, []byte("]C1")...)
						} else {
							// GS1 specification 5.4.7.5. Every subsequent FNC1 is returned as ASCII 29 (GS)
							result = append(result, 29)
						}
					}
					break
				case code128CODE_FNC_2:
					symbologyModifier = 4
					break
				case code128CODE_FNC_3:
					// do nothing?
					break
				case code128CODE_FNC_4_B:
					if !upperMode && shiftUpperMode {
						upperMode = true
						shiftUpperMode = false
					} else if upperMode && shiftUpperMode {
						upperMode = false
						shiftUpperMode = false
					} else {
						shiftUpperMode = true
					}
					break
				case code128CODE_SHIFT:
					isNextShifted = true
					codeSet = code128CODE_CODE_A
					break
				case code128CODE_CODE_A:
					codeSet = code128CODE_CODE_A
					break
				case code128CODE_CODE_C:
					codeSet = code128CODE_CODE_C
					break
				case code128CODE_STOP:
					done = true
					break
				}
			}
			break
		case code128CODE_CODE_C:
			if code < 100 {
				result = append(result, '0'+byte(code/10))
				result = append(result, '0'+byte(code%10))
			} else {
				if code != code128CODE_STOP {
					lastCharacterWasPrintable = false
				}
				switch code {
				case code128CODE_FNC_1:
					if len(result) == 0 { // FNC1 at first or second character determines the symbology
						symbologyModifier = 1
					} else if len(result) == 1 {
						symbologyModifier = 2
					}
					if convertFNC1 {
						if len(result) == 0 {
							// GS1 specification 5.4.3.7. and 5.4.6.4. If the first char after the start code
							// is FNC1 then this is GS1-128. We add the symbology identifier.
							result = append(result, []byte("]C1")...)
						} else {
							// GS1 specification 5.4.7.5. Every subsequent FNC1 is returned as ASCII 29 (GS)
							result = append(result, 29)
						}
					}
					break
				case code128CODE_CODE_A:
					codeSet = code128CODE_CODE_A
					break
				case code128CODE_CODE_B:
					codeSet = code128CODE_CODE_B
					break
				case code128CODE_STOP:
					done = true
					break
				}
			}
			break
		}

		// Unshift back to another code set if we were shifted
		if unshift {
			if codeSet == code128CODE_CODE_A {
				codeSet = code128CODE_CODE_B
			} else {
				codeSet = code128CODE_CODE_A
			}
		}

	}

	lastPatternSize := nextStart - lastStart

	// Check for ample whitespace following pattern, but, to do this we first need to remember that
	// we fudged decoding CODE_STOP since it actually has 7 bars, not 6. There is a black bar left
	// to read off. Would be slightly better to properly read. Here we just skip it:
	nextStart = row.GetNextUnset(nextStart)
	if b, _ := row.IsRange(nextStart,
		min(row.GetSize(), nextStart+(nextStart-lastStart)/2),
		false); !b {
		return nil, gozxing.NewNotFoundException()
	}

	// Pull out from sum the value of the penultimate check code
	checksumTotal -= multiplier * lastCode
	// lastCode is the checksum then:
	if checksumTotal%103 != lastCode {
		return nil, gozxing.NewChecksumException("checksumTotal=%d, lastCode=%d", checksumTotal, lastCode)
	}

	// Need to pull out the check digits from string
	resultLength := len(result)
	if resultLength == 0 {
		// false positive
		return nil, gozxing.NewNotFoundException("resultLength = %d", resultLength)
	}

	// Only bother if the result had at least one character, and if the checksum digit happened to
	// be a printable character. If it was just interpreted as a control code, nothing to remove.
	if resultLength > 0 && lastCharacterWasPrintable {
		if codeSet == code128CODE_CODE_C {
			result = result[:resultLength-2]
		} else {
			result = result[:resultLength-1]
		}
	}

	left := float64(startPatternInfo[1]+startPatternInfo[0]) / 2.0
	right := float64(lastStart) + float64(lastPatternSize)/2.0

	rawCodesSize := len(rawCodes)
	rawBytes := make([]byte, rawCodesSize)
	for i := 0; i < rawCodesSize; i++ {
		rawBytes[i] = rawCodes[i]
	}

	rowNumberf := float64(rowNumber)
	resultObject := gozxing.NewResult(
		string(result),
		rawBytes,
		[]gozxing.ResultPoint{
			gozxing.NewResultPoint(left, rowNumberf),
			gozxing.NewResultPoint(right, rowNumberf)},
		gozxing.BarcodeFormat_CODE_128)
	resultObject.PutMetadata(gozxing.ResultMetadataType_SYMBOLOGY_IDENTIFIER, "]C"+strconv.Itoa(symbologyModifier))
	return resultObject, nil
}
