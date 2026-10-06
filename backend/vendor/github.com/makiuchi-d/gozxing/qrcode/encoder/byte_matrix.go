package encoder

type ByteMatrix struct {
	bytes  [][]int8
	width  int
	height int
}

func NewByteMatrix(width, height int) *ByteMatrix {
	bytes := make([][]int8, height)
	for i := 0; i < height; i++ {
		bytes[i] = make([]int8, width)
	}
	return &ByteMatrix{bytes, width, height}
}

func (this *ByteMatrix) GetHeight() int {
	return this.height
}

func (this *ByteMatrix) GetWidth() int {
	return this.width
}

func (this *ByteMatrix) Get(x, y int) int8 {
	return this.bytes[y][x]
}

func (this *ByteMatrix) GetArray() [][]int8 {
	return this.bytes
}

func (this *ByteMatrix) Set(x, y int, value int8) {
	this.bytes[y][x] = value
}

func (this *ByteMatrix) SetBool(x, y int, value bool) {
	if value {
		this.bytes[y][x] = 1
	} else {
		this.bytes[y][x] = 0
	}
}

func (this *ByteMatrix) Clear(value int8) {
	for y := range this.bytes {
		for x := range this.bytes[y] {
			this.bytes[y][x] = value
		}
	}
}

func (this *ByteMatrix) String() string {
	result := make([]byte, 0, 2*(this.width+1)*this.height)
	for _, row := range this.bytes {
		for _, b := range row {
			switch b {
			case 0:
				result = append(result, " 0"...)
			case 1:
				result = append(result, " 1"...)
			default:
				result = append(result, "  "...)
			}
		}
		result = append(result, '\n')
	}
	return string(result)
}
