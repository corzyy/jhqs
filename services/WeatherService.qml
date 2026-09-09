pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."
import "WeatherModel.js" as WeatherModel

Singleton {
    id: root

    FileView {
        id: locationFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/config/weather.json"
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.configuredLocationState = WeatherModel.parseLocationFile(text())
        onLoadFailed: root.configuredLocationState = WeatherModel.parseLocationFile("")
        adapter: JsonAdapter {
            property string name: ""
            property double latitude: 0
            property double longitude: 0
            property bool hasCoords: false
            property string unit: ""
            property int refreshMinutes: 15
            property bool showLabel: true
        }
    }
    Timer { interval: 1500; running: true; repeat: false; onTriggered: locationFile.reload() }

    function setUnit(u: string): string {
        let v = (u || "").trim().toLowerCase()
        if (v === "auto") v = ""
        if (v !== "" && v !== "metric" && v !== "imperial") return "usage: unit auto|metric|imperial"
        if (locationFile.adapter.unit === v) return "unit=" + (v === "" ? "auto" : v)
        locationFile.adapter.unit = v
        locationFile.writeAdapter()
        return "unit=" + (v === "" ? "auto" : v)
    }
    function setRefreshMinutes(n: int): string {
        let c = Math.max(1, Math.min(120, Math.round(n)))
        if (isNaN(c)) return "usage: setRefreshMinutes <1-120>"
        if (locationFile.adapter.refreshMinutes === c) return "refreshMinutes=" + c
        locationFile.adapter.refreshMinutes = c
        locationFile.writeAdapter()
        return "refreshMinutes=" + c
    }

    property var report: null
    property var dailyForecastReport: null
    property string wttrLocation: ""
    property date lastUpdated: new Date(0)
    readonly property string updatedLabel: lastUpdated.getTime() > 0 ? Qt.formatDateTime(lastUpdated, "HH:mm") : ""

    property var configuredLocationState: ({ name: "", latitude: null, longitude: null })
    readonly property string configuredLocation: configuredLocationState.name
    readonly property string locationQuery: WeatherModel.wttrLocationQuery(configuredLocationState.name, configuredLocationState.latitude, configuredLocationState.longitude)

    onLocationQueryChanged: {
        if (savingLocation) savingLocationQueryStarted = true
        forecastRetries = 0
        dailyForecastRetries = 0
        forecastProc.running = false
        dailyForecastProc.running = false
        Qt.callLater(refresh)
    }

    property int forecastRetries: 0
    property int dailyForecastRetries: 0

    property bool editingLocation: false
    property bool savingLocation: false
    property bool savingLocationQueryStarted: false
    property var locationSuggestions: []
    property int suggestionIndex: 0
    property string geocodePendingQuery: ""
    property string geocodeActiveQuery: ""

    property string label: ""
    readonly property bool hasData: current !== null && current !== undefined
    readonly property bool hasConfiguredCoordinates: !isNaN(parseFloat(String(configuredLocationState.latitude))) && !isNaN(parseFloat(String(configuredLocationState.longitude)))
    readonly property var openMeteoCurrent: WeatherModel.openMeteoCurrentCondition(dailyForecastReport)
    readonly property var current: (hasConfiguredCoordinates && openMeteoCurrent) ? openMeteoCurrent : ((report && report.current_condition && report.current_condition[0]) ? report.current_condition[0] : openMeteoCurrent)
    readonly property var areaInfo: report && report.nearest_area && report.nearest_area[0] ? report.nearest_area[0] : null
    readonly property var forecastDays: buildForecastDays()
    readonly property string reportCountry: areaInfo && areaInfo.country && areaInfo.country[0] ? areaInfo.country[0].value : ""
    readonly property bool useImperial: WeatherModel.shouldUseImperial(locationFile.adapter.unit, Qt.locale().name, reportCountry)
    readonly property int refreshMinutes: Math.max(1, parseInt(locationFile.adapter.refreshMinutes, 10) || 15)
    readonly property bool showLabel: locationFile.adapter.showLabel !== false
    function setShowLabel(v: bool): void {
        let nv = !!v
        if ((locationFile.adapter.showLabel !== false) === nv) return
        locationFile.adapter.showLabel = nv
        locationFile.writeAdapter()
    }
    readonly property string cityName: configuredLocation
    readonly property string unitName: {
        let u = (locationFile.adapter.unit || "").trim().toLowerCase()
        return (u === "metric" || u === "imperial") ? u : "auto"
    }
    readonly property string reportLocation: configuredLocation || wttrLocation || (areaInfo && areaInfo.areaName && areaInfo.areaName[0] ? areaInfo.areaName[0].value : "")
    readonly property string reportTempNum: current ? String(useImperial ? current.temp_F : current.temp_C) : ""
    readonly property string tempUnit: "°" + (useImperial ? "F" : "C")
    readonly property string reportFeels: current ? formatTemp(useImperial ? current.FeelsLikeF : current.FeelsLikeC) : ""
    readonly property string reportWind: current ? (useImperial ? (current.windspeedMiles + " mph") : (current.windspeedKmph + " km/h")) : ""
    readonly property string reportHumidity: current ? (current.humidity + "%") : ""
    readonly property string reportCondition: (report && report.current_condition && report.current_condition[0] && report.current_condition[0].weatherDesc && report.current_condition[0].weatherDesc[0]) ? report.current_condition[0].weatherDesc[0].value : ""

    function status(): string {
        return "label=" + (label.length > 0 ? "yes" : "no") + " temp=" + reportTempNum + tempUnit
            + " loc=" + reportLocation + " imperial=" + useImperial + " updated=" + updatedLabel
    }

    function refresh(): void {
        forecastRetries = 0
        dailyForecastRetries = 0
        if (!forecastProc.running) forecastProc.running = true
        if (root.locationQuery === "" && !locationProc.running) locationProc.running = true
        refreshDailyForecast(null)
    }
    function refreshDailyForecast(sourceReport: var): void {
        if (dailyForecastProc.running) return
        let lat = parseFloat(String(root.configuredLocationState.latitude))
        let lon = parseFloat(String(root.configuredLocationState.longitude))
        if (isNaN(lat) || isNaN(lon)) {
            let area = sourceReport && sourceReport.nearest_area && sourceReport.nearest_area[0] ? sourceReport.nearest_area[0] : root.areaInfo
            if (!area) return
            lat = parseFloat(String(area.latitude || ""))
            lon = parseFloat(String(area.longitude || ""))
        }
        if (isNaN(lat) || isNaN(lon)) return
        let url = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=" + encodeURIComponent(String(lat))
            + "&longitude=" + encodeURIComponent(String(lon))
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min"
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day"
            + "&forecast_days=4"
            + "&timezone=auto"
        dailyForecastProc.command = ["curl", "-fsS", "--max-time", "5", url]
        dailyForecastProc.running = true
    }

    function beginEditingLocation(): void {
        editingLocation = true
        savingLocation = false
        savingLocationQueryStarted = false
        locationSuggestions = []
        suggestionIndex = 0
    }
    function cancelEditingLocation(): void {
        editingLocation = false
        savingLocation = false
        savingLocationQueryStarted = false
        locationSuggestions = []
        geocodeDebounce.stop()
    }
    function commitLocation(text: string): void {
        let location = WeatherModel.locationCommit(text, locationSuggestions, suggestionIndex)
        if (location.name === "") { clearLocation(); return }
        applyLocation(location.name, location.latitude, location.longitude)
    }
    function pickSuggestion(suggestion: var): void {
        if (!suggestion) return
        applyLocation(suggestion.name, suggestion.latitude, suggestion.longitude)
    }
    function clearLocation(): void {
        applyLocation("", null, null)
        wttrLocation = ""
        cancelEditingLocation()
    }
    function applyLocation(name: string, latitude: var, longitude: var): void {
        savingLocation = true
        savingLocationQueryStarted = false
        let lat = (latitude === null || latitude === undefined || isNaN(parseFloat(latitude))) ? 0 : parseFloat(latitude)
        let lon = (longitude === null || longitude === undefined || isNaN(parseFloat(longitude))) ? 0 : parseFloat(longitude)
        let coords = lat !== 0 || lon !== 0
        configuredLocationState = { name: name, latitude: coords ? lat : null, longitude: coords ? lon : null }
        locationFile.adapter.name = name
        locationFile.adapter.latitude = lat
        locationFile.adapter.longitude = lon
        locationFile.adapter.hasCoords = coords
        locationFile.writeAdapter()
        Qt.callLater(finishSaveCheck)
    }
    function finishSaveCheck(): void {
        if (savingLocation && !savingLocationQueryStarted) {
            savingLocationQueryStarted = true
            forecastRetries = 0
            dailyForecastRetries = 0
            forecastProc.running = false
            dailyForecastProc.running = false
            Qt.callLater(refresh)
        }
    }
    function finishSavingLocation(): void {
        if (savingLocation && savingLocationQueryStarted) cancelEditingLocation()
    }
    function queueGeocode(query: string): void {
        let q = String(query || "").trim()
        if (q.length < 2) { locationSuggestions = []; return }
        geocodePendingQuery = q
        geocodeDebounce.restart()
    }
    function startGeocode(): void {
        geocodeActiveQuery = geocodePendingQuery
        geocodeProc.command = ["curl", "-fsS", "--max-time", "5",
            "https://geocoding-api.open-meteo.com/v1/search?name=" + encodeURIComponent(geocodeActiveQuery) + "&count=5&language=en&format=json"]
        geocodeProc.running = true
    }

    function buildForecastDays(): var {
        return WeatherModel.buildForecastDays(report, dailyForecastReport, Qt.formatDate(new Date(), "yyyy-MM-dd"))
    }
    function formatTemp(value: var): string {
        return WeatherModel.formatTemp(value, useImperial)
    }
    function dayName(dateString: string): string {
        return WeatherModel.dayName(dateString, function(date) { return Qt.formatDate(date, "dddd") })
    }
    function bareTempForDay(day: var, kind: string): string {
        return WeatherModel.bareTempForDay(day, kind, useImperial)
    }
    function dayIcon(day: var): string {
        return WeatherModel.dayIcon(day)
    }

    Process {
        id: forecastProc
        command: ["curl", "-fsS", "--max-time", "10", "https://wttr.in/" + root.locationQuery + "?format=j1"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                let raw = String(text || "").trim()
                if (!raw) { root.scheduleForecastRetry(); return }
                try {
                    let parsed = JSON.parse(raw)
                    root.report = parsed
                    if (!root.hasConfiguredCoordinates)
                        root.label = WeatherModel.provisionalCurrentIcon(parsed.current_condition && parsed.current_condition[0], root.label)
                    root.forecastRetries = 0
                    if (WeatherModel.weatherResponseCompletesSave(root.hasConfiguredCoordinates, "wttr"))
                        root.finishSavingLocation()
                    if (isNaN(parseFloat(String(root.configuredLocationState.latitude))))
                        root.refreshDailyForecast(parsed)
                } catch (e) {
                    root.scheduleForecastRetry()
                }
            }
        }
    }
    function scheduleForecastRetry(): void {
        if (forecastRetries >= 3) return
        forecastRetries++
        forecastRetryTimer.restart()
    }
    Timer {
        id: forecastRetryTimer
        interval: 2500; repeat: false
        onTriggered: if (!forecastProc.running) forecastProc.running = true
    }
    function scheduleDailyForecastRetry(): void {
        if (dailyForecastRetries >= 3) return
        dailyForecastRetries++
        dailyForecastRetryTimer.restart()
    }
    Timer {
        id: dailyForecastRetryTimer
        interval: 2500; repeat: false
        onTriggered: root.refreshDailyForecast(null)
    }
    Process {
        id: dailyForecastProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                let raw = String(text || "").trim()
                if (!raw) { root.scheduleDailyForecastRetry(); return }
                try {
                    let parsed = JSON.parse(raw)
                    let parsedCurrent = WeatherModel.openMeteoCurrentCondition(parsed)
                    root.dailyForecastReport = parsed
                    root.label = WeatherModel.currentIcon(parsedCurrent, root.label)
                    root.dailyForecastRetries = 0
                    root.lastUpdated = new Date()
                    if (WeatherModel.weatherResponseCompletesSave(root.hasConfiguredCoordinates, "open-meteo"))
                        root.finishSavingLocation()
                } catch (e) {
                    root.scheduleDailyForecastRetry()
                }
            }
        }
    }
    Process {
        id: geocodeProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.locationSuggestions = root.editingLocation ? WeatherModel.parseGeocodingResults(text) : []
                root.suggestionIndex = 0
                if (root.geocodePendingQuery !== root.geocodeActiveQuery) Qt.callLater(root.startGeocode)
            }
        }
    }
    Timer {
        id: geocodeDebounce
        interval: 300; repeat: false
        onTriggered: if (!geocodeProc.running) root.startGeocode()
    }
    Process {
        id: locationProc
        command: ["curl", "-fsS", "--max-time", "4", "https://wttr.in/?format=%l"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                let raw = String(text || "").trim()
                if (!raw) return
                root.wttrLocation = raw.split(",")[0]
            }
        }
    }
    Timer {
        id: refreshTimer
        interval: root.refreshMinutes * 60 * 1000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.refresh()
    }
    Timer { id: netBackTimer; interval: 8000; repeat: false; onTriggered: root.refresh() }
    Connections {
        target: NetworkService
        function onNetActiveChanged() { if (NetworkService.netActive) netBackTimer.restart() }
    }
}
