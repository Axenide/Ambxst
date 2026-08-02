package weather

import (
	"encoding/json"

	"ambxst/backend/pkg/ipc"
)

// Service exposes weather fetching over IPC.
type Service struct {
	client *Client
}

func NewService() *Service {
	return &Service{client: NewClient()}
}

func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "weather",
		Methods: map[string]ipc.HandlerFunc{
			"get": func(params json.RawMessage) (any, error) {
				var p struct {
					Location string `json:"location"`
				}
				location := ""
				if len(params) > 0 {
					json.Unmarshal(params, &p)
					location = p.Location
				}
				resp, err := s.client.Fetch(location)
				if err != nil {
					return map[string]any{"error": err.Error()}, nil
				}
				return resp, nil
			},
		},
	})
}