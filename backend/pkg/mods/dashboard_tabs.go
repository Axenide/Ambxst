package mods

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

const dashboardPath = "modules/widgets/dashboard/Dashboard.qml"

// defaultCoreDashboardTabs is used when the base Dashboard cannot be read.
const defaultCoreDashboardTabs = 3

var (
	dashboardTabIndexPattern = regexp.MustCompile(`\bproperty\s+int\s+index\s*:\s*([0-9]+)\b`)
	dashboardTabModelPattern = regexp.MustCompile(`\btabModel\s*:\s*\[(.*)\]`)
	dashboardTabBoundPattern = regexp.MustCompile(`^(\s*)if\s*\(\s*idx\s*<=\s*[0-9]+\s*\)\s*\{\s*$`)
)

// discoverDashboardTabs lists the Dashboard tab indices a package adds. Every
// tab mod adds a TabLoader with its index to Dashboard.qml, so that one added
// declaration identifies the tab without extra manifest metadata.
func discoverDashboardTabs(root string, manifest Manifest) ([]int, []string, error) {
	seen := make(map[int]bool)
	var tabs []int
	var icons []string
	for _, operation := range manifest.Operations {
		if operation.Type != "patch" {
			continue
		}
		path, err := safeJoin(root, operation.Source)
		if err != nil {
			return nil, nil, err
		}
		found, appended, err := dashboardTabsAddedByPatch(path)
		if err != nil {
			return nil, nil, err
		}
		for _, tab := range found {
			if !seen[tab] {
				seen[tab] = true
				tabs = append(tabs, tab)
			}
		}
		icons = append(icons, appended...)
	}
	sort.Ints(tabs)
	if len(icons) != len(tabs) {
		// Without one icon per tab the manager cannot move tabs apart from
		// load order, but indices and conflicts still resolve.
		icons = nil
	}
	return tabs, icons, nil
}

// dashboardTabsAddedByPatch returns the added loader indices and the icons
// the patch appends to tabModel.
func dashboardTabsAddedByPatch(path string) ([]int, []string, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, nil, fmt.Errorf("read patch: %w", err)
	}
	defer file.Close()

	var tabs []int
	var removedModel, addedModel []string
	currentTarget := ""
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 0, 64*1024), 4*1024*1024)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "+++ ") {
			currentTarget = patchTarget(line)
			continue
		}
		if currentTarget != dashboardPath || strings.HasPrefix(line, "--- ") {
			continue
		}
		if strings.HasPrefix(line, "-") && dashboardTabModelPattern.MatchString(line) {
			_, removedModel, _, _ = splitListLine(line[1:])
			continue
		}
		if !strings.HasPrefix(line, "+") {
			continue
		}
		if dashboardTabModelPattern.MatchString(line) {
			_, addedModel, _, _ = splitListLine(line[1:])
		}
		for _, match := range dashboardTabIndexPattern.FindAllStringSubmatch(line, -1) {
			if tab, err := strconv.Atoi(match[1]); err == nil {
				tabs = append(tabs, tab)
			}
		}
	}
	if err := scanner.Err(); err != nil {
		return nil, nil, fmt.Errorf("scan patch: %w", err)
	}
	var icons []string
	if addedModel != nil && hasItemPrefix(addedModel, removedModel) {
		icons = addedModel[len(removedModel):]
	}
	return tabs, icons, nil
}

func patchTarget(header string) string {
	fields := strings.Fields(strings.TrimSpace(header[4:]))
	if len(fields) == 0 || fields[0] == "/dev/null" {
		return ""
	}
	return filepath.ToSlash(filepath.Clean(strings.TrimPrefix(fields[0], "b/")))
}

// coreDashboardTabs counts the tabs the base Dashboard defines itself, so the
// manager never hands one of them to a mod after Ambxst adds a core tab.
func coreDashboardTabs(base string) int {
	data, err := os.ReadFile(filepath.Join(base, dashboardPath))
	if err != nil {
		return defaultCoreDashboardTabs
	}
	match := dashboardTabModelPattern.FindStringSubmatch(string(data))
	if match == nil {
		return defaultCoreDashboardTabs
	}
	items := splitListItems(match[1])
	if len(items) == 0 {
		return defaultCoreDashboardTabs
	}
	return len(items)
}

// resolvedDashboardTabs numbers mod tabs right after the core tabs, in the
// given order: load order by default, or the positions the user chose. Indices
// stay contiguous because a tab's index is also its place in tabModel.
func resolvedDashboardTabs(order []string, manifests map[string]Manifest, core int) map[string]map[int]int {
	resolved := make(map[string]map[int]int)
	next := core
	for _, id := range order {
		for _, tab := range manifests[id].DashboardTabs {
			if tab < core {
				// The mod reuses or extends a core tab rather than adding one.
				continue
			}
			if resolved[id] == nil {
				resolved[id] = make(map[int]int)
			}
			resolved[id][tab] = next
			next++
		}
	}
	return resolved
}

// tabMods keeps the ids in order that add at least one Dashboard tab.
func tabMods(order []string, manifests map[string]Manifest) []string {
	var ids []string
	for _, id := range order {
		if len(manifests[id].DashboardTabs) > 0 {
			ids = append(ids, id)
		}
	}
	return ids
}

// canReorderTabs reports whether every tab mod appends exactly one known icon
// per tab, which the manager needs to rebuild tabModel in another order.
func canReorderTabs(ids []string, manifests map[string]Manifest) bool {
	for _, id := range ids {
		if len(manifests[id].DashboardTabIcons) != len(manifests[id].DashboardTabs) {
			return false
		}
	}
	return true
}

func resolvedDashboardTabList(manifest Manifest, resolved map[int]int) []int {
	var tabs []int
	for _, tab := range manifest.DashboardTabs {
		if index, ok := resolved[tab]; ok {
			tabs = append(tabs, index)
		}
	}
	return tabs
}

// replaceDashboardTabReference rewrites the references that tie added code to
// a Dashboard tab index. Loader and switch references are only meaningful in
// Dashboard.qml; tab selection through GlobalStates or shortcuts can appear in
// any file the mod patches.
func replaceDashboardTabReference(line, target, from, to, child string) string {
	number := regexp.QuoteMeta(from)
	patterns := []*regexp.Regexp{
		regexp.MustCompile(`(\btoggleDashboardTab\s*\(\s*)` + number + `(\s*\))`),
		regexp.MustCompile(`(\bdashboardCurrentTab\s*(?:===|!==|==|!=|=)\s*)` + number + `\b()`),
		regexp.MustCompile(`(\bcurrentTab\s*(?:===|!==|==|!=)\s*)` + number + `\b()`),
	}
	if target == dashboardPath {
		patterns = append(patterns,
			regexp.MustCompile(`(\bproperty\s+int\s+index\s*:\s*)`+number+`\b()`),
			regexp.MustCompile(`(\bcase\s+)`+number+`(\s*:)`),
			regexp.MustCompile(`(//\s*Tab\s+)`+number+`\b()`),
		)
		// Loaders are the stack's children in file order, which is load
		// order, so children[N] follows the loader's place in the file
		// rather than its tab index.
		childPattern := regexp.MustCompile(`(\bchildren\s*\[\s*)` + number + `(\s*\])`)
		line = childPattern.ReplaceAllString(line, "${1}"+child+"${2}")
	}
	for _, pattern := range patterns {
		line = pattern.ReplaceAllString(line, "${1}"+to+"${2}")
	}
	return line
}

// resolvePlumbingConflict settles a conflict that only exists because two
// mods each widened the same core line for their extra tabs. Tab indices are
// owned by the manager, so the canonical form that covers every tab wins.
func resolvePlumbingConflict(path string, ours, base, theirs []string) ([]string, bool) {
	if path != dashboardPath || len(base) != 1 || len(ours) != 1 || len(theirs) != 1 {
		return nil, false
	}
	match := dashboardTabBoundPattern.FindStringSubmatch(base[0])
	if match == nil {
		return nil, false
	}
	for _, side := range []string{ours[0], theirs[0]} {
		if !strings.Contains(side, "root.tabCount") {
			return nil, false
		}
	}
	return []string{match[1] + "if (idx >= 0 && idx < root.tabCount) {"}, true
}

// mergeAppendedList merges two edits that each append items to the same
// one-line list, such as a Dashboard tabModel or a bar widget list. The base
// items stay first, then the items of the mod applied earlier, then the rest.
func mergeAppendedList(ours, base, theirs []string) ([]string, bool) {
	if len(base) != 1 || len(ours) != 1 || len(theirs) != 1 {
		return nil, false
	}
	basePrefix, baseItems, baseSuffix, ok := splitListLine(base[0])
	if !ok {
		return nil, false
	}
	oursPrefix, oursItems, oursSuffix, ok := splitListLine(ours[0])
	if !ok || oursPrefix != basePrefix || oursSuffix != baseSuffix {
		return nil, false
	}
	theirsPrefix, theirsItems, theirsSuffix, ok := splitListLine(theirs[0])
	if !ok || theirsPrefix != basePrefix || theirsSuffix != baseSuffix {
		return nil, false
	}
	if !hasItemPrefix(oursItems, baseItems) || !hasItemPrefix(theirsItems, baseItems) {
		return nil, false
	}
	merged := append([]string(nil), oursItems...)
	for _, item := range theirsItems[len(baseItems):] {
		if !stringInList(merged, item) {
			merged = append(merged, item)
		}
	}
	return []string{basePrefix + "[" + strings.Join(merged, ", ") + "]" + baseSuffix}, true
}

// splitListLine splits a line holding exactly one top-level [...] list.
func splitListLine(line string) (string, []string, string, bool) {
	open := strings.Index(line, "[")
	close := strings.LastIndex(line, "]")
	if open < 0 || close < open {
		return "", nil, "", false
	}
	if strings.ContainsAny(line[close+1:], "[]") || strings.ContainsAny(line[:open], "[]") {
		return "", nil, "", false
	}
	return line[:open], splitListItems(line[open+1 : close]), line[close+1:], true
}

// splitListItems splits on commas that are not nested in brackets, braces,
// parentheses, or strings.
func splitListItems(body string) []string {
	var items []string
	depth := 0
	quote := rune(0)
	start := 0
	for index, char := range body {
		switch {
		case quote != 0:
			if char == quote {
				quote = 0
			}
		case char == '"' || char == '\'' || char == '`':
			quote = char
		case char == '(' || char == '[' || char == '{':
			depth++
		case char == ')' || char == ']' || char == '}':
			depth--
		case char == ',' && depth == 0:
			items = append(items, strings.TrimSpace(body[start:index]))
			start = index + 1
		}
	}
	if last := strings.TrimSpace(body[start:]); last != "" {
		items = append(items, last)
	}
	return items
}

func hasItemPrefix(items, prefix []string) bool {
	if len(items) < len(prefix) {
		return false
	}
	for index, item := range prefix {
		if items[index] != item {
			return false
		}
	}
	return true
}

func blankLines(lines []string) bool {
	for _, line := range lines {
		if strings.TrimSpace(line) != "" {
			return false
		}
	}
	return true
}

func trimTrailingBlankLines(lines []string) []string {
	end := len(lines)
	for end > 0 && strings.TrimSpace(lines[end-1]) == "" {
		end--
	}
	return lines[:end]
}

// compositionTabOrder is the order enabled tab mods take in the Dashboard. It
// is load order unless the user pinned positions and every tab mod declares
// its icon, which the manager needs to reorder tabModel.
func compositionTabOrder(state State, ordered []string, manifests map[string]Manifest) []string {
	loadOrder := tabMods(ordered, manifests)
	if !hasExplicitPositions(state, PositionTab) || !canReorderTabs(loadOrder, manifests) {
		return loadOrder
	}
	return filterOrder(positionOrder(state, manifests, PositionTab), loadOrder)
}

func valueOr(values map[int]int, key int) int {
	if value, ok := values[key]; ok {
		return value
	}
	return key
}

func intInList(values []int, target int) bool {
	for _, value := range values {
		if value == target {
			return true
		}
	}
	return false
}
