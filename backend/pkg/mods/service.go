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
		Name: "mods",
		Methods: map[string]ipc.HandlerFunc{
			"status":     s.status,
			"install":    s.install,
			"setEnabled": s.setEnabled,
			"remove":     s.remove,
			"move":       s.move,
			"update":     s.update,
			"rebuild":    s.rebuild,
			"rollback":   s.rollback,
			"settings":   s.settings,
			"setSetting": s.setSetting,
		},
	})
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
