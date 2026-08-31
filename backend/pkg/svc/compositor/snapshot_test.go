package compositor

import (
	"fmt"
	"os"
	"strings"
	"testing"
)

// TestRenderOutputSnapshot dumps a stable, hand-built input through
// Render() and prints it. Use this to eyeball the output against
// ~/.local/share/ambxst/axctl.toml during the QML→Go transition.
func TestRenderOutputSnapshot(t *testing.T) {
	if os.Getenv("DUMP_TOML") != "1" {
		t.Skip("set DUMP_TOML=1 to dump")
	}
	out := Render(realishInput())
	fmt.Println("---- begin TOML ----")
	fmt.Println(out)
	fmt.Println("---- end TOML ----")
}

// TestRenderLayoutRulesOrder matches the QML's hand-rolled key order
// for layer_rules. The QML writer emits blur, blur_popups, no_anim;
// this guard catches accidental reordering during refactors.
func TestRenderLayoutRulesOrder(t *testing.T) {
	out := Render(realishInput())
	ambxstIdx := strings.Index(out, `namespace = "^ambxst(:.*)?$"`)
	if ambxstIdx == -1 {
		t.Fatal("ambxst layer rule missing")
	}
	// Slice into the next [[layer_rules]] boundary and check key order.
	tail := out[ambxstIdx:]
	next := strings.Index(tail[1:], "[[layer_rules]]")
	if next != -1 {
		tail = tail[:next+1]
	}
	blur := strings.Index(tail, "blur = true")
	blurPopups := strings.Index(tail, "blur_popups = true")
	noAnim := strings.Index(tail, "no_anim = true")
	if !(blur < blurPopups && blurPopups < noAnim) {
		t.Errorf("expected order blur, blur_popups, no_anim; got blur=%d blur_popups=%d no_anim=%d", blur, blurPopups, noAnim)
	}
}
