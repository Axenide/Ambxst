package ipc

import (
	"bufio"
	"encoding/json"
	"net"
	"sync"
)

// streamSubscribe transitions a connection into streaming event mode.
// It mirrors DMS semantics: params {clientId?, services?: [...]}.
// The subscribe request itself is responded to with the initial server info
// event, then per-service state events stream over the same connection.
func (s *Server) streamSubscribe(conn net.Conn, w *bufio.Writer, req *Request) {
	Params := req.Params
	var params struct {
		ClientID string   `json:"clientId"`
		Services []string `json:"services"`
	}
	if len(Params) > 0 {
		json.Unmarshal(Params, &params)
	}
	if len(params.Services) == 0 {
		params.Services = []string{"all"}
	}

	all := false
	for _, sv := range params.Services {
		if sv == "all" {
			all = true
			break
		}
	}

	sub := &Subscriber{
		Events: make(chan ServiceEvent, 256),
		stop:   make(chan struct{}),
	}

	// Stream events in a goroutine. On dead conn it stops the sub.
	done := make(chan struct{})
	go func() {
		defer close(done)
		for {
			select {
			case event, ok := <-sub.Events:
				if !ok {
					return
				}
				resp := Response{ID: req.ID, Result: marshalEvent(event)}
				if err := writeMessageStream(w, resp); err != nil {
					sub.Stop()
					return
				}
			case <-sub.stop:
				return
			}
		}
	}()

	// Register this stream with every matching service.
	var wg sync.WaitGroup
	s.mu.RLock()
	for _, svc := range s.services {
		if svc.Subscribe == nil {
			continue
		}
		if !all && !contains(params.Services, svc.Name) {
			continue
		}
		wg.Add(1)
		go func(svc *Service) {
			defer wg.Done()
			svc.Subscribe(sub)
		}(svc)
	}
	s.mu.RUnlock()

	// Wait for the stream goroutine to finish; unregister/subscribers
	// observe sub.Stop via Select in their own goroutines.
	<-done
	sub.Stop()
	wg.Wait()
}

func writeMessageStream(w *bufio.Writer, resp Response) error {
	data, err := json.Marshal(resp)
	if err != nil {
		return err
	}
	if _, err := w.Write(append(data, '\n')); err != nil {
		return err
	}
	return w.Flush()
}