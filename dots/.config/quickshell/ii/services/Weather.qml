pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import QtPositioning

import qs.modules.common

Singleton {
    id: root
    // 10 minute
    readonly property int fetchInterval: Config.options.bar.weather.fetchInterval * 60 * 1000
    readonly property string city: Config.options.bar.weather.city
    readonly property bool useUSCS: Config.options.bar.weather.useUSCS
    property bool gpsActive: Config.options.bar.weather.enableGPS

    onUseUSCSChanged: {
        root.getData();
    }
    onCityChanged: {
        root.getData();
    }

    property var location: ({
        valid: false,
        lat: 0,
        lon: 0
    })

    property var data: ({
        uv: 0,
        humidity: 0,
        sunrise: 0,
        sunset: 0,
        windDir: 0,
        wCode: 0,
        city: 0,
        wind: 0,
        windUnit: "km/h",
        windDirArrow: "↑",
        precip: 0,
        precipUnit: "mm",
        visib: 0,
        visibUnit: "km",
        press: 0,
        pressUnit: "hPa",
        temp: 0,
        tempFeelsLike: 0,
        lastRefresh: 0,
    })

    function windDirToArrow(dir) {
        const normalized = Number(dir);
        if (!Number.isFinite(normalized))
            return "→";
        const arrows = ["↑", "↗", "→", "↘", "↓", "↙", "←", "↖"];
        return arrows[Math.round((((normalized % 360) + 360) % 360) / 45) % 8];
    }

    function formatApiTime(timeStr) {
        const date = new Date(timeStr);
        if (Number.isNaN(date.getTime()))
            return timeStr || "--:--";
        return Qt.locale().toString(date, Config.options?.time.format ?? "hh:mm");
    }

    function formatNumber(value, digits) {
        const parsed = Number(value);
        if (!Number.isFinite(parsed))
            return 0;
        return Number(parsed.toFixed(digits));
    }

    function refineData(data) {
        let temp = {};
        const current = data?.current ?? {};
        const daily = data?.daily ?? {};
        const hourly = data?.hourly ?? {};
        temp.uv = formatNumber(hourly?.uv_index?.[0] ?? daily?.uv_index_max?.[0] ?? 0, 1);
        temp.humidity = formatNumber(current?.relative_humidity_2m ?? 0, 0) + "%";
        temp.sunrise = formatApiTime(daily?.sunrise?.[0]);
        temp.sunset = formatApiTime(daily?.sunset?.[0]);
        temp.windDir = formatNumber(current?.wind_direction_10m ?? 0, 0);
        temp.windDirArrow = windDirToArrow(temp.windDir);
        temp.wCode = current?.weather_code ?? 0;
        temp.city = data?.location?.name || root.city || "City";
        temp.temp = "";
        temp.tempFeelsLike = "";
        if (root.useUSCS) {
            temp.wind = formatNumber(current?.wind_speed_10m ?? 0, 0);
            temp.windUnit = "mph";
            temp.precip = formatNumber(current?.precipitation ?? 0, 2);
            temp.precipUnit = "in";
            temp.visib = formatNumber((hourly?.visibility?.[0] ?? 0) / 1609.344, 1);
            temp.visibUnit = "mi";
            temp.press = formatNumber((current?.pressure_msl ?? 0) * 0.02953, 2);
            temp.pressUnit = "inHg";
            temp.temp += formatNumber(current?.temperature_2m ?? 0, 0);
            temp.tempFeelsLike += formatNumber(current?.apparent_temperature ?? 0, 0);
            temp.temp += "°F";
            temp.tempFeelsLike += "°F";
        } else {
            temp.wind = formatNumber(current?.wind_speed_10m ?? 0, 0);
            temp.windUnit = "km/h";
            temp.precip = formatNumber(current?.precipitation ?? 0, 1);
            temp.precipUnit = "mm";
            temp.visib = formatNumber((hourly?.visibility?.[0] ?? 0) / 1000, 1);
            temp.visibUnit = "km";
            temp.press = formatNumber(current?.pressure_msl ?? 0, 0);
            temp.pressUnit = "hPa";
            temp.temp += formatNumber(current?.temperature_2m ?? 0, 0);
            temp.tempFeelsLike += formatNumber(current?.apparent_temperature ?? 0, 0);
            temp.temp += "°C";
            temp.tempFeelsLike += "°C";
        }
        temp.lastRefresh = DateTime.time + " • " + DateTime.date;
        root.data = temp;
    }

    function getData() {
        const useGpsLocation = root.gpsActive && root.location.valid;
        const cityName = root.city.trim();
        if (!useGpsLocation && cityName.length === 0) {
            console.error("[WeatherService] Weather city is empty and GPS location is unavailable.");
            return;
        }

        const tempUnit = root.useUSCS ? "fahrenheit" : "celsius";
        const windUnit = root.useUSCS ? "mph" : "kmh";
        const precipUnit = root.useUSCS ? "inch" : "mm";
        const geocodeLang = (Translation.languageCode || Qt.locale().name || "en").split("_")[0];
        const escapedCity = shellQuote(cityName);
        let command = `
set -euo pipefail
city=${escapedCity}
geocode_lang=${shellQuote(geocodeLang)}
if ${useGpsLocation ? "true" : "false"}; then
  lat=${shellQuote(root.location.lat)}
  lon=${shellQuote(root.location.lon)}
  location_name="$city"
else
  geo=$(curl -fsSL --max-time 8 --get \\
    --data-urlencode "name=$city" \\
    --data "count=1" \\
    --data-urlencode "language=$geocode_lang" \\
    --data "format=json" \\
    "https://geocoding-api.open-meteo.com/v1/search")
  lat=$(printf '%s' "$geo" | jq -r '.results[0].latitude // empty')
  lon=$(printf '%s' "$geo" | jq -r '.results[0].longitude // empty')
  location_name=$(printf '%s' "$geo" | jq -r '.results[0].name // empty')
  if test -z "$lat" -o -z "$lon"; then
    geo=$(curl -fsSL --max-time 8 --get \\
      --data-urlencode "name=$city" \\
      --data "count=1" \\
      --data "language=en" \\
      --data "format=json" \\
      "https://geocoding-api.open-meteo.com/v1/search")
    lat=$(printf '%s' "$geo" | jq -r '.results[0].latitude // empty')
    lon=$(printf '%s' "$geo" | jq -r '.results[0].longitude // empty')
    location_name=$(printf '%s' "$geo" | jq -r '.results[0].name // empty')
  fi
  test -n "$lat" -a -n "$lon"
fi

curl -fsSL --max-time 10 --get \\
  --data-urlencode "latitude=$lat" \\
  --data-urlencode "longitude=$lon" \\
  --data "timezone=auto" \\
  --data "temperature_unit=${tempUnit}" \\
  --data "wind_speed_unit=${windUnit}" \\
  --data "precipitation_unit=${precipUnit}" \\
  --data "current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,pressure_msl,wind_speed_10m,wind_direction_10m" \\
  --data "hourly=uv_index,visibility" \\
  --data "daily=sunrise,sunset,uv_index_max" \\
  --data "forecast_hours=1" \\
  "https://api.open-meteo.com/v1/forecast" \\
  | jq --arg name "$location_name" '. + {location: {name: ($name // "")}}'
`;
        fetcher.command = ["bash", "-lc", command];
        fetcher.running = true;
    }

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    Component.onCompleted: {
        if (!root.gpsActive) return;
        console.info("[WeatherService] Starting the GPS service.");
        positionSource.start();
    }

    Process {
        id: fetcher
        command: ["bash", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0)
                    return;
                try {
                    const parsedData = JSON.parse(text);
                    root.refineData(parsedData);
                    // console.info(`[ data: ${JSON.stringify(parsedData)}`);
                } catch (e) {
                    console.error(`[WeatherService] ${e.message}`);
                }
            }
        }
    }

    PositionSource {
        id: positionSource
        updateInterval: root.fetchInterval

        onPositionChanged: {
            // update the location if the given location is valid
            // if it fails getting the location, use the last valid location
            if (position.latitudeValid && position.longitudeValid) {
                root.location.lat = position.coordinate.latitude;
                root.location.lon = position.coordinate.longitude;
                root.location.valid = true;
                // console.info(`📍 Location: ${position.coordinate.latitude}, ${position.coordinate.longitude}`);
                root.getData();
                // if can't get initialized with valid location deactivate the GPS
            } else {
                root.gpsActive = root.location.valid ? true : false;
                console.error("[WeatherService] Failed to get the GPS location.");
            }
        }

        onValidityChanged: {
            if (!positionSource.valid) {
                positionSource.stop();
                root.location.valid = false;
                root.gpsActive = false;
                Quickshell.execDetached(["notify-send", Translation.tr("Weather Service"), Translation.tr("Cannot find a GPS service. Using the fallback method instead."), "-a", "Shell"]);
                console.error("[WeatherService] Could not aquire a valid backend plugin.");
            }
        }
    }

    Timer {
        running: !root.gpsActive
        repeat: true
        interval: root.fetchInterval
        triggeredOnStart: !root.gpsActive
        onTriggered: root.getData()
    }
}
