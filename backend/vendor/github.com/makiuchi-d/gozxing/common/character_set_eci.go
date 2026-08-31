package common

import (
	"github.com/makiuchi-d/gozxing"
	"golang.org/x/text/encoding"
	"golang.org/x/text/encoding/charmap"
	"golang.org/x/text/encoding/ianaindex"
	"golang.org/x/text/encoding/japanese"
	"golang.org/x/text/encoding/korean"
	"golang.org/x/text/encoding/simplifiedchinese"
	"golang.org/x/text/encoding/traditionalchinese"
	"golang.org/x/text/encoding/unicode"
)

type CharacterSetECI struct {
	values             []int
	charset            encoding.Encoding
	name               string
	otherEncodingNames []string
}

var (
	valueToECI = map[int]*CharacterSetECI{}
	nameToECI  = map[string]*CharacterSetECI{}

	asciiEnc, _   = ianaindex.IANA.Encoding("US-ASCII")
	utf16beEnc, _ = ianaindex.IANA.Encoding("UTF-16BE")

	CharacterSetECI_Cp437     = newCharsetECI([]int{0, 2}, charmap.CodePage437, "Cp437")
	CharacterSetECI_ISO8859_1 = newCharsetECI([]int{1, 3}, charmap.ISO8859_1, "ISO-8859-1", "ISO8859_1")
	CharacterSetECI_ISO8859_2 = newCharsetECI([]int{4}, charmap.ISO8859_2, "ISO-8859-2", "ISO8859_2")
	CharacterSetECI_ISO8859_3 = newCharsetECI([]int{5}, charmap.ISO8859_3, "ISO-8859-3", "ISO8859_3")
	CharacterSetECI_ISO8859_4 = newCharsetECI([]int{6}, charmap.ISO8859_4, "ISO-8859-4", "ISO8859_4")
	CharacterSetECI_ISO8859_5 = newCharsetECI([]int{7}, charmap.ISO8859_5, "ISO-8859-5", "ISO8859_5")
	//CharacterSetECI_ISO8859_6  = newCharsetECI([]int{8}, charmap.ISO8859_6, "ISO-8859-6", "ISO8859_6")
	CharacterSetECI_ISO8859_7 = newCharsetECI([]int{9}, charmap.ISO8859_7, "ISO-8859-7", "ISO8859_7")
	//CharacterSetECI_ISO8859_8  = newCharsetECI([]int{10}, charmap.ISO8859_8, "ISO-8859-8", "ISO8859_8")
	CharacterSetECI_ISO8859_9 = newCharsetECI([]int{11}, charmap.ISO8859_9, "ISO-8859-9", "ISO8859_9")
	//CharacterSetECI_ISO8859_10 = newCharsetECI([]int{12}, charmap.ISO8859_10, "ISO-8859-10", "ISO8859_10")
	//CharacterSetECI_ISO8859_11 = newCharsetECI([]int{13}, charmap.ISO8859_11, "TIS-620", "ISO-8859-11", "ISO8859_11") // golang does not support

	CharacterSetECI_ISO8859_13 = newCharsetECI([]int{15}, charmap.ISO8859_13, "ISO-8859-13", "ISO8859_13")
	//CharacterSetECI_ISO8859_14         = newCharsetECI([]int{16}, charmap.ISO8859_14, "ISO-8859-14", "ISO8859_14")
	CharacterSetECI_ISO8859_15         = newCharsetECI([]int{17}, charmap.ISO8859_15, "ISO-8859-15", "ISO8859_15")
	CharacterSetECI_ISO8859_16         = newCharsetECI([]int{18}, charmap.ISO8859_16, "ISO-8859-16", "ISO8859_16")
	CharacterSetECI_SJIS               = newCharsetECI([]int{20}, japanese.ShiftJIS, "Shift_JIS", "SJIS")
	CharacterSetECI_Cp1250             = newCharsetECI([]int{21}, charmap.Windows1250, "windows-1250", "Cp1250")
	CharacterSetECI_Cp1251             = newCharsetECI([]int{22}, charmap.Windows1251, "windows-1251", "Cp1251")
	CharacterSetECI_Cp1252             = newCharsetECI([]int{23}, charmap.Windows1252, "windows-1252", "Cp1252")
	CharacterSetECI_Cp1256             = newCharsetECI([]int{24}, charmap.Windows1256, "windows-1256", "Cp1256")
	CharacterSetECI_UnicodeBigUnmarked = newCharsetECI([]int{25}, utf16beEnc, "UTF-16BE", "UnicodeBig", "UnicodeBigUnmarked")
	CharacterSetECI_UTF8               = newCharsetECI([]int{26}, unicode.UTF8, "UTF-8", "UTF8")
	CharacterSetECI_ASCII              = newCharsetECI([]int{27, 170}, asciiEnc, "ASCII", "US-ASCII")
	CharacterSetECI_Big5               = newCharsetECI([]int{28}, traditionalchinese.Big5, "Big5")
	CharacterSetECI_GB18030            = newCharsetECI([]int{29}, simplifiedchinese.GB18030, "GB18030", "GB2312", "EUC_CN", "GBK") // BG18030 is upward compatible with others
	CharacterSetECI_EUC_KR             = newCharsetECI([]int{30}, korean.EUCKR, "EUC-KR", "EUC_KR")
)

func newCharsetECI(values []int, charset encoding.Encoding, encodingNames ...string) *CharacterSetECI {
	c := &CharacterSetECI{
		values:             values,
		charset:            charset,
		name:               encodingNames[0],
		otherEncodingNames: encodingNames[1:],
	}
	for _, val := range values {
		valueToECI[val] = c
	}
	for _, name := range encodingNames {
		nameToECI[name] = c
	}
	iananame, _ := ianaindex.IANA.Name(charset)
	nameToECI[iananame] = c
	return c
}

func (this *CharacterSetECI) GetValue() int {
	return this.values[0]
}

func (this *CharacterSetECI) Name() string {
	return this.name
}

func (this *CharacterSetECI) GetCharset() encoding.Encoding {
	return this.charset
}

func GetCharacterSetECI(charset encoding.Encoding) (*CharacterSetECI, bool) {
	name, err := ianaindex.IANA.Name(charset)
	if err != nil {
		return nil, false
	}
	eci, ok := nameToECI[name]
	return eci, ok
}

func GetCharacterSetECIByValue(value int) (*CharacterSetECI, error) {
	if value < 0 || value >= 900 {
		return nil, gozxing.NewFormatException()
	}
	return valueToECI[value], nil
}

func GetCharacterSetECIByName(name string) (*CharacterSetECI, bool) {
	eci, ok := nameToECI[name]
	return eci, ok
}
