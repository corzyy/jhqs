pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io // required — provides IpcHandler
import Quickshell.Wayland
import "../../themes"
import "../../services"
import "../../Ui"

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

    // Shared bits (same language as Network/Bluetooth panels).
    component SectionHeader: Text {
        antialiasing: Theme.textAa
        renderType: Theme.textRenderType
        color: Theme.textSecondary
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.fs(10)
        font.weight: Font.Bold
        font.letterSpacing: 1.2
    }
    component Hairline: Rectangle {
        antialiasing: Theme.shapesAa
        color: Theme.withAlpha(Theme.textPrimary, 0.12)
        height: 1
    }
    component IconBtn: Rectangle {
        id: iconBtnRoot
        required property string glyph
        property bool accentOnHover: true
        signal pressed()
        width: 32; height: 32
        radius: 0
        antialiasing: Theme.shapesAa
        color: btnMouse.containsMouse ? Theme.bgHover : "transparent"
        border.color: btnMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.25) : "transparent"
        border.width: 1
        Text {
            anchors.centerIn: parent
            text: iconBtnRoot.glyph
            color: btnMouse.containsMouse && iconBtnRoot.accentOnHover ? Theme.accent : Theme.textSecondary
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.fs(15)
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
        }
        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: iconBtnRoot.pressed()
        }
    }

    readonly property string heroMeta: {
        let cond = (WeatherService.reportCondition || "").trim().toUpperCase()
        if (WeatherService.hasData) {
            let upd = WeatherService.updatedLabel !== "" ? "UPDATED " + WeatherService.updatedLabel : ""
            if (cond !== "" && upd !== "") return cond + "  •  " + upd
            if (cond !== "") return cond
            return upd !== "" ? upd : "LIVE"
        }
        return "FETCHING…"
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
                // Horizontal rectangle: width comfortably exceeds height.
                width: 560
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
                        var f = locationField
                        f.text = WeatherService.configuredLocation
                        f.selectAll()
                        f.forceActiveFocus()
                    })
                }
                implicitHeight: Math.max(120, Math.min(contentCol.implicitHeight + 36, wxAnchor.screenHeight - wxAnchor.edgeOffset - 24))
                color: Theme.bg
                border.color: Theme.panelBorderColor
                border.width: 2
                // 0px rounding kept intentionally — sharp horizontal rectangle.
                radius: 0
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

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 18
                    contentHeight: contentCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height
                    Column {
                        id: contentCol
                        width: parent.width
                        spacing: 12

                        // Hero across the full horizontal width.
                        Item {
                            width: parent.width
                            implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroActions.implicitHeight)
                            Text {
                                id: heroIcon
                                text: WeatherService.label || "—"
                                color: WeatherService.hasData ? Theme.textPrimary : Theme.textMuted
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fs(26)
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                            Row {
                                id: heroActions
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                IconBtn {
                                    glyph: "󰍎"
                                    onPressed: wxBox.startLocationEdit()
                                }
                                IconBtn {
                                    glyph: "↻"
                                    onPressed: WeatherService.refresh()
                                }
                            }
                            Column {
                                id: heroLabels
                                anchors.left: heroIcon.right
                                anchors.leftMargin: 14
                                anchors.right: heroActions.left
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Text {
                                    width: parent.width
                                    text: WeatherService.reportLocation !== "" ? WeatherService.reportLocation : "Weather"
                                    color: Theme.textPrimary
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: Theme.fs(16)
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                                Text {
                                    width: parent.width
                                    text: root.heroMeta
                                    color: Theme.textSecondary
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: Theme.fs(10)
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1.2
                                    elide: Text.ElideRight
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                            }
                            MouseArea {
                                anchors.left: parent.left
                                anchors.right: heroActions.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: wxBox.startLocationEdit()
                            }
                        }

                        Hairline { width: parent.width }

                        // Horizontal body: now/stats/location left, forecast right.
                        Row {
                            id: middleRow
                            width: parent.width
                            spacing: 14
                            Column {
                                id: leftCol
                                width: Math.floor((parent.width - 14 - 1) / 2)
                                spacing: 12
                                // Now: big temp + condition.
                                Item {
                                    width: parent.width
                                    implicitHeight: Math.max(tempRow.implicitHeight, nowSide.implicitHeight)
                                    visible: WeatherService.hasData
                                    Row {
                                        id: tempRow
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        Text {
                                            id: tempBig
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: WeatherService.reportTempNum || "—"
                                            color: Theme.textPrimary
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: Theme.fs(44)
                                            font.weight: Font.Bold
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                        }
                                        Text {
                                            anchors.top: tempBig.top
                                            anchors.topMargin: 8
                                            text: WeatherService.tempUnit
                                            color: Theme.textPrimary
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: Theme.fs(17)
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                        }
                                    }
                                    Column {
                                        id: nowSide
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.min(130, parent.width - tempRow.implicitWidth - 16)
                                        spacing: 4
                                        Text {
                                            width: parent.width
                                            horizontalAlignment: Text.AlignRight
                                            text: (WeatherService.reportCondition || "—")
                                            color: Theme.textPrimary
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: Theme.fs(12)
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                            wrapMode: Text.WordWrap
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                        }
                                        Text {
                                            visible: text !== ""
                                            width: parent.width
                                            horizontalAlignment: Text.AlignRight
                                            text: WeatherService.hasData && WeatherService.reportFeels !== "" ? "Feels " + WeatherService.reportFeels : ""
                                            color: Theme.textSecondary
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: Theme.fs(11)
                                            elide: Text.ElideRight
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                        }
                                    }
                                }
                                Text {
                                    visible: !WeatherService.hasData
                                    width: parent.width
                                    text: "Fetching forecast…"
                                    color: Theme.textSecondary
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: Theme.fs(11)
                                    font.italic: true
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                                GridLayout {
                                    visible: WeatherService.hasData
                                    width: parent.width
                                    columns: 3
                                    columnSpacing: 16
                                    rowSpacing: 4
                                    Repeater {
                                        model: ["FEELS", "WIND", "HUMIDITY"]
                                        delegate: Column {
                                            required property var modelData
                                            required property int index
                                            readonly property string statValue: {
                                                if (index === 0) return WeatherService.reportFeels !== "" ? WeatherService.reportFeels : "--"
                                                if (index === 1) return WeatherService.reportWind !== "" ? WeatherService.reportWind : "--"
                                                return WeatherService.reportHumidity !== "" ? WeatherService.reportHumidity : "--"
                                            }
                                            spacing: 1
                                            Layout.fillWidth: true
                                            Text {
                                                text: modelData
                                                color: Theme.textSecondary
                                                font.family: Theme.iconFontFamily
                                                font.pixelSize: Theme.fs(10)
                                                font.weight: Font.Bold
                                                font.letterSpacing: 1.2
                                                antialiasing: Theme.textAa
                                                renderType: Theme.textRenderType
                                            }
                                            Text {
                                                text: statValue
                                                color: Theme.textPrimary
                                                font.family: Theme.iconFontFamily
                                                font.pixelSize: Theme.fs(13)
                                                elide: Text.ElideRight
                                                antialiasing: Theme.textAa
                                                renderType: Theme.textRenderType
                                            }
                                        }
                                    }
                                }
                                Column {
                                    width: parent.width
                                    spacing: 8
                                    SectionHeader { text: "LOCATION" }
                                    Rectangle {
                                        visible: !WeatherService.editingLocation
                                        width: parent.width
                                        implicitHeight: 38
                                        radius: 0
                                        antialiasing: Theme.shapesAa
                                        color: locMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.08) : Theme.withAlpha(Theme.textPrimary, 0.04)
                                        border.color: Theme.withAlpha(Theme.textPrimary, 0.25)
                                        border.width: 1
                                        Row {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8
                                            Text {
                                                text: "󰍎"
                                                color: Theme.textSecondary
                                                font.family: Theme.iconFontFamily
                                                font.pixelSize: Theme.fs(12)
                                                anchors.verticalCenter: parent.verticalCenter
                                                antialiasing: Theme.textAa
                                                renderType: Theme.textRenderType
                                            }
                                            Text {
                                                width: parent.width - 22 - 8 - 40
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: WeatherService.reportLocation !== "" ? WeatherService.reportLocation.toUpperCase() : "SET LOCATION…"
                                                color: Theme.textPrimary
                                                font.family: Theme.iconFontFamily
                                                font.pixelSize: Theme.fs(12)
                                                font.letterSpacing: 1
                                                elide: Text.ElideRight
                                                antialiasing: Theme.textAa
                                                renderType: Theme.textRenderType
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "EDIT"
                                                color: locMouse.containsMouse ? Theme.accent : Theme.textSecondary
                                                font.family: Theme.iconFontFamily
                                                font.pixelSize: Theme.fs(10)
                                                font.weight: Font.Bold
                                                font.letterSpacing: 1.2
                                                antialiasing: Theme.textAa
                                                renderType: Theme.textRenderType
                                            }
                                        }
                                        MouseArea {
                                            id: locMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: wxBox.startLocationEdit()
                                        }
                                    }
                                    Row {
                                        visible: WeatherService.editingLocation
                                        width: parent.width
                                        spacing: 6
                                        Rectangle {
                                            width: parent.width - 40
                                            height: 36
                                            radius: 0
                                            antialiasing: Theme.shapesAa
                                            color: Theme.withAlpha(Theme.textPrimary, 0.04)
                                            border.color: locationField.activeFocus ? Theme.accent : Theme.withAlpha(Theme.textPrimary, 0.25)
                                            border.width: locationField.activeFocus ? 2 : 1
                                            TextInput {
                                                id: locationField
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 10
                                                verticalAlignment: TextInput.AlignVCenter
                                                clip: true
                                                color: Theme.textPrimary
                                                selectionColor: Theme.accent
                                                font.family: Theme.iconFontFamily
                                                font.pixelSize: Theme.fs(12)
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
                                                        WeatherService.commitLocation(locationField.text)
                                                        keyCatcher.forceActiveFocus()
                                                        event.accepted = true
                                                    }
                                                }
                                            }
                                            Text {
                                                visible: locationField.text === "" && !locationField.activeFocus
                                                anchors.left: parent.left
                                                anchors.leftMargin: 10
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "Search city…"
                                                color: Theme.textMuted
                                                font.family: Theme.iconFontFamily
                                                font.pixelSize: Theme.fs(12)
                                                antialiasing: Theme.textAa
                                                renderType: Theme.textRenderType
                                            }
                                        }
                                        Rectangle {
                                            width: 34; height: 36
                                            radius: 0
                                            antialiasing: Theme.shapesAa
                                            color: clearMouse.containsMouse && !WeatherService.savingLocation ? Theme.withAlpha(Theme.textPrimary, 0.08) : "transparent"
                                            border.color: Theme.withAlpha(Theme.textPrimary, 0.25)
                                            border.width: 1
                                            Text {
                                                anchors.centerIn: parent
                                                text: WeatherService.savingLocation ? "󰦖" : "✕"
                                                font.family: Theme.iconFontFamily
                                                color: Theme.textSecondary
                                                font.pixelSize: Theme.fs(12)
                                                antialiasing: Theme.textAa
                                                renderType: Theme.textRenderType
                                            }
                                            MouseArea {
                                                id: clearMouse
                                                anchors.fill: parent
                                                enabled: !WeatherService.savingLocation
                                                hoverEnabled: true
                                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: { WeatherService.clearLocation(); keyCatcher.forceActiveFocus() }
                                            }
                                        }
                                    }
                                    Column {
                                        visible: WeatherService.editingLocation && !WeatherService.savingLocation && WeatherService.locationSuggestions.length > 0
                                        width: parent.width
                                        spacing: 0
                                        Repeater {
                                            model: WeatherService.locationSuggestions
                                            delegate: Rectangle {
                                                required property var modelData
                                                required property int index
                                                width: parent.width
                                                implicitHeight: 36
                                                radius: 0
                                                antialiasing: Theme.shapesAa
                                                color: index === WeatherService.suggestionIndex || sugMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.08) : "transparent"
                                                Row {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 10
                                                    anchors.rightMargin: 10
                                                    spacing: 8
                                                    Text {
                                                        width: parent.width - 8 - (sugSub.visible ? sugSub.implicitWidth + 8 : 0)
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: modelData.name
                                                        color: index === WeatherService.suggestionIndex ? Theme.accent : Theme.textPrimary
                                                        font.family: Theme.iconFontFamily
                                                        font.pixelSize: Theme.fs(12)
                                                        elide: Text.ElideRight
                                                        antialiasing: Theme.textAa
                                                        renderType: Theme.textRenderType
                                                    }
                                                    Text {
                                                        id: sugSub
                                                        visible: text !== ""
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: modelData.description
                                                        color: Theme.textSecondary
                                                        font.family: Theme.iconFontFamily
                                                        font.pixelSize: Theme.fs(11)
                                                        elide: Text.ElideRight
                                                        antialiasing: Theme.textAa
                                                        renderType: Theme.textRenderType
                                                    }
                                                }
                                                MouseArea {
                                                    id: sugMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onPositionChanged: WeatherService.suggestionIndex = index
                                                    onClicked: { WeatherService.pickSuggestion(modelData); keyCatcher.forceActiveFocus() }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            // Vertical divider keeps the two halves distinct.
                            Rectangle {
                                width: 1
                                height: Math.max(leftCol.implicitHeight, rightCol.implicitHeight)
                                color: Theme.withAlpha(Theme.textPrimary, 0.12)
                                antialiasing: Theme.shapesAa
                            }
                            Column {
                                id: rightCol
                                width: Math.floor((parent.width - 14 - 1) / 2)
                                spacing: 8
                                SectionHeader { text: "NEXT 3 DAYS" }
                                Repeater {
                                    model: root.showWeather ? WeatherService.forecastDays : []
                                    delegate: Rectangle {
                                        required property var modelData
                                        readonly property string fIcon: WeatherService.dayIcon(modelData)
                                        readonly property string fName: WeatherService.dayName(modelData.date).toUpperCase()
                                        readonly property string fMax: WeatherService.bareTempForDay(modelData, "max")
                                        readonly property string fMin: WeatherService.bareTempForDay(modelData, "min")
                                        width: parent.width
                                        implicitHeight: 44
                                        radius: 0
                                        antialiasing: Theme.shapesAa
                                        color: fcMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.08) : "transparent"
                                        Row {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            spacing: 8
                                            Text {
                                                text: fIcon
                                                color: Theme.textPrimary
                                                font.family: Theme.iconFontFamily
                                                font.pixelSize: Theme.fs(17)
                                                width: 24
                                                horizontalAlignment: Text.AlignHCenter
                                                anchors.verticalCenter: parent.verticalCenter
                                                antialiasing: Theme.textAa
                                                renderType: Theme.textRenderType
                                            }
                                            Text {
                                                width: parent.width - 24 - 8 - 96
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: fName
                                                color: Theme.textPrimary
                                                font.family: Theme.iconFontFamily
                                                font.pixelSize: Theme.fs(12)
                                                font.weight: Font.Bold
                                                font.letterSpacing: 1
                                                elide: Text.ElideRight
                                                antialiasing: Theme.textAa
                                                renderType: Theme.textRenderType
                                            }
                                            Row {
                                                width: 96
                                                anchors.verticalCenter: parent.verticalCenter
                                                layoutDirection: Qt.RightToLeft
                                                spacing: 8
                                                Text {
                                                    text: fMax
                                                    color: Theme.textPrimary
                                                    font.family: Theme.iconFontFamily
                                                    font.pixelSize: Theme.fs(12)
                                                    font.weight: Font.Bold
                                                    antialiasing: Theme.textAa
                                                    renderType: Theme.textRenderType
                                                }
                                                Text {
                                                    text: fMin
                                                    color: Theme.textSecondary
                                                    font.family: Theme.iconFontFamily
                                                    font.pixelSize: Theme.fs(12)
                                                    antialiasing: Theme.textAa
                                                    renderType: Theme.textRenderType
                                                }
                                            }
                                        }
                                        MouseArea {
                                            id: fcMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.NoButton
                                        }
                                    }
                                }
                                Text {
                                    visible: WeatherService.forecastDays.length === 0
                                    width: parent.width
                                    text: WeatherService.hasData ? "No forecast yet" : "Fetching forecast…"
                                    color: Theme.textSecondary
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: Theme.fs(11)
                                    font.italic: true
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                            }
                        }

                        Hairline { width: parent.width }

                        // Footer across the full horizontal width.
                        Item {
                            width: parent.width
                            implicitHeight: 18
                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: WeatherService.updatedLabel !== "" ? "UPDATED " + WeatherService.updatedLabel : "NOT UPDATED"
                                color: Theme.textMuted
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fs(10)
                                font.weight: Font.Bold
                                font.letterSpacing: 1.2
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "°C"
                                    color: !WeatherService.useImperial ? Theme.textPrimary : Theme.textMuted
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: Theme.fs(11)
                                    font.weight: Font.Bold
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: WeatherService.setUnit("metric")
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "/"
                                    color: Theme.textMuted
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: Theme.fs(11)
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "°F"
                                    color: WeatherService.useImperial ? Theme.textPrimary : Theme.textMuted
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: Theme.fs(11)
                                    font.weight: Font.Bold
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: WeatherService.setUnit("imperial")
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
