import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // ── Config ──────────────────────────────────────────────
    property double latitude:  plasmoid.configuration.latitude  || 40.7128
    property double longitude: plasmoid.configuration.longitude || -74.006
    property string temperatureUnit: plasmoid.configuration.temperatureUnit || "fahrenheit"
    property string windUnit:        plasmoid.configuration.windUnit || "kmh"
    property int    refreshInterval: plasmoid.configuration.refreshInterval || 30
    property string locationLabel:   plasmoid.configuration.locationLabel || ""
    property string fontSize:        plasmoid.configuration.fontSize || "medium"

    property real fontScale: fontSize === "small" ? 0.85 : (fontSize === "large" ? 1.25 : 1.0)

    // ── Weather data ────────────────────────────────────────
    property var currentWeather: ({})
    property var hourlyModel:    []
    property var dailyModel:     []

    property string displayTemp:  "--°"
    property string displayIcon:  "weather-clear"
    property string conditionText: "Loading…"
    property bool   hasData:      false
    property bool   hasError:     false
    property string errorMessage: ""

    // ── WMO weather-code → icon mapping ─────────────────────
    function iconForCode(code, isNight) {
        // WMO codes: https://open-meteo.com/en/docs
        if (code === 0)                     return isNight ? "weather-clear-night"     : "weather-clear"
        if (code >= 1  && code <= 3)       return isNight ? "weather-few-clouds-night" : "weather-few-clouds"
        if (code === 45 || code === 48)     return "weather-fog"
        if (code >= 51 && code <= 55)      return "weather-showers-scattered"
        if (code >= 56 && code <= 57)      return "weather-freezing-rain"
        if (code >= 61 && code <= 65)      return "weather-showers"
        if (code >= 66 && code <= 67)      return "weather-freezing-rain"
        if (code >= 71 && code <= 77)      return "weather-snow"
        if (code >= 80 && code <= 82)      return "weather-showers"
        if (code >= 85 && code <= 86)      return "weather-snow"
        if (code >= 95 && code <= 99)      return "weather-storm"
        return "weather-clouds"
    }

    function conditionTextForCode(code) {
        var map = {
            0: "Clear", 1: "Mostly Clear", 2: "Partly Cloudy", 3: "Overcast",
            45: "Fog", 48: "Depositing Fog",
            51: "Drizzle", 53: "Drizzle", 55: "Drizzle",
            56: "Freezing Drizzle", 57: "Freezing Drizzle",
            61: "Rain", 63: "Rain", 65: "Heavy Rain",
            66: "Freezing Rain", 67: "Freezing Rain",
            71: "Snow", 73: "Snow", 75: "Heavy Snow", 77: "Snow Grains",
            80: "Showers", 81: "Showers", 82: "Heavy Showers",
            85: "Snow Showers", 86: "Snow Showers",
            95: "Thunderstorm", 96: "T-storm w/ Hail", 99: "T-storm w/ Hail"
        }
        return map[code] || "Unknown"
    }

    // ── Temperature helpers ─────────────────────────────────
    function formatTemp(celsius) {
        if (temperatureUnit === "fahrenheit")
            return Math.round(celsius * 9 / 5 + 32) + "°"
        return Math.round(celsius) + "°"
    }

    function formatTempNum(celsius) {
        if (temperatureUnit === "fahrenheit")
            return Math.round(celsius * 9 / 5 + 32)
        return Math.round(celsius)
    }

    function formatWind(kmh) {
        if (windUnit === "mph")
            return Math.round(kmh * 0.621371) + " mph"
        if (windUnit === "ms")
            return Math.round(kmh / 3.6) + " m/s"
        return Math.round(kmh) + " km/h"
    }

    // ── Time helpers ────────────────────────────────────────
    function formatHour(isoString) {
        var d = new Date(isoString)
        var h = d.getHours()
        var ampm = h >= 12 ? "PM" : "AM"
        if (h === 0) return "12AM"
        if (h === 12) return "12PM"
        return (h > 12 ? h - 12 : h) + ampm
    }

    function formatDay(isoString) {
        var d = new Date(isoString)
        var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var today = new Date()
        var tomorrow = new Date(today.getTime() + 86400000)
        if (d.toDateString() === today.toDateString()) return "Today"
        if (d.toDateString() === tomorrow.toDateString()) return "Tomorrow"
        return days[d.getDay()]
    }

    function isNighttime(isoString) {
        var d = new Date(isoString)
        var h = d.getHours()
        return h < 6 || h >= 20
    }

    // ── Timer ───────────────────────────────────────────────
    Timer {
        id: refreshTimer
        interval: root.refreshInterval * 60 * 1000
        running: true
        repeat: true
        onTriggered: fetchWeather()
    }
    onRefreshIntervalChanged: refreshTimer.interval = refreshInterval * 60 * 1000

    Component.onCompleted: fetchWeather()

    // ── Fetch ───────────────────────────────────────────────
    function fetchWeather() {
        var xhr = new XMLHttpRequest()
        var url = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=" + latitude
            + "&longitude=" + longitude
            + "&current=temperature_2m,weather_code,relative_humidity_2m,wind_speed_10m,apparent_temperature"
            + "&hourly=temperature_2m,weather_code,precipitation_probability"
            + "&daily=temperature_2m_max,temperature_2m_min,weather_code,precipitation_probability_max"
            + "&temperature_unit=celsius"
            + "&timezone=auto"
            + "&forecast_days=10"

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    parseResponse(xhr.responseText)
                } else {
                    hasError = true
                    errorMessage = "API error: " + xhr.status
                    displayTemp = "Err"
                }
            }
        }
        xhr.open("GET", url)
        xhr.send()
    }

    function parseResponse(jsonText) {
        try {
            var json = JSON.parse(jsonText)

            // Current
            var cur = json.current
            currentWeather = {
                temp:       cur.temperature_2m,
                feelsLike:  cur.apparent_temperature,
                humidity:   cur.relative_humidity_2m,
                windSpeed:  cur.wind_speed_10m,
                weatherCode: cur.weather_code
            }

            displayTemp = formatTemp(cur.temperature_2m)
            displayIcon = iconForCode(cur.weather_code, isNighttime(cur.time))
            conditionText = conditionTextForCode(cur.weather_code)

            // Hourly
            var hourly = json.hourly
            var hModel = []
            var now = new Date()
            for (var i = 0; i < hourly.time.length; i++) {
                var t = new Date(hourly.time[i])
                if (t < now) continue
                hModel.push({
                    time:     hourly.time[i],
                    hourLabel: formatHour(hourly.time[i]),
                    temp:     formatTempNum(hourly.temperature_2m[i]),
                    icon:     iconForCode(hourly.weather_code[i], isNighttime(hourly.time[i])),
                    code:     hourly.weather_code[i],
                    precip:   hourly.precipitation_probability[i] || 0
                })
                if (hModel.length >= 48) break
            }
            hourlyModel = hModel

            // Daily
            var daily = json.daily
            var dModel = []
            for (var j = 0; j < daily.time.length; j++) {
                dModel.push({
                    time:      daily.time[j],
                    dayLabel:  formatDay(daily.time[j]),
                    high:      formatTempNum(daily.temperature_2m_max[j]),
                    low:       formatTempNum(daily.temperature_2m_min[j]),
                    icon:      iconForCode(daily.weather_code[j], false),
                    code:      daily.weather_code[j],
                    precip:    daily.precipitation_probability_max[j] || 0
                })
            }
            dailyModel = dModel

            hasData = true
            hasError = false
        } catch (e) {
            hasError = true
            errorMessage = "Parse error: " + e
            displayTemp = "Err"
        }
    }

    // ── Representations ─────────────────────────────────────
    compactRepresentation: CompactRepresentation {}
    fullRepresentation:    FullRepresentation {}

    toolTipMainText: conditionText
    toolTipSubText:  displayTemp

    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground
}
