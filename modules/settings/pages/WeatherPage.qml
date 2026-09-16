pragma ComponentBehavior: Bound
import QtQuick
import "../../../themes"
import "../../../services"
import ".."

NexusControls.PageBase {
    id: root
    title: "Weather"

    NexusControls.SectionHeader { first: true; text: "Weather" }
    NexusControls.DropdownRow {
        first: true
        label: "Unit"
        options: ["auto", "metric", "imperial"]
        current: WeatherService.unitName
        onPicked: v => WeatherService.setUnit(v)
    }
    NexusControls.SliderRow { last: true; label: "Refresh"; from: 1; to: 120; stepSize: 1; unit: "m"; value: WeatherService.refreshMinutes; onMoved: v => WeatherService.setRefreshMinutes(Math.round(v)); onApplied: v => WeatherService.setRefreshMinutes(Math.round(v)) }
}
