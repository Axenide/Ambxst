package mods

import (
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func TestManagerMovesDashboardTabWithoutChangingLoadOrder(t *testing.T) {
	manager, _ := installTabMods(t)
	first := 0
	status, err := manager.SetPosition("example.audio", PositionTab, &first)
	if err != nil {
		t.Fatal(err)
	}
	if status.Mods[0].ID != "example.agents" || status.Mods[1].ID != "example.audio" {
		t.Fatalf("a tab position must not change load order: %#v", status.Mods)
	}
	content := activeFile(t, manager, status, dashboardPath)
	for _, want := range []string{
		"tabModel: [Icons.widgets, Icons.wallpapers, Icons.heartbeat, Icons.speakerHigh, Icons.robot]",
		// Loaders stay in load order in the file, so the switch maps the new
		// indices to their real children.
		"property int index: 4\n            sourceComponent: agentsComponent",
		"property int index: 3\n            sourceComponent: audioComponent",
		"case 4: return children[3].item;\n                case 3: return children[4].item;",
	} {
		if !strings.Contains(content, want) {
			t.Fatalf("generation is missing %q:\n%s", want, content)
		}
	}
	tabs := map[string]ModInfo{}
	for _, mod := range status.Mods {
		tabs[mod.ID] = mod
	}
	if tabs["example.audio"].TabPosition != 0 || !tabs["example.audio"].TabPositionPinned ||
		!reflect.DeepEqual(tabs["example.audio"].DashboardTabs, []int{3}) {
		t.Fatalf("moved tab was not reported: %#v", tabs["example.audio"])
	}

	status, err = manager.SetPosition("example.audio", PositionTab, nil)
	if err != nil {
		t.Fatal(err)
	}
	status, err = manager.SetPosition("example.agents", PositionTab, nil)
	if err != nil {
		t.Fatal(err)
	}
	content = activeFile(t, manager, status, dashboardPath)
	if !strings.Contains(content, "Icons.heartbeat, Icons.robot, Icons.speakerHigh]") {
		t.Fatalf("auto positions did not return to load order:\n%s", content)
	}
}

func TestSetPositionRejectsKindsTheModDoesNotUse(t *testing.T) {
	manager, _ := installTabMods(t)
	zero := 0
	if _, err := manager.SetPosition("example.agents", PositionBar, &zero); err == nil {
		t.Fatal("a mod without bar widgets must not get a bar position")
	}
}

const testBar = `RowLayout {
    Clock {}

    Tray {}
}
`

func TestManagerReordersBarWidgetsIndependentlyOfLoadOrder(t *testing.T) {
	root := t.TempDir()
	base := filepath.Join(root, "base")
	writeTestFile(t, filepath.Join(base, "shell.qml"), "ShellRoot {}\n")
	writeTestFile(t, filepath.Join(base, barContentPath), testBar)
	writeTestFile(t, filepath.Join(base, "version"), "1.2.5\n")
	t.Setenv("AMBXST_SHELL", base)
	t.Setenv("AMBXST_MODS_DISABLED", "1")

	manager := NewManager(testPaths(root))
	for _, widget := range []string{"Keyboard", "Phone"} {
		id := "example." + strings.ToLower(widget)
		packageRoot := filepath.Join(root, id)
		after := strings.Replace(testBar, "    Clock {}\n", "    Clock {}\n\n    "+widget+" {\n        visible: true\n    }\n", 1)
		writeFileDiffPackage(t, packageRoot, id, barContentPath, testBar, after)
		if _, err := manager.Install(packageRoot); err != nil {
			t.Fatal(err)
		}
		if _, err := manager.SetEnabled(id, true); err != nil {
			t.Fatal(err)
		}
	}
	status, err := manager.Status()
	if err != nil {
		t.Fatal(err)
	}
	content := activeFile(t, manager, status, barContentPath)
	if strings.Index(content, "Keyboard {") > strings.Index(content, "Phone {") {
		t.Fatalf("default bar order must follow load order:\n%s", content)
	}

	first := 0
	status, err = manager.SetPosition("example.phone", PositionBar, &first)
	if err != nil {
		t.Fatal(err)
	}
	content = activeFile(t, manager, status, barContentPath)
	want := "    Clock {}\n\n    Phone {\n        visible: true\n    }\n\n    Keyboard {\n        visible: true\n    }\n\n    Tray {}"
	if !strings.Contains(content, want) {
		t.Fatalf("bar widgets were not reordered:\n%s", content)
	}
	if status.Mods[0].ID != "example.keyboard" {
		t.Fatalf("a bar position must not change load order: %#v", status.Mods)
	}
}

func TestReorderWidgetBlocksAcrossAnchorsInOneLayout(t *testing.T) {
	lines := []string{
		"RowLayout {",
		"    Keyboard {",
		"    }",
		"    Clock {}",
		"    Phone {}",
		"    Tray {}",
		"}",
		"ColumnLayout {",
		"    Phone {}",
		"}",
	}
	owners := []string{"", "example.keyboard", "example.keyboard", "", "example.phone", "", "", "", "example.phone", ""}
	got, ok := reorderWidgetBlocks(lines, owners, map[string]int{"example.phone": 0, "example.keyboard": 1})
	want := []string{
		"RowLayout {",
		"    Phone {}",
		"    Clock {}",
		"    Keyboard {",
		"    }",
		"    Tray {}",
		"}",
		"ColumnLayout {",
		"    Phone {}",
		"}",
	}
	if !ok || !reflect.DeepEqual(got, want) {
		t.Fatalf("widgets did not swap places:\n%s", strings.Join(got, "\n"))
	}
}

func TestReorderWidgetBlocksKeepsPartialObjects(t *testing.T) {
	// The keyboard mod only opened an object; its closing brace is a base line.
	lines := []string{"Row {", "    Keyboard {", "    }", "    Phone {}", "}"}
	owners := []string{"", "example.keyboard", "", "example.phone", ""}
	if _, ok := reorderWidgetBlocks(lines, owners, map[string]int{"example.phone": 0, "example.keyboard": 1}); ok {
		t.Fatal("an object the mod did not close must not move")
	}
}
