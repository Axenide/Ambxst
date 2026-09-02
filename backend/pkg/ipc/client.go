package ipc

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net"
)

// Client is a request/response client over the daemon socket.
type Client struct {
	path string
}

func NewClient(path string) *Client {
	return &Client{path: path}
}

// Call sends a method request and returns the raw result payload.
func (c *Client) Call(method string, params any) (json.RawMessage, error) {
	conn, err := net.Dial("unix", c.path)
	if err != nil {
		return nil, fmt.Errorf("connect to %s: %w", c.path, err)
	}
	defer conn.Close()

	req := struct {
		ID     int            `json:"id"`
		Method string         `json:"method"`
		Params map[string]any `json:"params,omitempty"`
	}{
		ID:     1,
		Method: method,
	}
	if params != nil {
		switch v := params.(type) {
		case map[string]any:
			req.Params = v
		default:
			data, _ := json.Marshal(params)
			req.Params = map[string]any{}
			var m map[string]any
			if json.Unmarshal(data, &m) == nil {
				req.Params = m
			}
		}
	}
	data, err := json.Marshal(req)
	if err != nil {
		return nil, err
	}
	data = append(data, '\n')
	if _, err := conn.Write(data); err != nil {
		return nil, err
	}

	line, err := bufio.NewReader(conn).ReadBytes('\n')
	if err != nil {
		return nil, err
	}
	var resp Response
	if err := json.Unmarshal(line, &resp); err != nil {
		return nil, err
	}
	if resp.Error != "" {
		return nil, fmt.Errorf("%s", resp.Error)
	}
	return resp.Result, nil
}

// CallFireAndForget sends a request without waiting for the response.
// Used by short-lived CLI dispatch where the daemon responds on a different
// path; we still read the response to keep the connection deterministic.
func (c *Client) CallFireAndForget(method string, params any) error {
	conn, err := net.Dial("unix", c.path)
	if err != nil {
		return err
	}
	defer conn.Close()

	payload := map[string]any{
		"jsonrpc": "2.0",
		"method":  method,
	}
	if params != nil {
		data, _ := json.Marshal(params)
		var m map[string]any
		if json.Unmarshal(data, &m) == nil {
			payload["params"] = m
		}
	}
	data, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	data = append(data, '\n')
	_, err = conn.Write(data)
	return err
}