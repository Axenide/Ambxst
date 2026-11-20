package ocr

import (
	"bytes"
	"context"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"math"
	"os/exec"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"
)

const maxImagePixels = 40_000_000

type textLine struct {
	text       string
	paragraph  string
	bounds     image.Rectangle
	confidence float64
	weight     int
}

func recognizePNG(data []byte, langs string) (string, error) {
	config, err := png.DecodeConfig(bytes.NewReader(data))
	if err != nil {
		return "", fmt.Errorf("decode screenshot: %w", err)
	}
	if config.Width <= 0 || config.Height <= 0 || int64(config.Width)*int64(config.Height) > maxImagePixels {
		return "", fmt.Errorf("screenshot exceeds 40 megapixels")
	}
	if strings.TrimSpace(langs) == "" {
		langs = "eng+spa"
	}
	original, err := runTesseract(data, langs)
	if err != nil {
		return "", err
	}
	if averageConfidence(original) >= 95 {
		return joinLines(original), nil
	}
	prepared, scale, border, err := preparePNG(data)
	if err != nil {
		return "", err
	}
	retry, err := runTesseract(prepared, langs)
	if err != nil {
		// The first pass remains usable if the optional retry fails.
		return joinLines(original), nil
	}
	for i := range retry {
		r := retry[i].bounds
		retry[i].bounds = image.Rect((r.Min.X-border)/scale, (r.Min.Y-border)/scale, (r.Max.X-border+scale-1)/scale, (r.Max.Y-border+scale-1)/scale)
	}
	return joinLines(improveLines(original, retry)), nil
}

func runTesseract(data []byte, langs string) ([]textLine, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, "tesseract", "-", "-", "-l", langs, "--oem", "1", "tsv")
	cmd.Stdin = bytes.NewReader(data)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if ctx.Err() != nil {
		return nil, fmt.Errorf("tesseract timed out")
	}
	if err != nil || strings.Contains(stderr.String(), "Failed loading language") {
		if err == nil {
			err = fmt.Errorf("a selected language model is unavailable")
		}
		return nil, fmt.Errorf("tesseract: %w: %s", err, strings.TrimSpace(stderr.String()))
	}
	return parseTSV(string(out))
}

func parseTSV(tsv string) ([]textLine, error) {
	var lines []textLine
	lastKey := ""
	for _, row := range strings.Split(tsv, "\n") {
		fields := strings.SplitN(strings.TrimSuffix(row, "\r"), "\t", 12)
		if len(fields) != 12 || fields[0] != "5" || strings.TrimSpace(fields[11]) == "" {
			continue
		}
		var rect [4]int
		for i := range rect {
			n, err := strconv.Atoi(fields[6+i])
			if err != nil || n < 0 {
				return nil, fmt.Errorf("invalid tesseract word bounds")
			}
			rect[i] = n
		}
		confidence, err := strconv.ParseFloat(fields[10], 64)
		if err != nil || math.IsNaN(confidence) || math.IsInf(confidence, 0) || confidence < 0 || confidence > 100 {
			return nil, fmt.Errorf("invalid tesseract confidence")
		}
		paragraph := strings.Join(fields[1:4], ":")
		key := paragraph + ":" + fields[4]
		if key != lastKey {
			lines = append(lines, textLine{paragraph: paragraph})
			lastKey = key
		}
		line := &lines[len(lines)-1]
		word := fields[11]
		if line.text != "" {
			line.text += " "
		}
		line.text += word
		weight := utf8.RuneCountInString(word)
		line.confidence += confidence * float64(weight)
		line.weight += weight
		line.bounds = line.bounds.Union(image.Rect(rect[0], rect[1], rect[0]+rect[2], rect[1]+rect[3]))
	}
	for i := range lines {
		lines[i].confidence /= float64(lines[i].weight)
	}
	return lines, nil
}

func averageConfidence(lines []textLine) float64 {
	var sum float64
	weight := 0
	for _, line := range lines {
		sum += line.confidence * float64(line.weight)
		weight += line.weight
	}
	if weight == 0 {
		return 0
	}
	return sum / float64(weight)
}

func improveLines(original, retry []textLine) []textLine {
	if len(original) == 0 {
		return retry
	}
	out := append([]textLine(nil), original...)
	used := make([]bool, len(retry))
	for i, line := range original {
		best, overlap := -1, 0.0
		for j, candidate := range retry {
			if used[j] {
				continue
			}
			intersection := line.bounds.Intersect(candidate.bounds)
			area := intersection.Dx() * intersection.Dy()
			union := line.bounds.Dx()*line.bounds.Dy() + candidate.bounds.Dx()*candidate.bounds.Dy() - area
			if area <= 0 || union <= 0 {
				continue
			}
			match := float64(area) / float64(union)
			if match > overlap {
				best, overlap = j, match
			}
		}
		if best >= 0 && overlap >= 0.5 {
			used[best] = true
			// Confidence is an estimate. Keep the original for marginal gains;
			// interpolation can hurt one script while helping another.
			if retry[best].confidence >= line.confidence+10 {
				out[i].text = retry[best].text
			}
		}
	}
	return out
}

func joinLines(lines []textLine) string {
	var text strings.Builder
	for i, line := range lines {
		if i > 0 {
			text.WriteByte('\n')
			if line.paragraph != lines[i-1].paragraph {
				text.WriteByte('\n')
			}
		}
		text.WriteString(line.text)
	}
	return text.String()
}

// preparePNG enlarges small screen text without blurring its strokes,
// normalizes dark backgrounds and adds a border for tightly cropped text.
func preparePNG(data []byte) ([]byte, int, int, error) {
	src, err := png.Decode(bytes.NewReader(data))
	if err != nil {
		return nil, 0, 0, err
	}
	bounds := src.Bounds()
	gray := image.NewGray(image.Rect(0, 0, bounds.Dx(), bounds.Dy()))
	var histogram [256]int
	for y := 0; y < bounds.Dy(); y++ {
		for x := 0; x < bounds.Dx(); x++ {
			r, g, b, a := src.At(x+bounds.Min.X, y+bounds.Min.Y).RGBA()
			// RGBA components are premultiplied. Composite against white.
			white := uint32(65535) - a
			value := uint8(((299*r+587*g+114*b)/1000 + white) >> 8)
			gray.SetGray(x, y, color.Gray{Y: value})
			histogram[value]++
		}
	}
	count, median := 0, 0
	for median < 255 {
		count += histogram[median]
		if count > len(gray.Pix)/2 {
			break
		}
		median++
	}
	invert := median < 128
	scale := 3
	// Bound the enlargement; never downsample a high-resolution capture.
	for scale > 1 && int64(bounds.Dx())*int64(bounds.Dy())*int64(scale*scale) > 12_000_000 {
		scale--
	}
	const border = 10
	dst := image.NewGray(image.Rect(0, 0, bounds.Dx()*scale+border*2, bounds.Dy()*scale+border*2))
	for i := range dst.Pix {
		dst.Pix[i] = 255
	}
	for y := border; y < dst.Bounds().Dy()-border; y++ {
		for x := border; x < dst.Bounds().Dx()-border; x++ {
			value := gray.GrayAt((x-border)/scale, (y-border)/scale).Y
			if invert {
				value = 255 - value
			}
			dst.SetGray(x, y, color.Gray{Y: value})
		}
	}
	var out bytes.Buffer
	if err := png.Encode(&out, dst); err != nil {
		return nil, 0, 0, err
	}
	return out.Bytes(), scale, border, nil
}
