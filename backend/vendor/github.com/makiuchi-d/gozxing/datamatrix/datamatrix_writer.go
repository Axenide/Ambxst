package datamatrix

import (
	"github.com/makiuchi-d/gozxing"
	"github.com/makiuchi-d/gozxing/datamatrix/encoder"
	qrencoder "github.com/makiuchi-d/gozxing/qrcode/encoder"
)

// DataMatrixWriter This object renders a Data Matrix code as a BitMatrix 2D array of greyscale values.
type DataMatrixWriter struct{}

func NewDataMatrixWriter() gozxing.Writer {
	return &DataMatrixWriter{}
}

func (this *DataMatrixWriter) EncodeWithoutHint(
	contents string, format gozxing.BarcodeFormat, width, height int) (*gozxing.BitMatrix, error) {
	return this.Encode(contents, format, width, height, nil)
}

func (this *DataMatrixWriter) Encode(contents string, format gozxing.BarcodeFormat,
	width, height int, hints map[gozxing.EncodeHintType]interface{}) (*gozxing.BitMatrix, error) {

	if contents == "" {
		return nil, gozxing.NewWriterException("IllegalArgumentException: Found empty contents")
	}

	if format != gozxing.BarcodeFormat_DATA_MATRIX {
		return nil, gozxing.NewWriterException(
			"IllegalArgumentException: Can only encode DATA_MATRIX, but got %v", format)
	}

	if width < 0 || height < 0 {
		return nil, gozxing.NewWriterException(
			"IllegalArgumentException: Requested dimensions can't be negative: %vx%v", width, height)
	}

	// Try to get force shape & min / max size
	shape := encoder.SymbolShapeHint_FORCE_NONE
	var minSize *gozxing.Dimension
	var maxSize *gozxing.Dimension
	if hints != nil {
		if val, ok := hints[gozxing.EncodeHintType_DATA_MATRIX_SHAPE]; ok {
			if requestedShape, ok := val.(encoder.SymbolShapeHint); ok {
				shape = requestedShape
			}
		}
		if val, ok := hints[gozxing.EncodeHintType_MIN_SIZE]; ok {
			if requestedMinSize, ok := val.(*gozxing.Dimension); ok {
				minSize = requestedMinSize
			}
		}
		if val, ok := hints[gozxing.EncodeHintType_MAX_SIZE]; ok {
			if requestedMaxSize, ok := val.(*gozxing.Dimension); ok {
				maxSize = requestedMaxSize
			}
		}
	}

	//1. step: Data encodation
	encoded, e := encoder.EncodeHighLevel(contents, shape, minSize, maxSize)
	if e != nil {
		return nil, e
	}

	symbolInfo, _ := encoder.SymbolInfo_Lookup(len(encoded), shape, minSize, maxSize, true)

	//2. step: ECC generation
	codewords, _ := encoder.ErrorCorrection_EncodeECC200(encoded, symbolInfo)

	//3. step: Module placement in Matrix
	placement := encoder.NewDefaultPlacement(codewords,
		symbolInfo.GetSymbolDataWidth(), symbolInfo.GetSymbolDataHeight())
	placement.Place()

	//4. step: low-level encoding
	return encodeLowLevel(placement, symbolInfo, width, height), nil
}

// encodeLowLevel Encode the given symbol info to a bit matrix.
//
// @param placement  The DataMatrix placement.
// @param symbolInfo The symbol info to encode.
// @return The bit matrix generated.
//
func encodeLowLevel(placement *encoder.DefaultPlacement,
	symbolInfo *encoder.SymbolInfo, width, height int) *gozxing.BitMatrix {

	symbolWidth := symbolInfo.GetSymbolDataWidth()
	symbolHeight := symbolInfo.GetSymbolDataHeight()

	matrix := qrencoder.NewByteMatrix(symbolInfo.GetSymbolWidth(), symbolInfo.GetSymbolHeight())

	matrixY := 0

	for y := 0; y < symbolHeight; y++ {
		// Fill the top edge with alternate 0 / 1
		var matrixX int
		if (y % symbolInfo.GetMatrixHeight()) == 0 {
			matrixX = 0
			for x := 0; x < symbolInfo.GetSymbolWidth(); x++ {
				matrix.SetBool(matrixX, matrixY, (x%2) == 0)
				matrixX++
			}
			matrixY++
		}
		matrixX = 0
		for x := 0; x < symbolWidth; x++ {
			// Fill the right edge with full 1
			if (x % symbolInfo.GetMatrixWidth()) == 0 {
				matrix.SetBool(matrixX, matrixY, true)
				matrixX++
			}
			matrix.SetBool(matrixX, matrixY, placement.GetBit(x, y))
			matrixX++
			// Fill the right edge with alternate 0 / 1
			if (x % symbolInfo.GetMatrixWidth()) == symbolInfo.GetMatrixWidth()-1 {
				matrix.SetBool(matrixX, matrixY, (y%2) == 0)
				matrixX++
			}
		}
		matrixY++
		// Fill the bottom edge with full 1
		if (y % symbolInfo.GetMatrixHeight()) == symbolInfo.GetMatrixHeight()-1 {
			matrixX = 0
			for x := 0; x < symbolInfo.GetSymbolWidth(); x++ {
				matrix.SetBool(matrixX, matrixY, true)
				matrixX++
			}
			matrixY++
		}
	}

	return convertByteMatrixToBitMatrix(matrix, width, height)
}

// convertByteMatrixToBitMatrix Convert the ByteMatrix to BitMatrix.
//
// @param reqHeight The requested height of the image (in pixels) with the Datamatrix code
// @param reqWidth The requested width of the image (in pixels) with the Datamatrix code
// @param matrix The input matrix.
// @return The output matrix.
//
func convertByteMatrixToBitMatrix(matrix *qrencoder.ByteMatrix, reqWidth, reqHeight int) *gozxing.BitMatrix {
	matrixWidth := matrix.GetWidth()
	matrixHeight := matrix.GetHeight()
	outputWidth := reqWidth
	if outputWidth < matrixWidth {
		outputWidth = matrixWidth
	}
	outputHeight := reqHeight
	if outputHeight < matrixHeight {
		outputHeight = matrixHeight
	}

	multiple := outputWidth / matrixWidth
	if mh := outputHeight / matrixHeight; mh < multiple {
		multiple = mh
	}

	leftPadding := (outputWidth - (matrixWidth * multiple)) / 2
	topPadding := (outputHeight - (matrixHeight * multiple)) / 2

	var output *gozxing.BitMatrix

	// remove padding if requested width and height are too small
	if reqHeight < matrixHeight || reqWidth < matrixWidth {
		leftPadding = 0
		topPadding = 0
		output, _ = gozxing.NewBitMatrix(matrixWidth, matrixHeight)
	} else {
		output, _ = gozxing.NewBitMatrix(reqWidth, reqHeight)
	}

	output.Clear()
	for inputY, outputY := 0, topPadding; inputY < matrixHeight; inputY, outputY = inputY+1, outputY+multiple {
		// Write the contents of this row of the bytematrix
		for inputX, outputX := 0, leftPadding; inputX < matrixWidth; inputX, outputX = inputX+1, outputX+multiple {
			if matrix.Get(inputX, inputY) == 1 {
				output.SetRegion(outputX, outputY, multiple, multiple)
			}
		}
	}

	return output
}
