pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io // required — provides IpcHandler
import Quickshell.Wayland
import "../themes"
import "../services"
import "../Ui"

Scope {
    id: root
    property bool showWeather: false
    signal dismissed()
    property real springDbg: 1
    property bool _winVisible: showWeather
    Timer { id: hideTimer; interval: 0; repeat: false; onTriggered: if (!root.showWeather) root._winVisible = false }
    onShowWeatherChanged: {
        if (showWeather) { _winVisible = true; hideTimer.stop() } else hideTimer.restart()
    }
    readonly property string barPos: Theme.barPosition
    readonly property int screenGap: 6
    property int panelGap: screenGap - Theme.barThickness

    IpcHandler {
        target: "weather"
        function refresh(): string { WeatherService.refresh(); return "refreshing " + WeatherService.status() }
        function status(): string { return WeatherService.status() }
        function state(): string { return "weather=" + root.showWeather + " " + WeatherService.status() + " o=" + root.springDbg.toFixed(3) }
        function setUnit(u: string): string { return WeatherService.setUnit(u) }
        function setRefreshMinutes(n: int): string { return WeatherService.setRefreshMinutes(n) }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root._winVisible && modelData.name === "DP-1"
            color: "transparent"
            exclusiveZone: 0
            anchors { top: true; left: true; right: true; bottom: true }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "weather"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: root.dismissed()
            }
            Rectangle {
                antialiasing: Theme.shapesAa
                id: wxBox
                width: 480
                BarAnchor {
                    id: wxAnchor
                    moduleId: "weather"
                    barPos: root.barPos
                    panelWidth: wxBox.width
                    panelHeight: wxBox.implicitHeight
                    screenWidth: wxBox.parent.width
                    screenHeight: wxBox.parent.height
                    gap: root.panelGap
                    fallbackX: (wxBox.parent.width - wxBox.width) / 2
                    fallbackY: wxBox.parent.height - wxBox.implicitHeight - root.panelGap
                }
                x: wxAnchor.panelX
                y: wxAnchor.panelY
                function startLocationEdit(): void {
                    WeatherService.beginEditingLocation()
                    Qt.callLater(function() {
                        var f = locationFieldMinimal
                        f.text = WeatherService.configuredLocation
                        f.selectAll()
                        f.forceActiveFocus()
                    })
                }
                function dayNum(d: var, kind: string): real {
                    if (!d) return NaN
                    let v = WeatherService.useImperial ? (kind === "max" ? d.maxtempF : d.mintempF) : (kind === "max" ? d.maxtempC : d.mintempC)
                    return parseFloat(String(v))
                }
                function weekLo(): real {
                    let days = WeatherService.forecastDays
                    let m = Infinity
                    for (let i = 0; i < days.length; i++) {
                        let n = wxBox.dayNum(days[i], "min")
                        if (!isNaN(n) && n < m) m = n
                    }
                    return m === Infinity ? 0 : m
                }
                function weekHi(): real {
                    let days = WeatherService.forecastDays
                    let m = -Infinity
                    for (let i = 0; i < days.length; i++) {
                        let n = wxBox.dayNum(days[i], "max")
                        if (!isNaN(n) && n > m) m = n
                    }
                    return m === -Infinity ? 0 : m
                }
                function rangeFrac(v: real, lo: real, hi: real): real {
                    if (isNaN(v) || hi <= lo) return 0
                    return Math.max(0, Math.min(1, (v - lo) / (hi - lo)))
                }
                implicitHeight: minimalWrap.implicitHeight + 28
                color: Theme.bg
                border.color: Theme.accent
                border.width: 2
                radius: Theme.cornerRadius
                clip: true
                PanelSpring {
                    id: wxSpring
                    slideFade: true
                    shown: root.showWeather
                    onOffsetChanged: root.springDbg = offset
                    hiddenX: root.barPos === "left" ? -(wxBox.width + 5) : root.barPos === "right" ? (wxBox.width + 5) : 0
                    hiddenY: root.barPos === "top" ? -(wxBox.implicitHeight + 5) : root.barPos === "bottom" ? (wxBox.implicitHeight + 5) : 0
                }
                visible: wxSpring.boxVisible
                opacity: wxSpring.fade
                scale: wxSpring.zoom
                transformOrigin: wxAnchor.origin
                transform: Translate { x: wxSpring.slideX; y: wxSpring.slideY }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onClicked: mouse => mouse.accepted = true
                    onPressed: mouse => mouse.accepted = true
                    onWheel: wheel => wheel.accepted = true
                }
                Item {
                    id: keyCatcher
                    anchors.fill: parent
                    focus: true
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            if (WeatherService.editingLocation) WeatherService.cancelEditingLocation()
                            else root.dismissed()
                            event.accepted = true
                        } else if ((event.text === "r" || event.text === "R") && !WeatherService.editingLocation) {
                            WeatherService.refresh()
                            event.accepted = true
                        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !WeatherService.editingLocation) {
                            wxBox.startLocationEdit()
                            event.accepted = true
                        }
                    }
                    Component.onCompleted: forceActiveFocus()
                }
                Connections {
                    target: root
                    function onShowWeatherChanged() {
                        if (root.showWeather) Qt.callLater(function() { keyCatcher.forceActiveFocus() })
                    }
                }


                Item {
                    id: minimalWrap
                    anchors.fill: parent
                    anchors.margins: 14
                    implicitHeight: minimalCol.implicitHeight
                    clip: true
                    ColumnLayout {
                        id: minimalCol
                        anchors.left: parent.left; anchors.right: parent.right
                        spacing: 14

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(heroLeftOm.height, heroRightOm.height)
                            Row {
                                id: heroLeftOm
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 16
                                Text {
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: 5
                                    text: WeatherService.label || "—"
                                    color: Theme.textPrimary
                                    font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(64)
                                }
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text {
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                        id: tempBigOm
                                        text: WeatherService.reportTempNum || "—"
                                        color: Theme.textPrimary
                                        font.family: Theme.iconFontFamily
                                        font.pixelSize: Theme.fs(56); font.weight: Font.Bold
                                    }
                                    Text {
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                        visible: WeatherService.hasData
                                        text: WeatherService.tempUnit
                                        color: Theme.textPrimary
                                        font.family: Theme.iconFontFamily
                                        font.pixelSize: Theme.fs(24)
                                        anchors.top: tempBigOm.top
                                        anchors.topMargin: 10
                                    }
                                }
                            }
                            Column {
                                id: heroRightOm
                                width: weatherStatsOm.implicitWidth
                                anchors.right: parent.right
                                anchors.rightMargin: 20
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12
                                Item {
                                    visible: !WeatherService.editingLocation && WeatherService.reportLocation !== ""
                                    implicitWidth: locRowOm.implicitWidth
                                    implicitHeight: locRowOm.implicitHeight
                                    Row {
                                        id: locRowOm
                                        spacing: 6
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            text: "󰍎"
                                            color: Theme.textSecondary
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: Theme.fs(12)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            text: (WeatherService.reportLocation || "").toUpperCase()
                                            color: Theme.textSecondary
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: Theme.fs(12)
                                            font.letterSpacing: 1
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            text: "↻"
                                            color: refreshMouseOm.containsMouse ? Theme.accent : Theme.textSecondary
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: Theme.fs(12)
                                            anchors.verticalCenter: parent.verticalCenter
                                            MouseArea {
                                                id: refreshMouseOm
                                                anchors.fill: parent
                                                anchors.margins: -6
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: WeatherService.refresh()
                                            }
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: wxBox.startLocationEdit()
                                    }
                                }
                                Row {
                                    visible: WeatherService.editingLocation
                                    spacing: 6
                                    TextInput {
                                        id: locationFieldMinimal
                                        width: 190
                                        anchors.verticalCenter: parent.verticalCenter
                                        clip: true
                                        color: Theme.textPrimary
                                        selectionColor: Theme.accent
                                        font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(12)
                                        selectByMouse: true
                                        enabled: !WeatherService.savingLocation
                                        onTextChanged: {
                                            if (WeatherService.editingLocation && !WeatherService.savingLocation)
                                                WeatherService.queueGeocode(text)
                                        }
                                        Keys.onPressed: event => {
                                            if (event.key === Qt.Key_Escape) {
                                                WeatherService.cancelEditingLocation()
                                                keyCatcher.forceActiveFocus()
                                                event.accepted = true
                                            } else if (event.key === Qt.Key_Down) {
                                                if (WeatherService.suggestionIndex < WeatherService.locationSuggestions.length - 1) WeatherService.suggestionIndex++
                                                event.accepted = true
                                            } else if (event.key === Qt.Key_Up) {
                                                if (WeatherService.suggestionIndex > 0) WeatherService.suggestionIndex--
                                                event.accepted = true
                                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                                WeatherService.commitLocation(locationFieldMinimal.text)
                                                keyCatcher.forceActiveFocus()
                                                event.accepted = true
                                            }
                                        }
                                    }
                                    Rectangle {
                                        antialiasing: Theme.shapesAa
                                        width: 18; height: 18
                                        anchors.verticalCenter: parent.verticalCenter
                                        radius: 0
                                        color: !WeatherService.savingLocation && clearMouseOm.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.08) : "transparent"
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            anchors.centerIn: parent
                                            text: WeatherService.savingLocation ? "󰦖" : "✕"
                                            font.family: Theme.iconFontFamily
                                            color: Theme.textSecondary
                                            font.pixelSize: Theme.fs(11)
                                        }
                                        MouseArea {
                                            id: clearMouseOm
                                            anchors.fill: parent
                                            enabled: !WeatherService.savingLocation
                                            hoverEnabled: true
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: { WeatherService.clearLocation(); keyCatcher.forceActiveFocus() }
                                        }
                                    }
                                }
                                Row {
                                    id: weatherStatsOm
                                    visible: WeatherService.hasData
                                    spacing: 36
                                    Repeater {
                                        model: [
                                            { caps: "FEELS", value: WeatherService.reportFeels },
                                            { caps: "WIND", value: WeatherService.reportWind },
                                            { caps: "HUMID", value: WeatherService.reportHumidity }
                                        ]
                                        delegate: Column {
                                            required property var modelData
                                            spacing: 5
                                            Text {
                                                antialiasing: Theme.textAa
                                                renderType: Theme.textRenderType
                                                text: modelData.caps
                                                color: Theme.textSecondary
                                                font.family: Theme.iconFontFamily
                                                font.pixelSize: Theme.fs(11)
                                                font.letterSpacing: 1
                                            }
                                            Text {
                                                antialiasing: Theme.textAa
                                                renderType: Theme.textRenderType
                                                text: modelData.value
                                                color: Theme.textPrimary
                                                font.family: Theme.iconFontFamily
                                                font.pixelSize: Theme.fs(14)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            visible: WeatherService.editingLocation && !WeatherService.savingLocation && WeatherService.locationSuggestions.length > 0
                            Repeater {
                                model: WeatherService.locationSuggestions
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: suggestionRowOm.implicitHeight + 12
                                    radius: 0
                                    color: index === WeatherService.suggestionIndex ? Theme.withAlpha(Theme.textPrimary, 0.08) : "transparent"
                                    Row {
                                        id: suggestionRowOm
                                        anchors.left: parent.left
                                        anchors.leftMargin: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 8
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            text: modelData.name
                                            color: index === WeatherService.suggestionIndex ? Theme.accent : Theme.textPrimary
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: Theme.fs(12)
                                        }
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            visible: text !== ""
                                            text: modelData.description
                                            color: Theme.textSecondary
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: Theme.fs(11)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onPositionChanged: WeatherService.suggestionIndex = index
                                        onClicked: { WeatherService.pickSuggestion(modelData); keyCatcher.forceActiveFocus() }
                                    }
                                }
                            }
                        }

                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            visible: !WeatherService.hasData
                            text: "Fetching forecast…"
                            color: Theme.textSecondary
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.fs(11)
                            font.italic: true
                        }

                        Rectangle {
                            visible: WeatherService.forecastDays.length > 0
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Theme.textPrimary
                            opacity: 0.12
                        }

                        Item {
                            visible: WeatherService.forecastDays.length > 0
                            Layout.fillWidth: true
                            Layout.preferredHeight: forecastRowOm.height
                            Row {
                                id: forecastRowOm
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 44
                                Repeater {
                                    model: WeatherService.forecastDays
                                    delegate: Row {
                                        required property var modelData
                                        spacing: 10
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: WeatherService.dayIcon(modelData)
                                            color: Theme.textPrimary
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: Theme.fs(24)
                                        }
                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 2
                                            Text {
                                                antialiasing: Theme.textAa
                                                renderType: Theme.textRenderType
                                                text: WeatherService.dayName(modelData.date).toUpperCase()
                                                color: Theme.textSecondary
                                                font.family: Theme.iconFontFamily
                                                font.pixelSize: Theme.fs(10)
                                                font.letterSpacing: 1
                                            }
                                            Row {
                                                spacing: 6
                                                Text {
                                                    antialiasing: Theme.textAa
                                                    renderType: Theme.textRenderType
                                                    text: WeatherService.bareTempForDay(modelData, "max")
                                                    color: Theme.textPrimary
                                                    font.family: Theme.iconFontFamily
                                                    font.pixelSize: Theme.fs(12)
                                                }
                                                Text {
                                                    antialiasing: Theme.textAa
                                                    renderType: Theme.textRenderType
                                                    text: WeatherService.bareTempForDay(modelData, "min")
                                                    color: Theme.textSecondary
                                                    font.family: Theme.iconFontFamily
                                                    font.pixelSize: Theme.fs(12)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
