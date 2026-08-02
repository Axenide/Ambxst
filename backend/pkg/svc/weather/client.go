package weather

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

const (
	openMeteoForecast = "https://api.open-meteo.com/v1/forecast"
	openMeteoGeo      = "https://geocoding-api.open-meteo.com/v1/search"
	ipapiGeo          = "https://ipapi.co/json/"
)

// WeatherResponse mirrors the open-meteo payload consumed by WeatherService.qml.
type WeatherResponse struct {
	Error          string        `json:"error,omitempty"`
	CurrentWeather *CurrentWeather `json:"current_weather"`
	Daily          *Daily        `json:"daily"`
}

type CurrentWeather struct {
	Temperature float64 `json:"temperature"`
	Windspeed   float64 `json:"windspeed"`
	Weathercode int     `json:"weathercode"`
	Time        string  `json:"time"`
}

type Daily struct {
	Time               []string `json:"time"`
	Weathercode        []int    `json:"weathercode"`
	Temperature2mMax   []float64 `json:"temperature_2m_max"`
	Temperature2mMin   []float64 `json:"temperature_2m_min"`
	Sunrise            []string `json:"sunrise"`
	Sunset             []string `json:"sunset"`
}

// Client performs weather fetches for a given location.
type Client struct {
	http *http.Client
}

func NewClient() *Client {
	return &Client{http: &http.Client{Timeout: 20 * time.Second}}
}

// Fetch retrieves weather for a location (city name, "lat,lon", or empty for GeoIP).
func (c *Client) Fetch(location string) (*WeatherResponse, error) {
	lat, lon, err := c.resolveCoords(location)
	if err != nil {
		return &WeatherResponse{Error: err.Error()}, nil
	}

	params := url.Values{}
	params.Set("latitude", fmt.Sprintf("%v", lat))
	params.Set("longitude", fmt.Sprintf("%v", lon))
	params.Set("current_weather", "true")
	params.Set("daily", "temperature_2m_max,temperature_2m_min,sunrise,sunset,weathercode")
	params.Set("timezone", "auto")
	params.Set("forecast_days", "7")

	resp, err := c.httpGet(openMeteoForecast + "?" + params.Encode())
	if err != nil {
		return &WeatherResponse{Error: err.Error()}, nil
	}
	return resp, nil
}

func (c *Client) resolveCoords(location string) (float64, float64, error) {
	loc := strings.TrimSpace(location)
	if loc == "" {
		coords, err := c.geoip()
		return parseCoords(coords, err)
	}
	if isCoords(loc) {
		return parseCoords(loc, nil)
	}
	coords, err := c.geocode(loc)
	return parseCoords(coords, err)
}

func (c *Client) geoip() (string, error) {
	var data struct {
		Latitude  float64 `json:"latitude"`
		Longitude float64 `json:"longitude"`
		Error     string  `json:"error"`
	}
	if err := c.getJSON(ipapiGeo, &data); err != nil {
		return "", err
	}
	if data.Error != "" {
		return "", fmt.Errorf("geoip: %s", data.Error)
	}
	return fmt.Sprintf("%v,%v", data.Latitude, data.Longitude), nil
}

func (c *Client) geocode(city string) (string, error) {
	var data struct {
		Results []struct {
			Latitude  float64 `json:"latitude"`
			Longitude float64 `json:"longitude"`
		} `json:"results"`
		Error string `json:"error"`
	}
	u := openMeteoGeo + "?name=" + url.QueryEscape(city)
	if err := c.getJSON(u, &data); err != nil {
		return "", err
	}
	if data.Error != "" {
		return "", fmt.Errorf("geocoding: %s", data.Error)
	}
	if len(data.Results) == 0 {
		return "", fmt.Errorf("city not found")
	}
	return fmt.Sprintf("%v,%v", data.Results[0].Latitude, data.Results[0].Longitude), nil
}

func (c *Client) httpGet(rawurl string) (*WeatherResponse, error) {
	var resp WeatherResponse
	data, err := c.get(rawurl)
	if err != nil {
		return nil, err
	}
	if len(data) == 0 || string(data) == "null" {
		return nil, fmt.Errorf("empty response")
	}
	// open-meteo signals errors with {"error":true,"reason":"..."}.
	var apiErr struct {
		Error  bool   `json:"error"`
		Reason string `json:"reason"`
	}
	if json.Unmarshal(data, &apiErr) == nil && apiErr.Error {
		return nil, fmt.Errorf("weather api: %s", apiErr.Reason)
	}
	if err := json.Unmarshal(data, &resp); err != nil {
		return nil, err
	}
	if resp.CurrentWeather == nil || resp.Daily == nil {
		return nil, fmt.Errorf("invalid response structure")
	}
	return &resp, nil
}

func (c *Client) getJSON(rawurl string, dest any) error {
	data, err := c.get(rawurl)
	if err != nil {
		return err
	}
	return json.Unmarshal(data, dest)
}

func (c *Client) get(rawurl string) ([]byte, error) {
	var lastErr error
	for attempt := 0; attempt < 3; attempt++ {
		resp, err := c.http.Get(rawurl)
		if err != nil {
			lastErr = err
			time.Sleep(2 * time.Second)
			continue
		}
		body, err := io.ReadAll(resp.Body)
		resp.Body.Close()
		if err != nil {
			lastErr = err
			continue
		}
		if len(body) == 0 || string(body) == "null" {
			lastErr = fmt.Errorf("non-empty response")
			time.Sleep(2 * time.Second)
			continue
		}
		return body, nil
	}
	return nil, lastErr
}

func isCoords(s string) bool {
	parts := strings.Split(s, ",")
	if len(parts) != 2 {
		return false
	}
	_, err1 := floatParse(parts[0])
	_, err2 := floatParse(parts[1])
	return err1 == nil && err2 == nil
}

func parseCoords(s string, err error) (float64, float64, error) {
	if err != nil {
		return 0, 0, err
	}
	parts := strings.Split(s, ",")
	if len(parts) != 2 {
		return 0, 0, fmt.Errorf("invalid coords: %s", s)
	}
	lat, e1 := floatParse(parts[0])
	lon, e2 := floatParse(parts[1])
	if e1 != nil || e2 != nil {
		return 0, 0, fmt.Errorf("invalid coords: %s", s)
	}
	return lat, lon, nil
}

func floatParse(s string) (float64, error) {
	var f float64
	if _, err := fmt.Sscanf(s, "%g", &f); err != nil {
		return 0, err
	}
	return f, nil
}