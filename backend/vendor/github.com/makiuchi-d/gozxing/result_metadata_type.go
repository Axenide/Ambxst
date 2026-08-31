package gozxing

type ResultMetadataType int

const (
	/**
	 * Unspecified, application-specific metadata. Maps to an unspecified {@link Object}.
	 */
	ResultMetadataType_OTHER = ResultMetadataType(iota)

	/**
	 * Denotes the likely approximate orientation of the barcode in the image. This value
	 * is given as degrees rotated clockwise from the normal, upright orientation.
	 * For example a 1D barcode which was found by reading top-to-bottom would be
	 * said to have orientation "90". This key maps to an {@link Integer} whose
	 * value is in the range [0,360).
	 */
	ResultMetadataType_ORIENTATION

	/**
	 * <p>2D barcode formats typically encode text, but allow for a sort of 'byte mode'
	 * which is sometimes used to encode binary data. While {@link Result} makes available
	 * the complete raw bytes in the barcode for these formats, it does not offer the bytes
	 * from the byte segments alone.</p>
	 *
	 * <p>This maps to a {@link java.util.List} of byte arrays corresponding to the
	 * raw bytes in the byte segments in the barcode, in order.</p>
	 */
	ResultMetadataType_BYTE_SEGMENTS

	/**
	 * Error correction level used, if applicable. The value type depends on the
	 * format, but is typically a String.
	 */
	ResultMetadataType_ERROR_CORRECTION_LEVEL

	/**
	 * For some periodicals, indicates the issue number as an {@link Integer}.
	 */
	ResultMetadataType_ISSUE_NUMBER

	/**
	 * For some products, indicates the suggested retail price in the barcode as a
	 * formatted {@link String}.
	 */
	ResultMetadataType_SUGGESTED_PRICE

	/**
	 * For some products, the possible country of manufacture as a {@link String} denoting the
	 * ISO country code. Some map to multiple possible countries, like "US/CA".
	 */
	ResultMetadataType_POSSIBLE_COUNTRY

	/**
	 * For some products, the extension text
	 */
	ResultMetadataType_UPC_EAN_EXTENSION

	/**
	 * PDF417-specific metadata
	 */
	ResultMetadataType_PDF417_EXTRA_METADATA

	/**
	 * If the code format supports structured append and the current scanned code is part of one then the
	 * sequence number is given with it.
	 */
	ResultMetadataType_STRUCTURED_APPEND_SEQUENCE

	/**
	 * If the code format supports structured append and the current scanned code is part of one then the
	 * parity is given with it.
	 */
	ResultMetadataType_STRUCTURED_APPEND_PARITY

	/**
	 * Barcode Symbology Identifier.
	 *  Note: According to the GS1 specification the identifier may have to replace a leading FNC1/GS character when prepending to the barcode content.
	 */
	ResultMetadataType_SYMBOLOGY_IDENTIFIER
)

func (t ResultMetadataType) String() string {
	switch t {
	case ResultMetadataType_OTHER:
		return "OTHER"
	case ResultMetadataType_ORIENTATION:
		return "ORIENTATION"
	case ResultMetadataType_BYTE_SEGMENTS:
		return "BYTE_SEGMENTS"
	case ResultMetadataType_ERROR_CORRECTION_LEVEL:
		return "ERROR_CORRECTION_LEVEL"
	case ResultMetadataType_ISSUE_NUMBER:
		return "ISSUE_NUMBER"
	case ResultMetadataType_SUGGESTED_PRICE:
		return "SUGGESTED_PRICE"
	case ResultMetadataType_POSSIBLE_COUNTRY:
		return "POSSIBLE_COUNTRY"
	case ResultMetadataType_UPC_EAN_EXTENSION:
		return "UPC_EAN_EXTENSION"
	case ResultMetadataType_PDF417_EXTRA_METADATA:
		return "PDF417_EXTRA_METADATA"
	case ResultMetadataType_STRUCTURED_APPEND_SEQUENCE:
		return "STRUCTURED_APPEND_SEQUENCE"
	case ResultMetadataType_STRUCTURED_APPEND_PARITY:
		return "STRUCTURED_APPEND_PARITY"
	case ResultMetadataType_SYMBOLOGY_IDENTIFIER:
		return "SYMBOLOGY_IDENTIFIER"
	default:
		return "unknown metadata type"
	}
}
