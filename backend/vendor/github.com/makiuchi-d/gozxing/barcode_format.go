package gozxing

type BarcodeFormat int
type BarcodeFormats []BarcodeFormat

const (
	/** Aztec 2D barcode format. */
	BarcodeFormat_AZTEC = BarcodeFormat(iota)

	/** CODABAR 1D format. */
	BarcodeFormat_CODABAR

	/** Code 39 1D format. */
	BarcodeFormat_CODE_39

	/** Code 93 1D format. */
	BarcodeFormat_CODE_93

	/** Code 128 1D format. */
	BarcodeFormat_CODE_128

	/** Data Matrix 2D barcode format. */
	BarcodeFormat_DATA_MATRIX

	/** EAN-8 1D format. */
	BarcodeFormat_EAN_8

	/** EAN-13 1D format. */
	BarcodeFormat_EAN_13

	/** ITF (Interleaved Two of Five) 1D format. */
	BarcodeFormat_ITF

	/** MaxiCode 2D barcode format. */
	BarcodeFormat_MAXICODE

	/** PDF417 format. */
	BarcodeFormat_PDF_417

	/** QR Code 2D barcode format. */
	BarcodeFormat_QR_CODE

	/** RSS 14 */
	BarcodeFormat_RSS_14

	/** RSS EXPANDED */
	BarcodeFormat_RSS_EXPANDED

	/** UPC-A 1D format. */
	BarcodeFormat_UPC_A

	/** UPC-E 1D format. */
	BarcodeFormat_UPC_E

	/** UPC/EAN extension format. Not a stand-alone format. */
	BarcodeFormat_UPC_EAN_EXTENSION
)

func (f BarcodeFormat) String() string {
	switch f {
	case BarcodeFormat_AZTEC:
		return "AZTEC"
	case BarcodeFormat_CODABAR:
		return "CODABAR"
	case BarcodeFormat_CODE_39:
		return "CODE_39"
	case BarcodeFormat_CODE_93:
		return "CODE_93"
	case BarcodeFormat_CODE_128:
		return "CODE_128"
	case BarcodeFormat_DATA_MATRIX:
		return "DATA_MATRIX"
	case BarcodeFormat_EAN_8:
		return "EAN_8"
	case BarcodeFormat_EAN_13:
		return "EAN_13"
	case BarcodeFormat_ITF:
		return "ITF"
	case BarcodeFormat_MAXICODE:
		return "MAXICODE"
	case BarcodeFormat_PDF_417:
		return "PDF_417"
	case BarcodeFormat_QR_CODE:
		return "QR_CODE"
	case BarcodeFormat_RSS_14:
		return "RSS_14"
	case BarcodeFormat_RSS_EXPANDED:
		return "RSS_EXPANDED"
	case BarcodeFormat_UPC_A:
		return "UPC_A"
	case BarcodeFormat_UPC_E:
		return "UPC_E"
	case BarcodeFormat_UPC_EAN_EXTENSION:
		return "UPC_EAN_EXTENSION"
	default:
		return "unknown format"
	}
}

func (barcodes BarcodeFormats) Contains(c BarcodeFormat) bool {
	for _, bc := range barcodes {
		if bc == c {
			return true
		}
	}
	return false
}
