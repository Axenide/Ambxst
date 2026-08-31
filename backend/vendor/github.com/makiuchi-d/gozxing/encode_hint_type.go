package gozxing

type EncodeHintType int

const (
	/**
	 * Specifies what degree of error correction to use, for example in QR Codes.
	 * Type depends on the encoder. For example for QR codes it's type
	 * {@link com.google.zxing.qrcode.decoder.ErrorCorrectionLevel ErrorCorrectionLevel}.
	 * For Aztec it is of type {@link Integer}, representing the minimal percentage of error correction words.
	 * For PDF417 it is of type {@link Integer}, valid values being 0 to 8.
	 * In all cases, it can also be a {@link String} representation of the desired value as well.
	 * Note: an Aztec symbol should have a minimum of 25% EC words.
	 */
	EncodeHintType_ERROR_CORRECTION = iota

	/**
	 * Specifies what character encoding to use where applicable (type {@link String})
	 */
	EncodeHintType_CHARACTER_SET

	/**
	 * Specifies the matrix shape for Data Matrix (type {@link com.google.zxing.datamatrix.encoder.SymbolShapeHint})
	 */
	EncodeHintType_DATA_MATRIX_SHAPE

	/**
	 * Specifies a minimum barcode size (type {@link Dimension}). Only applicable to Data Matrix now.
	 *
	 * @deprecated use width/height params in
	 * {@link com.google.zxing.datamatrix.DataMatrixWriter#encode(String, BarcodeFormat, int, int)}
	 */
	EncodeHintType_MIN_SIZE

	/**
	 * Specifies a maximum barcode size (type {@link Dimension}). Only applicable to Data Matrix now.
	 *
	 * @deprecated without replacement
	 */
	EncodeHintType_MAX_SIZE

	/**
	 * Specifies margin, in pixels, to use when generating the barcode. The meaning can vary
	 * by format; for example it controls margin before and after the barcode horizontally for
	 * most 1D formats. (Type {@link Integer}, or {@link String} representation of the integer value).
	 */
	EncodeHintType_MARGIN

	/**
	 * Specifies whether to use compact mode for PDF417 (type {@link Boolean}, or "true" or "false"
	 * {@link String} value).
	 */
	EncodeHintType_PDF417_COMPACT

	/**
	 * Specifies what compaction mode to use for PDF417 (type
	 * {@link com.google.zxing.pdf417.encoder.Compaction Compaction} or {@link String} value of one of its
	 * enum values).
	 */
	EncodeHintType_PDF417_COMPACTION

	/**
	 * Specifies the minimum and maximum number of rows and columns for PDF417 (type
	 * {@link com.google.zxing.pdf417.encoder.Dimensions Dimensions}).
	 */
	EncodeHintType_PDF417_DIMENSIONS

	/**
	 * Specifies the required number of layers for an Aztec code.
	 * A negative number (-1, -2, -3, -4) specifies a compact Aztec code.
	 * 0 indicates to use the minimum number of layers (the default).
	 * A positive number (1, 2, .. 32) specifies a normal (non-compact) Aztec code.
	 * (Type {@link Integer}, or {@link String} representation of the integer value).
	 */
	EncodeHintType_AZTEC_LAYERS

	/**
	 * Specifies the exact version of QR code to be encoded.
	 * (Type {@link Integer}, or {@link String} representation of the integer value).
	 */
	EncodeHintType_QR_VERSION

	/**
	 * Specifies the QR code mask pattern to be used. Allowed values are
	 * 0..QRCode.NUM_MASK_PATTERNS-1. By default the code will automatically select
	 * the optimal mask pattern.
	 * (Type {@link Integer}, or {@link String} representation of the integer value).
	 */
	EncodeHintType_QR_MASK_PATTERN

	/**
	 * Specifies whether the data should be encoded to the GS1 standard (type {@link Boolean}, or "true" or "false"
	 * {@link String } value).
	 */
	EncodeHintType_GS1_FORMAT

	/**
	 * Forces which encoding will be used. Currently only used for Code-128 code sets (Type {@link String}). Valid values are "A", "B", "C".
	 */
	EncodeHintType_FORCE_CODE_SET
)

func (this EncodeHintType) String() string {
	switch this {
	case EncodeHintType_ERROR_CORRECTION:
		return "ERROR_CORRECTION"
	case EncodeHintType_CHARACTER_SET:
		return "CHARACTER_SET"
	case EncodeHintType_DATA_MATRIX_SHAPE:
		return "DATA_MATRIX_SHAPE"
	case EncodeHintType_MIN_SIZE:
		return "MIN_SIZE"
	case EncodeHintType_MAX_SIZE:
		return "MAX_SIZE"
	case EncodeHintType_MARGIN:
		return "MARGIN"
	case EncodeHintType_PDF417_COMPACT:
		return "PDF417_COMPACT"
	case EncodeHintType_PDF417_COMPACTION:
		return "PDF417_COMPACTION"
	case EncodeHintType_PDF417_DIMENSIONS:
		return "PDF417_DIMENSIONS"
	case EncodeHintType_AZTEC_LAYERS:
		return "AZTEC_LAYERS"
	case EncodeHintType_QR_VERSION:
		return "QR_VERSION"
	case EncodeHintType_QR_MASK_PATTERN:
		return "QR_MASK_PATTERN"
	case EncodeHintType_GS1_FORMAT:
		return "GS1_FORMAT"
	case EncodeHintType_FORCE_CODE_SET:
		return "FORCE_CODE_SET"
	}
	return ""
}
