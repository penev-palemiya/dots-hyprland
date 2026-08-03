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
        uv: "--",
        humidity: "--",
        sunrise: "--:--",
        sunset: "--:--",
        windDir: 0,
        wCode: 0,
        city: "City",
        wind: "--",
        windUnit: "km/h",
        windDirArrow: "↑",
        precip: "--",
        precipUnit: "mm",
        visib: "--",
        visibUnit: "km",
        press: "--",
        pressUnit: "hPa",
        temp: "--°",
        tempFeelsLike: "--°",
        lastRefresh: 0,
        conditionText: "Weather",
        current: ({
            temperature: "--°",
            feelsLike: "--°",
            condition: "Weather",
            wCode: 0
        }),
        today: ({
            high: "--°",
            low: "--°",
            precipitationProbability: 0,
            precipitation: "--",
            daylight: "--"
        }),
        hourlyPreview: [],
        insights: ({
            rain: "--",
            comfort: "--",
            uv: "--"
        }),
        details: ({
            wind: "--",
            uv: "--",
            daylight: "--",
            humidity: "--",
            visibility: "--",
            pressure: "--"
        })
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

    function formatTemp(value) {
        return formatNumber(value, 0) + (root.useUSCS ? "°F" : "°C");
    }

    function timeFromApi(timeStr) {
        const date = new Date(timeStr);
        if (Number.isNaN(date.getTime()))
            return "--:--";
        return Qt.locale().toString(date, Config.options?.time.format ?? "hh:mm");
    }

    function conditionText(code) {
        const map = {
            0: "Clear",
            1: "Mostly clear",
            2: "Partly cloudy",
            3: "Cloudy",
            45: "Fog",
            48: "Rime fog",
            51: "Light drizzle",
            53: "Drizzle",
            55: "Heavy drizzle",
            56: "Freezing drizzle",
            57: "Heavy freezing drizzle",
            61: "Light rain",
            63: "Rain",
            65: "Heavy rain",
            66: "Freezing rain",
            67: "Heavy freezing rain",
            71: "Light snow",
            73: "Snow",
            75: "Heavy snow",
            77: "Snow grains",
            80: "Light showers",
            81: "Showers",
            82: "Heavy showers",
            85: "Snow showers",
            86: "Heavy snow showers",
            95: "Thunderstorm",
            96: "Thunderstorm with hail",
            99: "Severe thunderstorm"
        };
        return Translation.tr(map[Number(code)] ?? "Cloudy");
    }

    function rainSummary(probability, amount) {
        const chance = formatNumber(probability, 0);
        const precip = formatNumber(amount, root.useUSCS ? 2 : 1);
        if (chance >= 70)
            return Translation.tr("Rain likely");
        if (chance >= 35)
            return Translation.tr("%1% chance").arg(chance);
        if (precip > 0)
            return `${precip} ${Translation.tr(root.useUSCS ? "in" : "mm")}`;
        return Translation.tr("Rain unlikely");
    }

    function comfortSummary(apparent, humidity, windSpeed, uvIndex) {
        const feels = Number(apparent);
        const humid = Number(humidity);
        const wind = Number(windSpeed);
        const uv = Number(uvIndex);
        if (uv >= 7)
            return Translation.tr("High UV compact");
        if (root.useUSCS ? feels >= 86 : feels >= 30)
            return humid >= 65 ? Translation.tr("Hot and humid compact") : Translation.tr("Feels hot compact");
        if (root.useUSCS ? feels <= 41 : feels <= 5)
            return wind >= (root.useUSCS ? 16 : 25) ? Translation.tr("Cold wind compact") : Translation.tr("Feels cold compact");
        if (wind >= (root.useUSCS ? 22 : 35))
            return Translation.tr("Windy");
        if (humid >= 75)
            return Translation.tr("Humid");
        return Translation.tr("Comfortable");
    }

    function daylightDuration(sunrise, sunset) {
        const start = new Date(sunrise);
        const end = new Date(sunset);
        const diffMs = end.getTime() - start.getTime();
        if (!Number.isFinite(diffMs) || diffMs <= 0)
            return "";
        const minutes = Math.round(diffMs / 60000);
        return Translation.tr("%1h %2m").arg(Math.floor(minutes / 60)).arg(minutes % 60);
    }

    function buildHourlyPreview(hourly, count) {
        let preview = [];
        const times = hourly?.time ?? [];
        const temps = hourly?.temperature_2m ?? [];
        const codes = hourly?.weather_code ?? [];
        const probs = hourly?.precipitation_probability ?? [];
        for (let i = 0; i < Math.min(count, times.length); i++) {
            preview.push({
                time: timeFromApi(times[i]),
                temp: formatTemp(temps[i] ?? 0),
                wCode: codes[i] ?? 0,
                precipProbability: formatNumber(probs[i] ?? 0, 0)
            });
        }
        return preview;
    }

    function refineData(data) {
        let temp = {};
        const current = data?.current ?? {};
        const daily = data?.daily ?? {};
        const hourly = data?.hourly ?? {};
        const humidity = formatNumber(current?.relative_humidity_2m ?? 0, 0);
        const uv = formatNumber(hourly?.uv_index?.[0] ?? daily?.uv_index_max?.[0] ?? 0, 1);
        const precipProbability = formatNumber(daily?.precipitation_probability_max?.[0] ?? hourly?.precipitation_probability?.[0] ?? 0, 0);
        const precipSum = formatNumber(daily?.precipitation_sum?.[0] ?? current?.precipitation ?? 0, root.useUSCS ? 2 : 1);
        const weatherCode = current?.weather_code ?? daily?.weather_code?.[0] ?? 0;
        const sunrise = daily?.sunrise?.[0];
        const sunset = daily?.sunset?.[0];
        temp.uv = uv;
        temp.humidity = humidity + "%";
        temp.sunrise = formatApiTime(sunrise);
        temp.sunset = formatApiTime(sunset);
        temp.windDir = formatNumber(current?.wind_direction_10m ?? 0, 0);
        temp.windDirArrow = windDirToArrow(temp.windDir);
        temp.wCode = weatherCode;
        temp.city = data?.location?.name || root.city || "City";
        temp.conditionText = conditionText(weatherCode);
        if (root.useUSCS) {
            temp.wind = formatNumber(current?.wind_speed_10m ?? 0, 0);
            temp.windUnit = "mph";
            temp.precip = precipSum;
            temp.precipUnit = "in";
            temp.visib = formatNumber((hourly?.visibility?.[0] ?? 0) / 1609.344, 1);
            temp.visibUnit = "mi";
            temp.press = formatNumber((current?.pressure_msl ?? 0) * 0.02953, 2);
            temp.pressUnit = "inHg";
        } else {
            temp.wind = formatNumber(current?.wind_speed_10m ?? 0, 0);
            temp.windUnit = "km/h";
            temp.precip = precipSum;
            temp.precipUnit = "mm";
            temp.visib = formatNumber((hourly?.visibility?.[0] ?? 0) / 1000, 1);
            temp.visibUnit = "km";
            temp.press = formatNumber(current?.pressure_msl ?? 0, 0);
            temp.pressUnit = "hPa";
        }
        temp.temp = formatTemp(current?.temperature_2m ?? 0);
        temp.tempFeelsLike = formatTemp(current?.apparent_temperature ?? 0);
        temp.current = {
            temperature: temp.temp,
            feelsLike: temp.tempFeelsLike,
            condition: temp.conditionText,
            wCode: weatherCode
        };
        temp.today = {
            high: formatTemp(daily?.temperature_2m_max?.[0] ?? current?.temperature_2m ?? 0),
            low: formatTemp(daily?.temperature_2m_min?.[0] ?? current?.temperature_2m ?? 0),
            precipitationProbability: precipProbability,
            precipitation: precipSum,
            daylight: daylightDuration(sunrise, sunset)
        };
        temp.hourlyPreview = buildHourlyPreview(hourly, 6);
        temp.insights = {
            rain: rainSummary(precipProbability, precipSum),
            comfort: comfortSummary(current?.apparent_temperature ?? 0, humidity, current?.wind_speed_10m ?? 0, uv),
            uv: uv >= 7 ? Translation.tr("High") : uv >= 3 ? Translation.tr("Moderate") : Translation.tr("Low")
        };
        temp.details = {
            wind: `${temp.windDirArrow} ${temp.wind} ${Translation.tr(temp.windUnit)}`,
            uv: `${uv} • ${temp.insights.uv}`,
            daylight: temp.today.daylight.length > 0 ? `${temp.sunrise} - ${temp.sunset}` : `${temp.sunrise} / ${temp.sunset}`,
            humidity: temp.humidity,
            visibility: `${temp.visib} ${Translation.tr(temp.visibUnit)}`,
            pressure: `${temp.press} ${Translation.tr(temp.pressUnit)}`
        };
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
  --data "hourly=temperature_2m,weather_code,precipitation_probability,uv_index,visibility" \\
  --data "daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_probability_max,precipitation_sum" \\
  --data "forecast_hours=6" \\
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
