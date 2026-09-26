package mods

import (
	"encoding/json"
	"fmt"

	"ambxst/backend/pkg/ipc"
)

type Service struct {
	manager *Manager
}

func NewService(manager *Manager) *Service {
	return &Service{manager: manager}
}

func (s *Service) Register(server *ipc.Server) {
	server.Register(&ipc.Service{
		Name:      "mods",
		Subscribe: s.subscribe,
		Methods: map[string]ipc.HandlerFunc{
			"status":                s.status,
			"install":               s.install,
			"previewArchive":        s.previewArchive,
			"installArchive":        s.installArchive,
			"installDependencies":   s.installDependencies,
			"setEnabled":            s.setEnabled,
			"remove":                s.remove,
			"move":                  s.move,
			"setMenuIndex":          s.setMenuIndex,
			"setPosition":           s.setPosition,
			"update":                s.update,
			"rebuild":               s.rebuild,
			"rollback":              s.rollback,
			"settings":              s.settings,
			"setSetting":            s.setSetting,
			"setBypassVersionCheck": s.setBypassVersionCheck,
			"setModsEnabled":        s.setModsEnabled,
			"checkUpdates":          s.checkUpdates,
			"discardUpdates":        func(_ json.RawMessage) (any, error) { return s.manager.DiscardUpdates() },
			"applyUpdates":          s.applyUpdates,
			"setUpdatePolicy":       s.setUpdatePolicy,
			"setUpdateInterval":     s.setUpdateInterval,
			"setPeriodicChecks":     s.setPeriodicChecks,
			"diagnostics":           s.diagnostics,
			"checkCompatibility":    s.checkCompatibility,
		},
	})
}

func (s *Service) subscribe(sub *ipc.Subscriber) {
	ch := make(chan struct{}, 1)
	s.manager.eventsMu.Lock()
	if s.manager.listeners == nil {
		s.manager.listeners = map[chan struct{}]bool{}
	}
	s.manager.listeners[ch] = true
	s.manager.eventsMu.Unlock()
	defer func() { s.manager.eventsMu.Lock(); delete(s.manager.listeners, ch); s.manager.eventsMu.Unlock() }()
	for {
		if status, err := s.manager.Status(); err == nil {
			sub.Send("mods", status)
		}
		select {
		case <-sub.StopCh():
			return
		case <-ch:
		}
	}
}

func (s *Service) checkUpdates(raw json.RawMessage) (any, error) {
	var params struct {
		IDs []string `json:"ids"`
	}
	if err := json.Unmarshal(raw, &params); err != nil {
		return nil, err
	}
	return s.manager.CheckUpdates(params.IDs, false)
}

func (s *Service) applyUpdates(raw json.RawMessage) (any, error) {
	var params struct {
		PlanID   string `json:"planId"`
		Reviewed bool   `json:"reviewed"`
	}
	if err := json.Unmarshal(raw, &params); err != nil {
		return nil, err
	}
	return s.manager.ApplyUpdates(params.PlanID, params.Reviewed)
}

func (s *Service) setUpdatePolicy(raw json.RawMessage) (any, error) {
	var params struct {
		ID     string `json:"id"`
		Policy string `json:"policy"`
	}
	if err := json.Unmarshal(raw, &params); err != nil {
		return nil, err
	}
	return s.manager.SetUpdatePolicy(params.ID, params.Policy)
}

func (s *Service) setUpdateInterval(raw json.RawMessage) (any, error) {
	var params struct {
		Hours int `json:"hours"`
	}
	if err := json.Unmarshal(raw, &params); err != nil {
		return nil, err
	}
	return s.manager.SetUpdateInterval(params.Hours)
}

func (s *Service) setPeriodicChecks(raw json.RawMessage) (any, error) {
	var params struct {
		Enabled *bool `json:"enabled"`
	}
	if err := json.Unmarshal(raw, &params); err != nil {
		return nil, err
	}
	if params.Enabled == nil {
		return nil, fmt.Errorf("enabled is required")
	}
	return s.manager.SetPeriodicChecks(*params.Enabled)
}

func (s *Service) diagnostics(_ json.RawMessage) (any, error) { return s.manager.Diagnostics() }

func (s *Service) checkCompatibility(raw json.RawMessage) (any, error) {
	var params struct {
		Base string `json:"base"`
	}
	if err := json.Unmarshal(raw, &params); err != nil {
		return nil, err
	}
	return s.manager.CheckBaseCompatibility(params.Base)
}

func (s *Service) status(_ json.RawMessage) (any, error) {
	return s.manager.Status()
}

type sourceParams struct {
	Source string `json:"source"`
}

func (s *Service) install(raw json.RawMessage) (any, error) {
	var params sourceParams
	if err := json.Unmarshal(raw, &params); err != nil {
		return nil, fmt.Errorf("invalid install request: %w", err)
	}
	return s.manager.Install(params.Source)
}

func (s *Service) previewArchive(raw json.RawMessage) (any, error) {
	var params sourceParams
	if err := json.Unmarshal(raw, &params); err != nil {
		return nil, fmt.Errorf("invalid archive preview request: %w", err)
	}
	return s.manager.PreviewArchive(params.Source)
}

func (s *Service) installArchive(raw json.RawMessage) (any, error) {
	var params struct {
		Source string `json:"source"`
		SHA256 string `json:"sha256"`
	}
	if err := json.Unmarshal(raw, &params); err != nil {
		return nil, fmt.Errorf("invalid archive install request: %w", err)
	}
	return s.manager.InstallArchive(params.Source, params.SHA256)
}

type enabledParams struct {
	ID      string `json:"id"`
	Enabled bool   `json:"enabled"`
}

func (s *Service) setEnabled(raw json.RawMessage) (any, error) {
	var params enabledParams
	if err := json.Unmarshal(raw, &params); err != nil {
		return nil, fmt.Errorf("invalid enable request: %w", err)
	}
	return s.manager.SetEnabled(params.ID, params.Enabled)
}

type idParams struct {
	ID string `json:"id"`
}

func decodeID(raw json.RawMessage) (string, error) {
	var params idParams
	if err := json.Unmarshal(raw, &params); err != nil {
		return "", err
	}
	if !idPattern.MatchString(params.ID) {
		return "", fmt.Errorf("invalid mod id %q", params.ID)
	}
	return params.ID, nil
}

func (s *Service) installDependencies(raw json.RawMessage) (any, error) {
	id, err := decodeID(raw)
	if err != nil {
		return nil, fmt.Errorf("invalid dependency install request: %w", err)
	}
	return s.manager.InstallDependencies(id)
}

func (s *Service) remove(raw json.RawMessage) (any, error) {
	id, err := decodeID(raw)
	if err != nil {
		return nil, fmt.Errorf("invalid remove request: %w", err)
	}
	return s.manager.Remove(id)
}

func (s *Service) update(raw json.RawMessage) (any, error) {
	id, err := decodeID(raw)
	if err != nil {
		return nil, fmt.Errorf("invalid update request: %w", err)
	}
	return s.manager.Update(id)
}

type moveParams struct {
	ID        string `json:"id"`
	Direction int    `json:"direction"`
	Position  *int   `json:"position"`
}

func (s *Service) move(raw json.RawMessage) (any, error) {
	var params moveParams
	if err := json.Unmarshal(raw, &params); err != nil {
		return nil, fmt.Errorf("invalid move request: %w", err)
	}
	if !idPattern.MatchString(params.ID) {
		return nil, fmt.Errorf("invalid mod id %q", params.ID)
	}
	if params.Position != nil {
		return s.manager.MoveTo(params.ID, *params.Position)
	}
	return s.manager.Move(params.ID, params.Direction)
}

func (s *Service) setMenuIndex(raw json.RawMessage) (any, error) {
	var params struct {
		ID       string `json:"id"`
		Position int    `json:"position"`
	}
	if err := json.Unmarshal(raw, &params); err != nil {
		return nil, fmt.Errorf("invalid menu index request: %w", err)
	}
	if !idPattern.MatchString(params.ID) {
		return nil, fmt.Errorf("invalid mod id %q", params.ID)
	}
	return s.manager.SetMenuIndex(params.ID, params.Position)
}

func (s *Service) rebuild(_ json.RawMessage) (any, error) {
	return s.manager.Rebuild()
}

func (s *Service) rollback(_ json.RawMessage) (any, error) {
	return s.manager.Rollback()
}

func (s *Service) settings(raw json.RawMessage) (any, error) {
	id, err := decodeID(raw)
	if err != nil {
		return nil, fmt.Errorf("invalid settings request: %w", err)
	}
	return s.manager.Settings(id)
}

type settingParams struct {
	ID    string `json:"id"`
	Key   string `json:"key"`
	Value any    `json:"value"`
}

func (s *Service) setSetting(raw json.RawMessage) (any, error) {
	var params settingParams
	if err := json.Unmarshal(raw, &params); err != nil {
		return nil, fmt.Errorf("invalid setting request: %w", err)
	}
	if !idPattern.MatchString(params.ID) || !settingKeyPattern.MatchString(params.Key) {
		return nil, fmt.Errorf("invalid mod id or setting key")
	}
	return s.manager.SetSetting(params.ID, params.Key, params.Value)
}

type bypassParams struct {
	Enabled bool `json:"enabled"`
}

func (s *Service) setBypassVersionCheck(raw json.RawMessage) (any, error) {
	var params bypassParams
	if err := json.Unmarshal(raw, &params); err != nil {
		return nil, fmt.Errorf("invalid bypass request: %w", err)
	}
	return s.manager.SetBypassVersionCheck(params.Enabled)
}

func (s *Service) setModsEnabled(raw json.RawMessage) (any, error) {
	var params bypassParams
	if err := json.Unmarshal(raw, &params); err != nil {
		return nil, fmt.Errorf("invalid setModsEnabled request: %w", err)
	}
	return s.manager.SetModsEnabled(params.Enabled)
}

func (s *Service) setPosition(raw json.RawMessage) (any, error) {
	var params struct {
		ID       string `json:"id"`
		Kind     string `json:"kind"`
		Position *int   `json:"position"`
	}
	if err := json.Unmarshal(raw, &params); err != nil {
		return nil, fmt.Errorf("invalid position request: %w", err)
	}
	if !idPattern.MatchString(params.ID) {
		return nil, fmt.Errorf("invalid mod id %q", params.ID)
	}
	return s.manager.SetPosition(params.ID, params.Kind, params.Position)
}
