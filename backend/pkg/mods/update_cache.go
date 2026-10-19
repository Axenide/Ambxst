package mods

import "path/filepath"

// Discovery survives discarded plans and daemon restarts. Only Items belongs to
// the prepared transaction; cached records never authorize an installation.
func (m *Manager) mergeKnownUpdates(state State, items []UpdateItem) {
	known := make(map[string]UpdateItem)
	for _, item := range m.knownUpdatesFor(state) {
		known[item.ID] = item
	}
	for _, item := range items {
		index, ok := findInstalled(state, item.ID)
		if !ok {
			continue
		}
		mod := state.Mods[index]
		item.Source, item.SourceType = mod.Source, mod.SourceType
		item.CheckedAt = m.updates.LastAttempt
		if previous, ok := known[item.ID]; ok && previous.State == "available" && item.State == "failed" && item.ErrorCode == "fetch_failed" {
			previous.CheckError = item.Details
			known[item.ID] = previous
		} else {
			known[item.ID] = item
		}
	}
	m.updates.Known = make([]UpdateItem, 0, len(known))
	for _, mod := range state.Mods {
		if item, ok := known[mod.ID]; ok {
			m.updates.Known = append(m.updates.Known, item)
		}
	}
}

func (m *Manager) knownUpdatesFor(state State) []UpdateItem {
	result := make([]UpdateItem, 0, len(m.updates.Known))
	for _, item := range m.updates.Known {
		index, ok := findInstalled(state, item.ID)
		if !ok {
			continue
		}
		mod := state.Mods[index]
		manifest, err := LoadManifest(filepath.Join(m.paths.ModPackagesDir(), mod.ID))
		if err != nil || item.Source != mod.Source || item.SourceType != mod.SourceType || item.FromRevision != mod.Revision || item.FromVersion != manifest.Version {
			continue
		}
		result = append(result, item)
	}
	return result
}
