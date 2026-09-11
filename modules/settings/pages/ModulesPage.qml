pragma ComponentBehavior: Bound
import QtQuick
import "../../../themes"
import "../../../services"
import ".."

Column {
    id: root
    width: parent ? parent.width : 400
    spacing: 10

    property var moduleEntries: [
        {id: "vitals", title: "Vitals"},
        {id: "volume", title: "Volume"},
        {id: "weather", title: "Weather"}
    ]
    property string selectedModule: "vitals"
    function entryTitle(id: string): string {
        for (let i = 0; i < moduleEntries.length; i++)
            if (moduleEntries[i].id === id) return moduleEntries[i].title
        return moduleEntries.length > 0 ? moduleEntries[0].title : ""
    }
    function entryId(title: string): string {
        for (let i = 0; i < moduleEntries.length; i++)
            if (moduleEntries[i].title === title) return moduleEntries[i].id
        return selectedModule
    }
    readonly property var moduleOptions: {
        let out = []
        for (let i = 0; i < moduleEntries.length; i++) out.push(moduleEntries[i].title)
        return out
    }

    SettingsControls.SettingsSection {
        title: "Module"
        SettingsControls.SettingsDropdown {
            label: "Configure"
            options: root.moduleOptions
            current: root.entryTitle(root.selectedModule)
            onPicked: v => root.selectedModule = root.entryId(v)
        }
    }

    SettingsControls.SettingsSection {
        visible: root.selectedModule === "vitals"
        title: "Vitals"
        SettingsControls.SettingsRow {
            title: "CPU"
            subtitle: "Show CPU load in the bar pill + panel"
            SettingsControls.SettingsToggle { on: VitalsService.showCpu; onToggled: n => VitalsService.setShowCpu(n) }
        }
        SettingsControls.SettingsRow {
            title: "RAM"
            subtitle: "Show memory usage in the bar pill + panel"
            SettingsControls.SettingsToggle { on: VitalsService.showRam; onToggled: n => VitalsService.setShowRam(n) }
        }
        SettingsControls.SettingsRow {
            title: "GPU"
            subtitle: VitalsService.gpuAvailable ? ("Show GPU load (" + (VitalsService.gpuName.length > 0 ? VitalsService.gpuName : "auto") + ")") : "Show GPU load (auto-hidden: no GPU detected)"
            SettingsControls.SettingsToggle { on: VitalsService.showGpu; enabled: VitalsService.gpuAvailable; onToggled: n => VitalsService.setShowGpu(n) }
        }
        SettingsControls.SettingsRow {
            title: "% Labels"
            subtitle: "Show percentage text next to the bar icons"
            SettingsControls.SettingsToggle { on: VitalsService.showLabels; onToggled: n => VitalsService.setShowLabels(n) }
        }
        SettingsControls.SettingsSliderRow { label: "Refresh"; from: 1; to: 10; stepSize: 1; unit: "s"; value: VitalsService.refreshSeconds; onMoved: v => VitalsService.setRefreshSeconds(Math.round(v)); onApplied: v => VitalsService.setRefreshSeconds(Math.round(v)) }
        SettingsControls.SettingsSliderRow { label: "Warn at"; from: 10; to: 95; stepSize: 1; unit: "%"; value: VitalsService.warnThreshold; onMoved: v => VitalsService.setWarnThreshold(Math.round(v)); onApplied: v => VitalsService.setWarnThreshold(Math.round(v)) }
        SettingsControls.SettingsSliderRow { label: "Critical at"; from: 20; to: 99; stepSize: 1; unit: "%"; value: VitalsService.critThreshold; onMoved: v => VitalsService.setCritThreshold(Math.round(v)); onApplied: v => VitalsService.setCritThreshold(Math.round(v)) }
    }

    SettingsControls.SettingsSection {
        visible: root.selectedModule === "volume"
        title: "Volume"
        SettingsControls.SettingsRow {
            title: "% Label"
            subtitle: "Show volume percentage next to the bar icon"
            SettingsControls.SettingsToggle { on: VolumeService.showPct; onToggled: n => VolumeService.setShowPct(n) }
        }
    }

    SettingsControls.SettingsSection {
        visible: root.selectedModule === "weather"
        title: "Weather"
        SettingsControls.SettingsRow {
            title: "Label"
            subtitle: "Show temperature next to the bar icon"
            SettingsControls.SettingsToggle { on: WeatherService.showLabel; onToggled: n => WeatherService.setShowLabel(n) }
        }
        SettingsControls.SettingsRow {
            visible: !WeatherService.editingLocation
            title: WeatherService.cityName.length > 0 ? WeatherService.cityName : "Auto-detect"
            subtitle: "City — located by IP"
            Rectangle {
                antialiasing: Theme.shapesAa
                width: 32; height: 32
                radius: Theme.cornerRadiusSmall
                color: cityEditMouse.containsMouse ? Theme.bgHover : Theme.panelSurface
                border.color: Theme.divider; border.width: 1
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    anchors.centerIn: parent
                    text: "󰏫"
                    font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14)
                    color: Theme.textSecondary
                }
                MouseArea {
                    id: cityEditMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        WeatherService.beginEditingLocation()
                        cityField.text = WeatherService.cityName
                        cityField.forceActiveFocus()
                    }
                }
            }
        }
        Column {
            visible: WeatherService.editingLocation
            width: parent.width
            spacing: 4
            Row {
                width: parent.width
                spacing: 8
                Rectangle {
                    antialiasing: Theme.shapesAa
                    width: parent.width - 44; height: 36
                    radius: Theme.cornerRadiusSmall
                    color: cityField.activeFocus ? Theme.bgSelected : Theme.panelSurface
                    border.color: cityField.activeFocus ? Theme.accent : Theme.divider
                    border.width: 1
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                        verticalAlignment: Text.AlignVCenter
                        visible: cityField.displayText.length === 0
                        text: "Search city"
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12)
                        color: Theme.textMuted
                        elide: Text.ElideRight
                    }
                    TextInput {
                        id: cityField
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12)
                        color: Theme.textPrimary
                        selectByMouse: true
                        clip: true
                        enabled: !WeatherService.savingLocation
                        onTextChanged: {
                            if (WeatherService.editingLocation && !WeatherService.savingLocation)
                                WeatherService.queueGeocode(text)
                        }
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                WeatherService.cancelEditingLocation()
                                focus = false
                                event.accepted = true
                            } else if (event.key === Qt.Key_Down) {
                                if (WeatherService.suggestionIndex < WeatherService.locationSuggestions.length - 1) WeatherService.suggestionIndex++
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up) {
                                if (WeatherService.suggestionIndex > 0) WeatherService.suggestionIndex--
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                WeatherService.commitLocation(cityField.text)
                                focus = false
                                event.accepted = true
                            }
                        }
                    }
                }
                Rectangle {
                    antialiasing: Theme.shapesAa
                    width: 36; height: 36
                    radius: Theme.cornerRadiusSmall
                    color: cityClearMouse.containsMouse && !WeatherService.savingLocation ? Theme.bgHover : Theme.panelSurface
                    border.color: Theme.divider; border.width: 1
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        anchors.centerIn: parent
                        text: WeatherService.savingLocation ? "↻" : "✕"
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13)
                        color: Theme.textSecondary
                    }
                    MouseArea {
                        id: cityClearMouse
                        anchors.fill: parent
                        enabled: !WeatherService.savingLocation
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: { WeatherService.clearLocation(); cityField.focus = false }
                    }
                }
            }
            Repeater {
                model: (WeatherService.editingLocation && !WeatherService.savingLocation) ? WeatherService.locationSuggestions : []
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    antialiasing: Theme.shapesAa
                    width: parent.width; height: 40
                    radius: Theme.cornerRadiusSmall
                    color: index === WeatherService.suggestionIndex ? Theme.bgSelected : (suggMouse.containsMouse ? Theme.bgHover : "transparent")
                    border.color: index === WeatherService.suggestionIndex ? Theme.divider : "transparent"
                    border.width: 1
                    Row {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                        spacing: 8
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            text: modelData.name
                            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: Font.Medium
                            color: Theme.textPrimary
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 20 - ((modelData.description || "") !== "" ? suggDesc.implicitWidth + 8 : 0)
                            elide: Text.ElideRight
                        }
                        Text {
                            id: suggDesc
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            visible: (modelData.description || "") !== ""
                            text: modelData.description || ""
                            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10)
                            color: Theme.textMuted
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                        }
                    }
                    MouseArea {
                        id: suggMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: WeatherService.suggestionIndex = index
                        onClicked: { WeatherService.pickSuggestion(modelData); cityField.focus = false }
                    }
                }
            }
        }
        SettingsControls.SettingsSliderRow { label: "Refresh"; from: 1; to: 120; stepSize: 1; unit: "m"; value: WeatherService.refreshMinutes; onMoved: v => WeatherService.setRefreshMinutes(Math.round(v)); onApplied: v => WeatherService.setRefreshMinutes(Math.round(v)) }
    }

}
