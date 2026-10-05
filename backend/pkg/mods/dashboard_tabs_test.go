package mods

import (
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

const testDashboard = `Item {
    readonly property var tabModel: [Icons.widgets, Icons.wallpapers, Icons.heartbeat]
    readonly property int tabCount: tabModel.length

    function getYForIndex(idx) {
        if (idx <= 2) {
            return idx * 56;
        }
        return -1;
    }

    Item {
        TabLoader {
            property int index: 2
        }

        property var currentItem: {
            switch (currentTab) {
                case 2: return children[2].item;
                default: return null;
            }
        }
    }
}
`

// tabModDashboard returns the Dashboard a third-party mod ships for its own
// tab 3, written the way public mods do it: the list, the bound, a loader, and
// the switch are all edited, and the spacer line loses its trailing spaces.
func tabModDashboard(icon, bound, component string) string {
	after := strings.Replace(testDashboard, "Icons.heartbeat]", "Icons.heartbeat, "+icon+"]", 1)
	after = strings.Replace(after, "if (idx <= 2) {", bound, 1)
	after = strings.Replace(after, `            property int index: 2
        }

`, `            property int index: 2
        }

        // Tab 3: `+component+`
        TabLoader {
            property int index: 3
            sourceComponent: `+component+`
        }

`, 1)
	after = strings.Replace(after, `                case 2: return children[2].item;
`, `                case 2: return children[2].item;
                case 3: return children[3].item;
`, 1)
	return after
}

func TestDiscoverDashboardTabsFromPatch(t *testing.T) {
	root := t.TempDir()
	writeFileDiffPackage(t, root, "example.tab", dashboardPath, testDashboard,
		tabModDashboard("Icons.robot", "if (idx < root.tabCount) {", "agents"))
	manifest, err := LoadManifest(root)
	if err != nil {
		t.Fatal(err)
	}
	// Index 2 is the core Metrics loader that only appears as context.
	if !reflect.DeepEqual(manifest.DashboardTabs, []int{3}) {
		t.Fatalf("unexpected dashboard tabs: %#v", manifest.DashboardTabs)
	}
	if !reflect.DeepEqual(manifest.DashboardTabIcons, []string{"Icons.robot"}) {
		t.Fatalf("unexpected dashboard tab icons: %#v", manifest.DashboardTabIcons)
	}
}

func TestDashboardTabsResolveCollisionsInLoadOrder(t *testing.T) {
	ordered := []string{"example.first", "example.none", "example.second", "example.third"}
	manifests := map[string]Manifest{
		"example.first":  {DashboardTabs: []int{3}},
		"example.none":   {DashboardTabs: []int{2}},
		"example.second": {DashboardTabs: []int{3, 4}},
		"example.third":  {DashboardTabs: []int{7}},
	}
	resolved := resolvedDashboardTabs(ordered, manifests, 3)
	want := map[string]map[int]int{
		"example.first":  {3: 3},
		"example.second": {3: 4, 4: 5},
		// Indices stay contiguous: a tab's index is its place in tabModel.
		"example.third": {7: 6},
	}
	if !reflect.DeepEqual(resolved, want) {
		t.Fatalf("unexpected tab resolution:\nwant %#v\n got %#v", want, resolved)
	}
}

func TestCoreDashboardTabsFollowsBase(t *testing.T) {
	base := t.TempDir()
	if got := coreDashboardTabs(base); got != defaultCoreDashboardTabs {
		t.Fatalf("missing Dashboard should use the default, got %d", got)
	}
	writeTestFile(t, filepath.Join(base, dashboardPath),
		"readonly property var tabModel: [Icons.a, Icons.b, Icons.c, Icons.d]\n")
	if got := coreDashboardTabs(base); got != 4 {
		t.Fatalf("expected 4 core tabs, got %d", got)
	}
}

func TestReplaceDashboardTabReferences(t *testing.T) {
	cases := []struct {
		target string
		line   string
		want   string
	}{
		{dashboardPath, "+        property int index: 3", "+        property int index: 4"},
		{dashboardPath, "+    case 3: return children[3].item;", "+    case 4: return children[4].item;"},
		{dashboardPath, "+    // Tab 3: Audio", "+    // Tab 4: Audio"},
		{"modules/services/GlobalShortcuts.qml", `+    case "audio": toggleDashboardTab(3); break;`, `+    case "audio": toggleDashboardTab(4); break;`},
		{"modules/example/Widget.qml", "+    GlobalStates.dashboardCurrentTab = 3;", "+    GlobalStates.dashboardCurrentTab = 4;"},
		{"modules/example/Widget.qml", "+    visible: currentTab === 3", "+    visible: currentTab === 4"},
		// Loader and switch numbers mean something else outside Dashboard.qml.
		{"modules/example/Widget.qml", "+    case 3: return 30;", "+    case 3: return 30;"},
		{dashboardPath, "+    property int index: 33", "+    property int index: 33"},
	}
	for _, test := range cases {
		if got := replaceDashboardTabReference(test.line, test.target, "3", "4", "4"); got != test.want {
			t.Errorf("%s:\nwant %q\n got %q", test.target, test.want, got)
		}
	}
}

func TestMergeAppendedList(t *testing.T) {
	base := []string{"    tabModel: [Icons.a, Icons.b]"}
	merged, ok := mergeAppendedList(
		[]string{"    tabModel: [Icons.a, Icons.b, Icons.robot]"},
		base,
		[]string{"    tabModel: [Icons.a,Icons.b, Icons.speaker]"},
	)
	if !ok || merged[0] != "    tabModel: [Icons.a, Icons.b, Icons.robot, Icons.speaker]" {
		t.Fatalf("appended items were not merged: %v %#v", ok, merged)
	}
	if _, ok := mergeAppendedList(
		[]string{"    tabModel: [Icons.b, Icons.a]"},
		base,
		[]string{"    tabModel: [Icons.a, Icons.b, Icons.c]"},
	); ok {
		t.Fatal("a reordered list must not merge as an append")
	}
	if _, ok := mergeAppendedList(
		[]string{"    otherModel: [Icons.a, Icons.b, Icons.c]"},
		base,
		[]string{"    tabModel: [Icons.a, Icons.b, Icons.d]"},
	); ok {
		t.Fatal("a renamed property must not merge as an append")
	}
}

func TestMergeAddedBlocksRules(t *testing.T) {
	conflict := func(ours, base, theirs string) string {
		return "before\n<<<<<<< ours\n" + ours + "||||||| base\n" + base + "=======\n" + theirs + ">>>>>>> theirs\nafter"
	}
	blank := conflict("\n    first()\n    \n", "    \n", "\n    second()\n\n")
	if got, ok := mergeAddedBlocks("modules/bar/BarContent.qml", blank); !ok ||
		got != "before\n\n    first()\n\n    second()\n\nafter" {
		t.Fatalf("blank base was not merged as two insertions: %v %q", ok, got)
	}

	bound := conflict("        if (idx >= 0 && idx < root.tabCount) {\n", "        if (idx <= 2) {\n", "        if (idx < root.tabCount) {\n")
	if got, ok := mergeAddedBlocks(dashboardPath, bound); !ok ||
		got != "before\n        if (idx >= 0 && idx < root.tabCount) {\nafter" {
		t.Fatalf("tab bound was not resolved: %v %q", ok, got)
	}
	if _, ok := mergeAddedBlocks("modules/other/File.qml", bound); ok {
		t.Fatal("the tab bound rule must stay limited to Dashboard.qml")
	}

	rewrite := conflict("    value: 1\n", "    value: 0\n", "    value: 2\n")
	if _, ok := mergeAddedBlocks(dashboardPath, rewrite); ok {
		t.Fatal("competing rewrites must still stop the build")
	}
}

func installTabMods(t *testing.T) (*Manager, string) {
	t.Helper()
	root := t.TempDir()
	base := filepath.Join(root, "base")
	writeTestFile(t, filepath.Join(base, "shell.qml"), "ShellRoot {}\n")
	writeTestFile(t, filepath.Join(base, dashboardPath), testDashboard)
	writeTestFile(t, filepath.Join(base, "version"), "1.2.5\n")
	t.Setenv("AMBXST_SHELL", base)
	t.Setenv("AMBXST_MODS_DISABLED", "1")

	packages := []struct {
		id, icon, bound, component string
	}{
		{"example.agents", "Icons.robot", "if (idx >= 0 && idx < root.tabCount) {", "agentsComponent"},
		{"example.audio", "Icons.speakerHigh", "if (idx < root.tabCount) {", "audioComponent"},
	}
	manager := NewManager(testPaths(root))
	for _, item := range packages {
		packageRoot := filepath.Join(root, item.id)
		writeFileDiffPackage(t, packageRoot, item.id, dashboardPath, testDashboard,
			tabModDashboard(item.icon, item.bound, item.component))
		if _, err := manager.Install(packageRoot); err != nil {
			t.Fatal(err)
		}
		if _, err := manager.SetEnabled(item.id, true); err != nil {
			t.Fatal(err)
		}
	}
	return manager, root
}

func activeFile(t *testing.T, manager *Manager, status Status, file string) string {
	t.Helper()
	data, err := os.ReadFile(filepath.Join(manager.paths.ModGenerationsDir(), status.ActiveGeneration, file))
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}

func TestManagerResolvesCompetingDashboardTabs(t *testing.T) {
	manager, _ := installTabMods(t)
	status, err := manager.Status()
	if err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(manager.paths.ModGenerationsDir(), status.ActiveGeneration, dashboardPath))
	if err != nil {
		t.Fatal(err)
	}
	content := string(data)
	for _, want := range []string{
		"tabModel: [Icons.widgets, Icons.wallpapers, Icons.heartbeat, Icons.robot, Icons.speakerHigh]",
		"if (idx >= 0 && idx < root.tabCount) {",
		"// Tab 3: agentsComponent\n        TabLoader {\n            property int index: 3\n            sourceComponent: agentsComponent",
		"// Tab 4: audioComponent\n        TabLoader {\n            property int index: 4\n            sourceComponent: audioComponent",
		"case 3: return children[3].item;\n                case 4: return children[4].item;",
	} {
		if !strings.Contains(content, want) {
			t.Fatalf("generation is missing %q:\n%s", want, content)
		}
	}
	if strings.Contains(content, "<<<<<<<") {
		t.Fatalf("generation kept conflict markers:\n%s", content)
	}
	tabs := map[string][]int{}
	for _, mod := range status.Mods {
		tabs[mod.ID] = mod.DashboardTabs
	}
	if !reflect.DeepEqual(tabs["example.agents"], []int{3}) || !reflect.DeepEqual(tabs["example.audio"], []int{4}) {
		t.Fatalf("resolved tabs were not reported: %#v", tabs)
	}
}

func TestManagerKeepsTabsThatShareAnIcon(t *testing.T) {
	root := t.TempDir()
	base := filepath.Join(root, "base")
	writeTestFile(t, filepath.Join(base, "shell.qml"), "ShellRoot {}\n")
	writeTestFile(t, filepath.Join(base, dashboardPath), testDashboard)
	writeTestFile(t, filepath.Join(base, "version"), "1.2.5\n")
	t.Setenv("AMBXST_SHELL", base)
	t.Setenv("AMBXST_MODS_DISABLED", "1")
	manager := NewManager(testPaths(root))
	// Git merges two identical tabModel edits into one, which left the
	// second tab without a button.
	for _, item := range []struct{ id, bound string }{
		{"example.first", "if (idx >= 0 && idx < root.tabCount) {"},
		{"example.second", "if (idx < root.tabCount) {"},
	} {
		packageRoot := filepath.Join(root, item.id)
		writeFileDiffPackage(t, packageRoot, item.id, dashboardPath, testDashboard,
			tabModDashboard("Icons.robot", item.bound, "component"))
		if _, err := manager.Install(packageRoot); err != nil {
			t.Fatal(err)
		}
		if _, err := manager.SetEnabled(item.id, true); err != nil {
			t.Fatal(err)
		}
	}
	status, err := manager.Status()
	if err != nil {
		t.Fatal(err)
	}
	content := activeFile(t, manager, status, dashboardPath)
	if !strings.Contains(content, "tabModel: [Icons.widgets, Icons.wallpapers, Icons.heartbeat, Icons.robot, Icons.robot]") {
		t.Fatalf("each mod tab needs its own tabModel entry:\n%s", content)
	}
}
