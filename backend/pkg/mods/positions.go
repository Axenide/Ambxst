package mods

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

// Position kinds. A mod only has the kinds it actually uses: a Settings menu
// entry, a Dashboard tab, or a widget in the bar.
const (
	PositionMenu = "menu"
	PositionTab  = "tab"
	PositionBar  = "bar"
)

const barContentPath = "modules/bar/BarContent.qml"

// barWidgetPattern matches an added QML object, the shape every bar widget
// takes. Property tweaks to existing bar items do not give a mod a position.
var barWidgetPattern = regexp.MustCompile(`^\+\s*[A-Z][A-Za-z0-9_.]*\s*\{`)

// SetPosition places a mod among the mods that use the same kind of position.
// Load order stays the default and still decides every conflict; a position
// only overrides where the finished item appears. A nil position returns the
// mod to its load-order place.
func (m *Manager) SetPosition(id, kind string, position *int) (Status, error) {
	if kind == PositionMenu {
		return m.setMenuIndex(id, position)
	}
	if kind != PositionTab && kind != PositionBar {
		return Status{}, fmt.Errorf("unknown position kind %q", kind)
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	if err := m.guardUpdateTrial(); err != nil {
		return Status{}, err
	}
	state, err := m.loadState()
	if err != nil {
		return Status{}, err
	}
	if _, ok := findInstalled(state, id); !ok {
		return Status{}, fmt.Errorf("mod %q is not installed", id)
	}
	manifests := m.installedManifests(state)
	if !usesPosition(manifests[id], kind) {
		return Status{}, fmt.Errorf("mod %q has no %s position", id, kind)
	}

	next := cloneState(state)
	if position == nil {
		index, _ := findInstalled(next, id)
		setExplicitPosition(&next.Mods[index], kind, nil)
	} else {
		order := positionOrder(next, manifests, kind)
		target := *position
		if target < 0 {
			target = 0
		}
		if target >= len(order) {
			target = len(order) - 1
		}
		order = moveID(order, id, target)
		// Every mod of this kind is pinned, so a later install cannot shift
		// the order the user chose.
		for rank, orderedID := range order {
			index, _ := findInstalled(next, orderedID)
			value := rank
			setExplicitPosition(&next.Mods[index], kind, &value)
		}
	}

	index, _ := findInstalled(next, id)
	if !next.Mods[index].Enabled {
		if err := m.saveState(next); err != nil {
			return Status{}, err
		}
		return m.statusFor(next)
	}
	if err := m.composeAndActivate(state, &next); err != nil {
		return Status{}, err
	}
	return m.statusForRestart(next, true)
}

func (m *Manager) setMenuIndex(id string, position *int) (Status, error) {
	if position != nil {
		return m.SetMenuIndex(id, *position)
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	state, err := m.loadState()
	if err != nil {
		return Status{}, err
	}
	index, ok := findInstalled(state, id)
	if !ok {
		return Status{}, fmt.Errorf("mod %q is not installed", id)
	}
	next := cloneState(state)
	next.Mods[index].MenuIndex = nil
	if err := m.saveState(next); err != nil {
		return Status{}, err
	}
	return m.statusFor(next)
}

func (m *Manager) installedManifests(state State) map[string]Manifest {
	manifests := make(map[string]Manifest, len(state.Mods))
	for _, installed := range state.Mods {
		manifest, err := LoadManifest(filepath.Join(m.paths.ModPackagesDir(), installed.ID))
		if err == nil {
			manifests[installed.ID] = manifest
		}
	}
	return manifests
}

func usesPosition(manifest Manifest, kind string) bool {
	switch kind {
	case PositionMenu:
		return len(settingsMenusForManifest(manifest)) > 0
	case PositionTab:
		return len(manifest.DashboardTabs) > 0
	case PositionBar:
		return manifest.BarWidgets
	}
	return false
}

func explicitPosition(mod InstalledMod, kind string) *int {
	switch kind {
	case PositionTab:
		return mod.TabPosition
	case PositionBar:
		return mod.BarPosition
	}
	return nil
}

func setExplicitPosition(mod *InstalledMod, kind string, value *int) {
	switch kind {
	case PositionTab:
		mod.TabPosition = value
	case PositionBar:
		mod.BarPosition = value
	}
}

// positionOrder lists the installed mods of one kind in display order. A mod
// without an explicit position keeps its load-order rank, and ties fall back
// to load order, so the default is exactly the order conflicts resolve in.
func positionOrder(state State, manifests map[string]Manifest, kind string) []string {
	type entry struct {
		id   string
		key  int
		load int
	}
	var entries []entry
	for _, mod := range state.Mods {
		if !usesPosition(manifests[mod.ID], kind) {
			continue
		}
		rank := len(entries)
		key := rank
		if explicit := explicitPosition(mod, kind); explicit != nil {
			key = *explicit
		}
		entries = append(entries, entry{id: mod.ID, key: key, load: rank})
	}
	sort.SliceStable(entries, func(a, b int) bool {
		if entries[a].key != entries[b].key {
			return entries[a].key < entries[b].key
		}
		return entries[a].load < entries[b].load
	})
	order := make([]string, len(entries))
	for index, item := range entries {
		order[index] = item.id
	}
	return order
}

func hasExplicitPositions(state State, kind string) bool {
	for _, mod := range state.Mods {
		if mod.Enabled && explicitPosition(mod, kind) != nil {
			return true
		}
	}
	return false
}

// filterOrder keeps the ids that take part in the current composition.
func filterOrder(order []string, ordered []string) []string {
	enabled := make(map[string]bool, len(ordered))
	for _, id := range ordered {
		enabled[id] = true
	}
	var filtered []string
	for _, id := range order {
		if enabled[id] {
			filtered = append(filtered, id)
		}
	}
	return filtered
}

func moveID(order []string, id string, target int) []string {
	var rest []string
	for _, item := range order {
		if item != id {
			rest = append(rest, item)
		}
	}
	if target > len(rest) {
		target = len(rest)
	}
	result := append([]string{}, rest[:target]...)
	result = append(result, id)
	return append(result, rest[target:]...)
}

func positionRank(order []string, id string) int {
	for index, item := range order {
		if item == id {
			return index
		}
	}
	return 0
}

// discoverBarWidgets reports whether a package adds a QML object to the bar.
func discoverBarWidgets(root string, manifest Manifest) (bool, error) {
	for _, operation := range manifest.Operations {
		if operation.Type != "patch" {
			continue
		}
		path, err := safeJoin(root, operation.Source)
		if err != nil {
			return false, err
		}
		file, err := os.Open(path)
		if err != nil {
			return false, fmt.Errorf("read patch: %w", err)
		}
		target := ""
		found := false
		scanner := bufio.NewScanner(file)
		scanner.Buffer(make([]byte, 0, 64*1024), 4*1024*1024)
		for scanner.Scan() {
			line := scanner.Text()
			if strings.HasPrefix(line, "+++ ") {
				target = patchTarget(line)
				continue
			}
			if target == barContentPath && barWidgetPattern.MatchString(line) {
				found = true
				break
			}
		}
		scanErr := scanner.Err()
		file.Close()
		if scanErr != nil {
			return false, fmt.Errorf("scan patch: %w", scanErr)
		}
		if found {
			return true, nil
		}
	}
	return false, nil
}

// applyTabModelOrder rewrites the merged tabModel so the icons follow the
// resolved tab indices instead of the order the patches were applied in. It
// also restores icons lost when two mods append the same one: Git merges the
// identical edits into one, and the tab after it would have no button.
func applyTabModelOrder(generation string, core int, loadOrder, tabOrder []string, manifests map[string]Manifest) error {
	path := filepath.Join(generation, dashboardPath)
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	lines := strings.Split(string(data), "\n")
	for index, line := range lines {
		if !dashboardTabModelPattern.MatchString(line) {
			continue
		}
		prefix, items, suffix, ok := splitListLine(line)
		if !ok || len(items) < core {
			break
		}
		expected := append([]string{}, items[:core]...)
		for _, id := range loadOrder {
			expected = append(expected, manifests[id].DashboardTabIcons...)
		}
		if !sameItems(items, expected) && !collapsedItems(items[core:], expected[core:]) {
			break
		}
		ordered := append([]string{}, items[:core]...)
		for _, id := range tabOrder {
			ordered = append(ordered, manifests[id].DashboardTabIcons...)
		}
		if sameItems(items, ordered) {
			return nil
		}
		lines[index] = prefix + "[" + strings.Join(ordered, ", ") + "]" + suffix
		return os.WriteFile(path, []byte(strings.Join(lines, "\n")), 0o644)
	}
	if sameItems(loadOrder, tabOrder) {
		// Nothing to move; keep the list the mods wrote.
		return nil
	}
	return fmt.Errorf("the Dashboard tab list was changed by another mod, so the tab order cannot be applied; " +
		"reset it with `ambxst mods position <id> tab auto`")
}

func sameItems(a, b []string) bool {
	return strings.Join(a, "\x00") == strings.Join(b, "\x00")
}

// collapsedItems reports whether got holds the same distinct items as want
// but fewer of them, which is what merging identical appends leaves behind.
func collapsedItems(got, want []string) bool {
	if len(got) >= len(want) {
		return false
	}
	for _, item := range got {
		if !stringInList(want, item) {
			return false
		}
	}
	for _, item := range want {
		if !stringInList(got, item) {
			return false
		}
	}
	return true
}

// reorderBarWidgets orders the widgets mods add to the same bar layout by bar
// position. Composition commits every mod separately, so blame tells which mod
// added each line. The places the widgets occupy stay the same; only which
// mod's widget sits in which place changes, so core items never move. A widget
// moves only as a whole, balanced QML object.
func reorderBarWidgets(generation string, rank map[string]int) error {
	path := filepath.Join(generation, barContentPath)
	if _, err := os.Stat(path); err != nil {
		return nil
	}
	owners, err := blameOwners(generation, barContentPath)
	if err != nil {
		return err
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	lines := strings.Split(string(data), "\n")
	if len(owners) < len(lines) {
		owners = append(owners, make([]string, len(lines)-len(owners))...)
	}
	reordered, changed := reorderWidgetBlocks(lines, owners, rank)
	if !changed {
		return nil
	}
	return os.WriteFile(path, []byte(strings.Join(reordered, "\n")), 0o644)
}

type widgetBlock struct {
	owner      string
	start, end int // lines[start:end]
	parent     int // line of the enclosing open brace
	order      int
}

func reorderWidgetBlocks(lines, owners []string, rank map[string]int) ([]string, bool) {
	parents := enclosingBraces(lines)
	var blocks []widgetBlock
	for index := 0; index < len(lines); {
		owner := owners[index]
		if _, ranked := rank[owner]; !ranked || !barWidgetPattern.MatchString("+"+lines[index]) {
			index++
			continue
		}
		end := index + 1
		for end < len(lines) && !balanced(lines[index:end]) {
			if owners[end] != owner {
				break
			}
			end++
		}
		if !balanced(lines[index:end]) {
			index++
			continue
		}
		blocks = append(blocks, widgetBlock{owner: owner, start: index, end: end, parent: parents[index], order: len(blocks)})
		index = end
	}

	groups := make(map[int][]widgetBlock)
	var parentsInOrder []int
	for _, block := range blocks {
		if _, seen := groups[block.parent]; !seen {
			parentsInOrder = append(parentsInOrder, block.parent)
		}
		groups[block.parent] = append(groups[block.parent], block)
	}
	placement := make(map[int]widgetBlock) // slot start -> block placed there
	for _, parent := range parentsInOrder {
		slots := groups[parent]
		sorted := append([]widgetBlock{}, slots...)
		sort.SliceStable(sorted, func(a, b int) bool {
			if rank[sorted[a].owner] != rank[sorted[b].owner] {
				return rank[sorted[a].owner] < rank[sorted[b].owner]
			}
			return sorted[a].order < sorted[b].order
		})
		for index, slot := range slots {
			if sorted[index].start != slot.start {
				placement[slot.start] = sorted[index]
			}
		}
	}
	if len(placement) == 0 {
		return nil, false
	}
	var out []string
	for index := 0; index < len(lines); {
		block, moved := placement[index]
		if !moved {
			out = append(out, lines[index])
			index++
			continue
		}
		out = append(out, lines[block.start:block.end]...)
		for _, original := range blocks {
			if original.start == index {
				index = original.end
				break
			}
		}
	}
	return out, true
}

// enclosingBraces returns, for every line, the line of the innermost brace
// still open when the line starts. Widgets with the same parent are siblings.
func enclosingBraces(lines []string) []int {
	parents := make([]int, len(lines))
	stack := []int{-1}
	for index, line := range lines {
		parents[index] = stack[len(stack)-1]
		quote := rune(0)
		previous := rune(0)
		for _, char := range line {
			if quote != 0 {
				if char == quote && previous != '\\' {
					quote = 0
				}
				previous = char
				continue
			}
			if char == '/' && previous == '/' {
				break
			}
			switch char {
			case '"', '\'', '`':
				quote = char
			case '{':
				stack = append(stack, index)
			case '}':
				if len(stack) > 1 {
					stack = stack[:len(stack)-1]
				}
			}
			previous = char
		}
	}
	return parents
}

// balanced reports whether a block closes every bracket it opens, ignoring
// strings and line comments, so moving it cannot split a QML object.
func balanced(lines []string) bool {
	depth := 0
	for _, line := range lines {
		quote := rune(0)
		previous := rune(0)
		for _, char := range line {
			if quote != 0 {
				if char == quote && previous != '\\' {
					quote = 0
				}
				previous = char
				continue
			}
			if char == '/' && previous == '/' {
				break
			}
			switch char {
			case '"', '\'', '`':
				quote = char
			case '{', '(', '[':
				depth++
			case '}', ')', ']':
				depth--
				if depth < 0 {
					return false
				}
			}
			previous = char
		}
	}
	return depth == 0
}

// blameOwners maps every line of a composed file to the mod that added it, or
// to "" for base lines.
func blameOwners(generation, file string) ([]string, error) {
	cmd := exec.Command("git", "blame", "--line-porcelain", "HEAD", "--", file)
	cmd.Dir = generation
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("blame %s: %w", file, err)
	}
	var owners []string
	current := ""
	for _, line := range strings.Split(string(output), "\n") {
		switch {
		case strings.HasPrefix(line, "summary "):
			current = ""
			if summary := strings.TrimPrefix(line, "summary "); strings.HasPrefix(summary, "mod ") {
				current = strings.TrimPrefix(summary, "mod ")
			}
		case strings.HasPrefix(line, "\t"):
			owners = append(owners, current)
		}
	}
	return owners, nil
}
