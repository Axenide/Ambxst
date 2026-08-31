package gozxing

import (
	"time"
)

type Result struct {
	text           string
	rawBytes       []byte
	numBits        int
	resultPoints   []ResultPoint
	format         BarcodeFormat
	resultMetadata map[ResultMetadataType]interface{}
	timestamp      int64
}

func NewResult(text string, rawBytes []byte, resultPoints []ResultPoint, format BarcodeFormat) *Result {
	return NewResultWithTimestamp(
		text, rawBytes, resultPoints, format, time.Now().UnixNano()/int64(time.Millisecond))
}

func NewResultWithTimestamp(text string, rawBytes []byte, resultPoints []ResultPoint, format BarcodeFormat, timestamp int64) *Result {
	return NewResultWithNumBits(
		text, rawBytes, 8*len(rawBytes), resultPoints, format, timestamp)
}

func NewResultWithNumBits(text string, rawBytes []byte, numBits int, resultPoints []ResultPoint, format BarcodeFormat, timestamp int64) *Result {
	return &Result{
		text:           text,
		rawBytes:       rawBytes,
		numBits:        numBits,
		resultPoints:   resultPoints,
		format:         format,
		resultMetadata: nil,
		timestamp:      timestamp,
	}
}

func (this *Result) GetText() string {
	return this.text
}

func (this *Result) GetRawBytes() []byte {
	return this.rawBytes
}

func (this *Result) GetNumBits() int {
	return this.numBits
}

func (this *Result) GetResultPoints() []ResultPoint {
	return this.resultPoints
}

func (this *Result) GetBarcodeFormat() BarcodeFormat {
	return this.format
}

func (this *Result) GetResultMetadata() map[ResultMetadataType]interface{} {
	return this.resultMetadata
}

func (this *Result) PutMetadata(mdtype ResultMetadataType, value interface{}) {
	if this.resultMetadata == nil {
		this.resultMetadata = make(map[ResultMetadataType]interface{}, 1)
	}
	this.resultMetadata[mdtype] = value
}

func (this *Result) PutAllMetadata(metadata map[ResultMetadataType]interface{}) {
	if len(metadata) > 0 {
		if this.resultMetadata == nil {
			this.resultMetadata = metadata
		} else {
			for k, v := range metadata {
				this.resultMetadata[k] = v
			}
		}
	}
}

func (this *Result) AddResultPoints(newPoints []ResultPoint) {
	oldPoints := this.resultPoints
	if len(oldPoints) == 0 {
		this.resultPoints = newPoints
	} else if len(newPoints) > 0 {
		this.resultPoints = append(this.resultPoints, newPoints...)
	}
}

func (this *Result) GetTimestamp() int64 {
	return this.timestamp
}

func (this *Result) String() string {
	return this.text
}
