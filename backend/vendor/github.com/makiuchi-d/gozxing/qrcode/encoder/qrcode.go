package encoder

import (
	"strconv"

	"github.com/makiuchi-d/gozxing/qrcode/decoder"
)

const QRCode_NUM_MASK_PATERNS = 8

type QRCode struct {
	mode        *decoder.Mode
	ecLevel     decoder.ErrorCorrectionLevel
	version     *decoder.Version
	maskPattern int
	matrix      *ByteMatrix
}

func NewQRCode() *QRCode {
	return &QRCode{
		maskPattern: -1,
	}
}

func (this *QRCode) GetMode() *decoder.Mode {
	return this.mode
}

func (this *QRCode) GetECLevel() decoder.ErrorCorrectionLevel {
	return this.ecLevel
}

func (this *QRCode) GetVersion() *decoder.Version {
	return this.version
}

func (this *QRCode) GetMaskPattern() int {
	return this.maskPattern
}

func (this *QRCode) GetMatrix() *ByteMatrix {
	return this.matrix
}

func (this *QRCode) String() string {
	result := make([]byte, 0, 200)
	result = append(result, "<<\n"...)
	result = append(result, " mode: "...)
	result = append(result, this.mode.String()...)
	result = append(result, "\n ecLevel: "...)
	result = append(result, this.ecLevel.String()...)
	result = append(result, "\n version: "...)
	result = append(result, this.version.String()...)
	result = append(result, "\n maskPattern: "...)
	result = append(result, strconv.Itoa(this.maskPattern)...)
	if this.matrix == nil {
		result = append(result, "\n matrix: nil\n"...)
	} else {
		result = append(result, "\n matrix:\n"...)
		result = append(result, this.matrix.String()...)
	}
	result = append(result, ">>\n"...)
	return string(result)
}

func (this *QRCode) SetMode(value *decoder.Mode) {
	this.mode = value
}

func (this *QRCode) SetECLevel(value decoder.ErrorCorrectionLevel) {
	this.ecLevel = value
}

func (this *QRCode) SetVersion(value *decoder.Version) {
	this.version = value
}

func (this *QRCode) SetMaskPattern(value int) {
	this.maskPattern = value
}

func (this *QRCode) SetMatrix(value *ByteMatrix) {
	this.matrix = value
}

func QRCode_IsValidMaskPattern(maskPattern int) bool {
	return maskPattern >= 0 && maskPattern < QRCode_NUM_MASK_PATERNS
}
