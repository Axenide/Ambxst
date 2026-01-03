#!/bin/bash

# Weather fetching script for Ambxst
# Usage: weather.sh [location]
# If no location is provided, uses GeoIP to determine location
# Output: JSON with weather data or error

LOCATION="${1:-}"
MAX_RETRIES=3
RETRY_DELAY=2

# Function to make HTTP request with retries
http_get() {
	local url="$1"
	local attempt=1
	local response=""

	while [[ $attempt -le $MAX_RETRIES ]]; do
		response=$(curl -s --max-time 15 --retry 2 --retry-delay 1 "$url" 2>/dev/null)
		if [[ -n "$response" && "$response" != "null" ]]; then
			echo "$response"
			return 0
		fi
		attempt=$((attempt + 1))
		sleep $RETRY_DELAY
	done

	return 1
}

# Function to get coordinates from GeoIP
get_geoip_coords() {
	local response
	response=$(http_get "https://ipapi.co/json/")

	if [[ -z "$response" ]]; then
		echo '{"error": "GeoIP request failed"}'
		return 1
	fi

	local lat lon
	lat=$(echo "$response" | jq -r '.latitude // empty')
	lon=$(echo "$response" | jq -r '.longitude // empty')

	if [[ -z "$lat" || -z "$lon" ]]; then
		echo '{"error": "Could not determine location from GeoIP"}'
		return 1
	fi

	echo "$lat,$lon"
}

# Function to geocode a city name
geocode_city() {
	local city="$1"
	local encoded_city
	encoded_city=$(echo -n "$city" | jq -sRr @uri)

	local response
	response=$(http_get "https://geocoding-api.open-meteo.com/v1/search?name=${encoded_city}")

	if [[ -z "$response" ]]; then
		echo '{"error": "Geocoding request failed"}'
		return 1
	fi

	local lat lon
	lat=$(echo "$response" | jq -r '.results[0].latitude // empty')
	lon=$(echo "$response" | jq -r '.results[0].longitude // empty')

	if [[ -z "$lat" || -z "$lon" ]]; then
		echo '{"error": "City not found"}'
		return 1
	fi

	echo "$lat,$lon"
}

# Function to fetch weather data
fetch_weather() {
	local lat="$1"
	local lon="$2"

	local url="https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current_weather=true&daily=temperature_2m_max,temperature_2m_min,sunrise,sunset,weathercode&timezone=auto&forecast_days=7"

	local response
	response=$(http_get "$url")

	if [[ -z "$response" ]]; then
		echo '{"error": "Weather API request failed"}'
		return 1
	fi

	# Validate response has required fields
	local has_current has_daily
	has_current=$(echo "$response" | jq -r '.current_weather // empty')
	has_daily=$(echo "$response" | jq -r '.daily // empty')

	if [[ -z "$has_current" || -z "$has_daily" ]]; then
		echo '{"error": "Invalid weather API response"}'
		return 1
	fi

	echo "$response"
}

# Main logic
main() {
	local coords lat lon

	if [[ -z "$LOCATION" ]]; then
		# No location provided, use GeoIP
		coords=$(get_geoip_coords)
		if [[ "$coords" == "{"* ]]; then
			# It's an error JSON
			echo "$coords"
			exit 1
		fi
	elif [[ "$LOCATION" =~ ^-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*$ ]]; then
		# Location is coordinates (lat,lon)
		coords="$LOCATION"
	else
		# Location is a city name, geocode it
		coords=$(geocode_city "$LOCATION")
		if [[ "$coords" == "{"* ]]; then
			# It's an error JSON
			echo "$coords"
			exit 1
		fi
	fi

	# Split coordinates
	lat="${coords%,*}"
	lon="${coords#*,}"

	# Fetch and output weather
	fetch_weather "$lat" "$lon"
}

main
