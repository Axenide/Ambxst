package oned

import (
	"github.com/makiuchi-d/gozxing"
)

// A reader that can read all available UPC/EAN formats. If a caller wants to try to
// read all such formats, it is most efficient to use this implementation rather than invoke
// individual readers.

type upceanDecoder interface {
	decodeRowWithStartRange(
		rowNumber int, row *gozxing.BitArray, startGuardRange []int,
		hints map[gozxing.DecodeHintType]interface{}) (*gozxing.Result, error)
}

type multiFormatUPCEANReader struct {
	*OneDReader
	readers []upceanDecoder
}

func NewMultiFormatUPCEANReader(hints map[gozxing.DecodeHintType]interface{}) gozxing.Reader {
	// @SuppressWarnings("unchecked")
	possibleFormats, _ := hints[gozxing.DecodeHintType_POSSIBLE_FORMATS].([]gozxing.BarcodeFormat)
	var readers []upceanDecoder
	for _, format := range possibleFormats {
		if format == gozxing.BarcodeFormat_EAN_13 {
			readers = append(readers, NewEAN13Reader().(*ean13Reader))
		} else if format == gozxing.BarcodeFormat_UPC_A {
			readers = append(readers, NewUPCAReader().(*upcAReader))
		} else if format == gozxing.BarcodeFormat_EAN_8 {
			readers = append(readers, NewEAN8Reader().(*ean8Reader))
		} else if format == gozxing.BarcodeFormat_UPC_E {
			readers = append(readers, NewUPCEReader().(*upcEReader))
		}
	}

	if len(readers) == 0 {
		readers = []upceanDecoder{
			NewEAN13Reader().(*ean13Reader),
			// UPC-A is covered by EAN-13
			NewEAN8Reader().(*ean8Reader),
			NewUPCEReader().(*upcEReader),
		}
	}

	this := &multiFormatUPCEANReader{
		readers: readers,
	}
	this.OneDReader = NewOneDReader(this)
	return this
}

func (this *multiFormatUPCEANReader) DecodeRow(rowNumber int, row *gozxing.BitArray, hints map[gozxing.DecodeHintType]interface{}) (*gozxing.Result, error) {
	// Compute this location once and reuse it on multiple implementations
	startGuardPattern, e := upceanReader_findStartGuardPattern(row)
	if e != nil {
		return nil, gozxing.WrapNotFoundException(e)
	}

	for _, reader := range this.readers {
		var e error
		result, e := reader.decodeRowWithStartRange(rowNumber, row, startGuardPattern, hints)
		if e != nil {
			if _, ok := e.(gozxing.ReaderException); ok {
				continue
			}
			return nil, e
		}
		// Special case: a 12-digit code encoded in UPC-A is identical to a "0"
		// followed by those 12 digits encoded as EAN-13. Each will recognize such a code,
		// UPC-A as a 12-digit string and EAN-13 as a 13-digit string starting with "0".
		// Individually these are correct and their readers will both read such a code
		// and correctly call it EAN-13, or UPC-A, respectively.
		//
		// In this case, if we've been looking for both types, we'd like to call it
		// a UPC-A code. But for efficiency we only run the EAN-13 decoder to also read
		// UPC-A. So we special case it here, and convert an EAN-13 result to a UPC-A
		// result if appropriate.
		//
		// But, don't return UPC-A if UPC-A was not a requested format!
		ean13MayBeUPCA :=
			result.GetBarcodeFormat() == gozxing.BarcodeFormat_EAN_13 &&
				result.GetText()[0] == '0'
		// @SuppressWarnings("unchecked")
		possibleFormats, _ := hints[gozxing.DecodeHintType_POSSIBLE_FORMATS].([]gozxing.BarcodeFormat)
		canReturnUPCA := false
		for _, format := range possibleFormats {
			if format == gozxing.BarcodeFormat_UPC_A {
				canReturnUPCA = true
				break
			}
		}

		if ean13MayBeUPCA && canReturnUPCA {
			// Transfer the metdata across
			resultUPCA := gozxing.NewResult(result.GetText()[1:],
				result.GetRawBytes(),
				result.GetResultPoints(),
				gozxing.BarcodeFormat_UPC_A)
			resultUPCA.PutAllMetadata(result.GetResultMetadata())
			return resultUPCA, nil
		}
		return result, nil
	}

	return nil, gozxing.NewNotFoundException()
}

/*
  public void reset() {
    for (Reader reader : readers) {
      reader.reset();
    }
  }
*/
