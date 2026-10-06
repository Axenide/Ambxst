package gozxing

type DecodeHintType int

const (
	/**
	 * Unspecified, application-specific hint. Maps to an unspecified {@link Object}.
	 */
	DecodeHintType_OTHER DecodeHintType = iota

	/**
	 * Image is a pure monochrome image of a barcode. Doesn't matter what it maps to;
	 * use {@link Boolean#TRUE}.
	 */
	DecodeHintType_PURE_BARCODE

	/**
	 * Image is known to be of one of a few possible formats.
	 * Maps to a {@link List} of {@link BarcodeFormat}s.
	 */
	DecodeHintType_POSSIBLE_FORMATS

	/**
	 * Spend more time to try to find a barcode; optimize for accuracy, not speed.
	 * Doesn't matter what it maps to; use {@link Boolean#TRUE}.
	 */
	DecodeHintType_TRY_HARDER

	/**
	 * Specifies what character encoding to use when decoding, where applicable (type String)
	 */
	DecodeHintType_CHARACTER_SET

	/**
	 * Allowed lengths of encoded data -- reject anything else. Maps to an {@code int[]}.
	 */
	DecodeHintType_ALLOWED_LENGTHS

	/**
	 * Assume Code 39 codes employ a check digit. Doesn't matter what it maps to;
	 * use {@link Boolean#TRUE}.
	 */
	DecodeHintType_ASSUME_CODE_39_CHECK_DIGIT

	/**
	 * Assume the barcode is being processed as a GS1 barcode, and modify behavior as needed.
	 * For example this affects FNC1 handling for Code 128 (aka GS1-128). Doesn't matter what it maps to;
	 * use {@link Boolean#TRUE}.
	 */
	DecodeHintType_ASSUME_GS1

	/**
	 * If true, return the start and end digits in a Codabar barcode instead of stripping them. They
	 * are alpha, whereas the rest are numeric. By default, they are stripped, but this causes them
	 * to not be. Doesn't matter what it maps to; use {@link Boolean#TRUE}.
	 */
	DecodeHintType_RETURN_CODABAR_START_END

	/**
	 * The caller needs to be notified via callback when a possible {@link ResultPoint}
	 * is found. Maps to a {@link ResultPointCallback}.
	 */
	DecodeHintType_NEED_RESULT_POINT_CALLBACK

	/**
	 * Allowed extension lengths for EAN or UPC barcodes. Other formats will ignore this.
	 * Maps to an {@code int[]} of the allowed extension lengths, for example [2], [5], or [2, 5].
	 * If it is optional to have an extension, do not set this hint. If this is set,
	 * and a UPC or EAN barcode is found but an extension is not, then no result will be returned
	 * at all.
	 */
	DecodeHintType_ALLOWED_EAN_EXTENSIONS

	/**
	 * If true, also tries to decode as inverted image. All configured decoders are simply called a
	 * second time with an inverted image. Doesn't matter what it maps to; use {@link Boolean#TRUE}.
	 */
	DecodeHintType_ALSO_INVERTED
)

func (t DecodeHintType) String() string {
	switch t {
	case DecodeHintType_OTHER:
		return "OTHER"
	case DecodeHintType_PURE_BARCODE:
		return "PURE_BARCODE"
	case DecodeHintType_POSSIBLE_FORMATS:
		return "POSSIBLE_FORMATS"
	case DecodeHintType_TRY_HARDER:
		return "TRY_HARDER"
	case DecodeHintType_CHARACTER_SET:
		return "CHARACTER_SET"
	case DecodeHintType_ALLOWED_LENGTHS:
		return "ALLOWED_LENGTHS"
	case DecodeHintType_ASSUME_CODE_39_CHECK_DIGIT:
		return "ASSUME_CODE_39_CHECK_DIGIT"
	case DecodeHintType_ASSUME_GS1:
		return "ASSUME_GS1"
	case DecodeHintType_RETURN_CODABAR_START_END:
		return "RETURN_CODABAR_START_END"
	case DecodeHintType_NEED_RESULT_POINT_CALLBACK:
		return "NEED_RESULT_POINT_CALLBACK"
	case DecodeHintType_ALLOWED_EAN_EXTENSIONS:
		return "ALLOWED_EAN_EXTENSIONS"
	case DecodeHintType_ALSO_INVERTED:
		return "ALSO_INVERTED"
	}
	return "Unknown DecodeHintType"
}
