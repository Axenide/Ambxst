package gozxing

type Writer interface {
	/**
	 * Encode a barcode using the default settings.
	 *
	 * @param contents The contents to encode in the barcode
	 * @param format The barcode format to generate
	 * @param width The preferred width in pixels
	 * @param height The preferred height in pixels
	 * @return {@link BitMatrix} representing encoded barcode image
	 * @throws WriterException if contents cannot be encoded legally in a format
	 */
	EncodeWithoutHint(contents string, format BarcodeFormat, width, height int) (*BitMatrix, error)

	/**
	 * @param contents The contents to encode in the barcode
	 * @param format The barcode format to generate
	 * @param width The preferred width in pixels
	 * @param height The preferred height in pixels
	 * @param hints Additional parameters to supply to the encoder
	 * @return {@link BitMatrix} representing encoded barcode image
	 * @throws WriterException if contents cannot be encoded legally in a format
	 */
	Encode(contents string, format BarcodeFormat, width, height int, hints map[EncodeHintType]interface{}) (*BitMatrix, error)
}
