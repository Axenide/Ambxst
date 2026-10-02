package weather

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/godbus/dbus/v5"
)

const (
	openMeteoForecast = "https://api.open-meteo.com/v1/forecast"
	openMeteoGeo      = "https://geocoding-api.open-meteo.com/v1/search"
	ipapiGeo          = "http://ip-api.com/json/"
)

// WeatherResponse mirrors the open-meteo payload consumed by WeatherService.qml.
type WeatherResponse struct {
	Error          string          `json:"error,omitempty"`
	CurrentWeather *CurrentWeather `json:"current_weather"`
	Daily          *Daily          `json:"daily"`
}

type CurrentWeather struct {
	Temperature float64 `json:"temperature"`
	Windspeed   float64 `json:"windspeed"`
	Weathercode int     `json:"weathercode"`
	Time        string  `json:"time"`
}

type Daily struct {
	Time             []string  `json:"time"`
	Weathercode      []int     `json:"weathercode"`
	Temperature2mMax []float64 `json:"temperature_2m_max"`
	Temperature2mMin []float64 `json:"temperature_2m_min"`
	Sunrise          []string  `json:"sunrise"`
	Sunset           []string  `json:"sunset"`
}

// Client performs weather fetches for a given location.
type Client struct {
	http *http.Client
}

func NewClient() *Client {
	return &Client{http: &http.Client{Timeout: 20 * time.Second}}
}

// Fetch retrieves weather for a location (city name, "lat,lon", or empty for
// the system location service with GeoIP fallback).
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
		// Prefer the desktop's location provider. GeoClue can use an actual
		// GNSS device when available and otherwise uses the system's permitted
		// network/Wi-Fi location sources. Keep GeoIP as a fallback for systems
		// without GeoClue or without a location permission.
		coords, err := c.deviceLocation()
		if err != nil {
			log.Printf("weather: GeoClue unavailable (%v); falling back to GeoIP", err)
			coords, err = c.geoip()
		} else {
			log.Printf("weather: using GeoClue device location")
		}
		return parseCoords(coords, err)
	}
	if isCoords(loc) {
		return parseCoords(loc, nil)
	}
	coords, err := c.geocode(loc)
	return parseCoords(coords, err)
}

// deviceLocation reads the current position from GeoClue2 over the system
// D-Bus. GeoClue is intentionally queried only for automatic weather mode;
// manually entered locations never access device location services.
func (c *Client) deviceLocation() (string, error) {
	conn, err := dbus.SystemBus()
	if err != nil {
		return "", fmt.Errorf("geoclue bus: %w", err)
	}
	defer conn.Close()

	manager := conn.Object("org.freedesktop.GeoClue2", "/org/freedesktop/GeoClue2/Manager")
	var clientPath dbus.ObjectPath
	if err := manager.Call("org.freedesktop.GeoClue2.Manager.GetClient", 0).Store(&clientPath); err != nil {
		return "", fmt.Errorf("geoclue client: %w", err)
	}

	client := conn.Object("org.freedesktop.GeoClue2", clientPath)
	if err := client.Call("org.freedesktop.GeoClue2.Client.SetDesktopId", 0, "ambxst").Err; err != nil {
		return "", fmt.Errorf("geoclue desktop id: %w", err)
	}
	defer client.Call("org.freedesktop.GeoClue2.Client.Stop", 0)
	if err := client.Call("org.freedesktop.GeoClue2.Client.Start", 0).Err; err != nil {
		return "", fmt.Errorf("geoclue start: %w", err)
	}

	locationVariant, err := client.GetProperty("org.freedesktop.GeoClue2.Client.Location")
	if err != nil {
		return "", fmt.Errorf("geoclue location: %w", err)
	}
	locationPath, ok := locationVariant.Value().(dbus.ObjectPath)
	if !ok || locationPath == "/" {
		return "", fmt.Errorf("geoclue has no current location")
	}

	location := conn.Object("org.freedesktop.GeoClue2", locationPath)
	latitude, err := location.GetProperty("org.freedesktop.GeoClue2.Location.Latitude")
	if err != nil {
		return "", fmt.Errorf("geoclue latitude: %w", err)
	}
	longitude, err := location.GetProperty("org.freedesktop.GeoClue2.Location.Longitude")
	if err != nil {
		return "", fmt.Errorf("geoclue longitude: %w", err)
	}
	lat, latOK := latitude.Value().(float64)
	lon, lonOK := longitude.Value().(float64)
	if !latOK || !lonOK {
		return "", fmt.Errorf("geoclue returned invalid coordinates")
	}
	return fmt.Sprintf("%v,%v", lat, lon), nil
}

func (c *Client) geoip() (string, error) {
	var data struct {
		Status    string  `json:"status"`
		Message   string  `json:"message"`
		Latitude  float64 `json:"lat"`
		Longitude float64 `json:"lon"`
	}
	if err := c.getJSON(ipapiGeo, &data); err != nil {
		return "", err
	}
	if data.Status != "success" {
		msg := data.Message
		if msg == "" {
			msg = "could not determine location"
		}
		return "", fmt.Errorf("geoip: %s", msg)
	}
	return fmt.Sprintf("%v,%v", data.Latitude, data.Longitude), nil
}

func (c *Client) geocode(city string) (string, error) {
	var data struct {
		Results []struct {
			Latitude  float64 `json:"latitude"`
			Longitude float64 `json:"longitude"`
		} `json:"results"`
		Error json.RawMessage `json:"error"`
	}
	u := openMeteoGeo + "?name=" + url.QueryEscape(city)
	if err := c.getJSON(u, &data); err != nil {
		return "", err
	}
	if len(data.Error) > 0 && string(data.Error) != "false" {
		return "", fmt.Errorf("geocoding: %s", strings.Trim(string(data.Error), `"`))
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
