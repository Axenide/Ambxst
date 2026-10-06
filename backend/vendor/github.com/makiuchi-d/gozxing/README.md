# gozxing A Barcode Scanning/Encoding Library for Go

[![Build Status](https://github.com/makiuchi-d/gozxing/actions/workflows/main.yml/badge.svg)](https://github.com/makiuchi-d/gozxing/actions/workflows/main.yml)
[![codecov](https://codecov.io/gh/makiuchi-d/gozxing/branch/master/graph/badge.svg)](https://codecov.io/gh/makiuchi-d/gozxing)

[ZXing](https://github.com/zxing/zxing) is an open-source, multi-format 1D/2D barcode image processing library for Java.
This project is a port of ZXing core library to pure Go.

## Porting Status (supported formats)

### 2D barcodes

| Format      | Scanning           | Encoding           |
|-------------|--------------------|--------------------|
| QR Code     | :heavy_check_mark: | :heavy_check_mark: |
| Data Matrix | :heavy_check_mark: | :heavy_check_mark: |
| Aztec       | :heavy_check_mark: |                    |
| PDF 417     |                    |                    |
| MaxiCode    |                    |                    |


### 1D product barcodes

| Format      | Scanning           | Encoding           |
|-------------|--------------------|--------------------|
| UPC-A       | :heavy_check_mark: | :heavy_check_mark: |
| UPC-E       | :heavy_check_mark: | :heavy_check_mark: |
| EAN-8       | :heavy_check_mark: | :heavy_check_mark: |
| EAN-13      | :heavy_check_mark: | :heavy_check_mark: |

### 1D industrial barcode

| Format       | Scanning           | Encoding           |
|--------------|--------------------|--------------------|
| Code 39      | :heavy_check_mark: | :heavy_check_mark: |
| Code 93      | :heavy_check_mark: | :heavy_check_mark: |
| Code 128     | :heavy_check_mark: | :heavy_check_mark: |
| Codabar      | :heavy_check_mark: | :heavy_check_mark: |
| ITF          | :heavy_check_mark: | :heavy_check_mark: |
| RSS-14       | :heavy_check_mark: | -                  |
| RSS-Expanded |                    |                    |

### Special reader/writer

| Reader/Writer                | Porting status     |
|------------------------------|--------------------|
| MultiFormatReader            |                    |
| MultiFormatWriter            |                    |
| ByQuadrantReader             |                    |
| GenericMultipleBarcodeReader |                    |
| QRCodeMultiReader            | :heavy_check_mark: |
| MultiFormatUPCEANReader      | :heavy_check_mark: |
| MultiFormatOneDReader        |                    |

## Usage Examples

### Scanning QR code

```Go
package main

import (
	"fmt"
	"image"
	_ "image/jpeg"
	"os"

	"github.com/makiuchi-d/gozxing"
	"github.com/makiuchi-d/gozxing/qrcode"
)

func main() {
	// open and decode image file
	file, _ := os.Open("qrcode.jpg")
	img, _, _ := image.Decode(file)

	// prepare BinaryBitmap
	bmp, _ := gozxing.NewBinaryBitmapFromImage(img)

	// decode image
	qrReader := qrcode.NewQRCodeReader()
	result, _ := qrReader.Decode(bmp, nil)

	fmt.Println(result)
}
```

### Generating CODE128 barcode

```Go
package main

import (
	"image/png"
	"os"

	"github.com/makiuchi-d/gozxing"
	"github.com/makiuchi-d/gozxing/oned"
)

func main() {
	// Generate a barcode image (*BitMatrix)
	enc := oned.NewCode128Writer()
	img, _ := enc.Encode("Hello, Gophers!", gozxing.BarcodeFormat_CODE_128, 250, 50, nil)

	file, _ := os.Create("barcode.png")
	defer file.Close()

	// *BitMatrix implements the image.Image interface,
	// so it is able to be passed to png.Encode directly.
	_ = png.Encode(file, img)
}
```
