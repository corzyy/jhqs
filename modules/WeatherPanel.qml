pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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
    Timer { id: hideTimer; interval: Theme.panelAnimExit + 20; repeat: false; onTriggered: if (!root.showWeather) root._winVisible = false }
    onShowWeatherChanged: {
        if (showWeather) { _winVisible = true; hideTimer.stop() } else hideTimer.restart()
    }
    readonly property string barPos: Theme.barPosition
    readonly property int screenGap: 6
    property int panelGap: screenGap - Theme.barThickness
    readonly property bool isMinimal: Theme.minimalTheme

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
                width: root.isMinimal ? 480 : 658
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
                Behavior on x { enabled: wxAnchor.valid && wxBox.width > 0 && wxBox.implicitHeight > 0 && wxSpring.offset === 0; NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingSmooth } }
                Behavior on y { enabled: wxAnchor.valid && wxBox.width > 0 && wxBox.implicitHeight > 0 && wxSpring.offset === 0; NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingSmooth } }
                function startLocationEdit(): void {
                    WeatherService.beginEditingLocation()
                    Qt.callLater(function() {
                        var f = root.isMinimal ? locationFieldMinimal : locationField
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
                implicitHeight: (root.isMinimal ? minimalWrap.implicitHeight + 28 : contentRow.implicitHeight + 24)
                color: root.isMinimal ? Theme.bg : Theme.panelBg
                border.color: root.isMinimal ? Theme.accent : Theme.panelBorderColor
                border.width: root.isMinimal ? 2 : 1
                radius: Theme.cornerRadius
                clip: true
                Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
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

                RowLayout {
                    id: contentRow
                    visible: !root.isMinimal
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    ColumnLayout {
                        Layout.preferredWidth: 300
                        Layout.fillHeight: true
                        spacing: 8
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            id: heroCard
                            Layout.fillWidth: true
                            Layout.preferredHeight: 150
                            Layout.fillHeight: true
                            radius: Theme.cornerRadius
                            color: Theme.accentDim
                            border.width: 0
                            clip: true
                            Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
                            opacity: root.showWeather ? 1 : 0
                            transform: Translate {
                                y: root.showWeather ? 0 : 14
                                Behavior on y {
                                    SequentialAnimation {
                                        PauseAnimation { duration: Theme.animStagger }
                                        NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate }
                                    }
                                }
                            }
                            Behavior on opacity {
                                SequentialAnimation {
                                    PauseAnimation { duration: Theme.animStagger }
                                    NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate }
                                }
                            }
                            Rectangle {
                                antialiasing: Theme.shapesAa
                                readonly property real blobSize: Math.min(120, parent.height - 24)
                                width: blobSize; height: blobSize
                                radius: width / 2
                                x: parent.width - blobSize / 2
                                y: (parent.height - height) / 2
                                color: Theme.withAlpha(Theme.on_primary_container, 0.09)
                            }
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 8
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12
                                    Rectangle {
                                        antialiasing: Theme.shapesAa
                                        Layout.preferredWidth: 56; Layout.preferredHeight: 56
                                        Layout.alignment: Qt.AlignVCenter
                                        radius: width / 2
                                        color: Theme.withAlpha(Theme.on_primary_container, 0.16)
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            id: heroIcon
                                            property bool _ready: false
                                            Component.onCompleted: _ready = true
                                            anchors.centerIn: parent
                                            text: WeatherService.label || "—"
                                            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(26)
                                            color: Theme.on_primary_container
                                            onTextChanged: if (_ready) iconPop.restart()
                                            SequentialAnimation {
                                                id: iconPop
                                                ScaleAnimator { target: heroIcon; from: 0.45; to: 1; duration: Theme.animEmph; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot }
                                            }
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 2
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            visible: WeatherService.reportCondition !== ""
                                            text: (WeatherService.reportCondition || "").toUpperCase()
                                            color: Theme.withAlpha(Theme.on_primary_container, 0.75)
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fs(10); font.weight: Font.Bold; font.letterSpacing: 1.4
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        RowLayout {
                                            spacing: 2
                                            Text {
                                                antialiasing: Theme.textAa
                                                renderType: Theme.textRenderType
                                                id: heroTemp
                                                property bool _ready: false
                                                Component.onCompleted: _ready = true
                                                text: WeatherService.reportTempNum || "—"
                                                color: Theme.on_primary_container
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fs(32); font.weight: Font.Bold
                                                Layout.alignment: Qt.AlignVCenter
                                                onTextChanged: if (_ready) tempPop.restart()
                                                SequentialAnimation {
                                                    id: tempPop
                                                    ScaleAnimator { target: heroTemp; from: 0.82; to: 1; duration: Theme.animEmph; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot }
                                                }
                                            }
                                            Text {
                                                antialiasing: Theme.textAa
                                                renderType: Theme.textRenderType
                                                visible: WeatherService.hasData
                                                text: WeatherService.tempUnit
                                                color: Theme.withAlpha(Theme.on_primary_container, 0.75)
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fs(14); font.weight: Font.Medium
                                                Layout.alignment: Qt.AlignTop
                                                Layout.topMargin: 5
                                            }
                                        }
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            visible: WeatherService.hasData
                                            text: "Feels " + WeatherService.reportFeels
                                            color: Theme.withAlpha(Theme.on_primary_container, 0.75)
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fs(11)
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }
                                Item { Layout.fillHeight: true }
                                Rectangle {
                                    antialiasing: Theme.shapesAa
                                    id: locPill
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    radius: height / 2
                                    color: locTopMouse.containsMouse ? Theme.withAlpha(Theme.on_primary_container, 0.22) : Theme.withAlpha(Theme.on_primary_container, 0.12)
                                    Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
                                    scale: Theme.animationsEnabled && locTopMouse.pressed ? Theme.pressScale : 1.0
                                    Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
                                    RowLayout {
                                        id: locPillRow
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            text: "󰍎"
                                            color: Theme.on_primary_container
                                            font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(13)
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            text: (WeatherService.reportLocation || "…").toUpperCase()
                                            color: Theme.on_primary_container
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fs(11); font.weight: Font.Bold; font.letterSpacing: 0.8
                                            Layout.alignment: Qt.AlignVCenter
                                            Layout.maximumWidth: 190
                                            horizontalAlignment: Text.AlignLeft
                                            elide: Text.ElideRight
                                        }
                                    }
                                    MouseArea {
                                        id: locTopMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: wxBox.startLocationEdit()
                                    }
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: WeatherService.hasData
                            Repeater {
                                model: [
                                    { icon: "󰔏", value: WeatherService.reportFeels, caps: "FEELS LIKE", bg: Theme.secondary_container, fg: Theme.on_secondary_container },
                                    { icon: "󰖝", value: WeatherService.reportWind, caps: "WIND", bg: Theme.tertiary_container, fg: Theme.on_tertiary_container },
                                    { icon: "", value: WeatherService.reportHumidity, caps: "HUMIDITY", bg: Theme.accentDim, fg: Theme.on_primary_container }
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 84
                                    radius: Theme.cornerRadiusSmall
                                    color: Theme.cardBg
                                    border.color: Theme.divider
                                    border.width: Theme.panelBlur > 0.001 ? 0 : 1
                                    opacity: root.showWeather ? 1 : 0
                                    transform: Translate {
                                        y: root.showWeather ? 0 : 12
                                        Behavior on y {
                                            SequentialAnimation {
                                                PauseAnimation { duration: Theme.animStagger * 2 + index * Theme.animStagger }
                                                NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate }
                                            }
                                        }
                                    }
                                    Behavior on opacity {
                                        SequentialAnimation {
                                            PauseAnimation { duration: Theme.animStagger * 2 + index * Theme.animStagger }
                                            NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate }
                                        }
                                    }
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 4
                                        Rectangle {
                                            antialiasing: Theme.shapesAa
                                            Layout.preferredWidth: 30; Layout.preferredHeight: 30
                                            radius: width / 2
                                            color: modelData.bg
                                            Text {
                                                antialiasing: Theme.textAa
                                                renderType: Theme.textRenderType
                                                anchors.centerIn: parent
                                                text: modelData.icon
                                                font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14)
                                                color: modelData.fg
                                            }
                                        }
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            text: modelData.value
                                            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13); font.weight: Font.Bold
                                            color: Theme.textPrimary
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            text: modelData.caps
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fs(9); font.weight: Font.Bold; font.letterSpacing: 1.0
                                            color: Theme.textMuted
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 10
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            visible: WeatherService.editingLocation
                            spacing: 8
                            Rectangle {
                                antialiasing: Theme.shapesAa
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: height / 2
                                color: Theme.panelSurface
                                border.color: locationField.activeFocus ? Theme.accent : Theme.divider
                                border.width: 1
                                Behavior on border.color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14; anchors.rightMargin: 14
                                    spacing: 8
                                    Text {
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                        text: "󰍉"
                                        font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(13)
                                        color: Theme.textMuted
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: locationField.text === ""
                                            text: "Search city"
                                            color: Theme.textMuted
                                            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13)
                                        }
                                        TextInput {
                                            id: locationField
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width
                                            clip: true
                                            color: Theme.textPrimary
                                            selectionColor: Theme.accent
                                            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13)
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
                                    }
                                }
                            }
                            Rectangle {
                                antialiasing: Theme.shapesAa
                                Layout.preferredWidth: 40; Layout.preferredHeight: 40
                                radius: width / 2
                                color: !WeatherService.savingLocation && clearMouse.containsMouse ? Theme.bgHover : Theme.panelSurface
                                border.color: Theme.divider
                                border.width: Theme.panelBlur > 0.001 ? 0 : 1
                                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                                scale: Theme.animationsEnabled && clearMouse.pressed ? 0.9 : 1.0
                                Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
                                Text {
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                    anchors.centerIn: parent
                                    text: WeatherService.savingLocation ? "↻" : "✕"
                                    font.family: Theme.fontFamily; font.pixelSize: Theme.fs(14)
                                    color: Theme.textSecondary
                                    RotationAnimator on rotation {
                                        running: WeatherService.savingLocation && Theme.animationsEnabled
                                        from: 0; to: 360
                                        duration: 800
                                        loops: Animation.Infinite
                                    }
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
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            visible: WeatherService.editingLocation && !WeatherService.savingLocation && WeatherService.locationSuggestions.length > 0
                            Repeater {
                                model: WeatherService.locationSuggestions
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 48
                                    radius: Theme.cornerRadiusSmall
                                    color: index === WeatherService.suggestionIndex ? Theme.bgSelected : (suggMouse.containsMouse ? Theme.panelSurface : "transparent")
                                    border.color: index === WeatherService.suggestionIndex ? Theme.divider : "transparent"
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
                                    scale: Theme.animationsEnabled && suggMouse.pressed ? 0.98 : 1.0
                                    Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12; anchors.rightMargin: 12
                                        spacing: 8
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            text: modelData.name
                                            color: Theme.textPrimary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fs(13)
                                            font.weight: Theme.textBold ? Font.Medium : Font.Normal
                                            Layout.alignment: Qt.AlignVCenter
                                            elide: Text.ElideRight
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            visible: modelData.description !== ""
                                            text: modelData.description
                                            color: Theme.textMuted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fs(10)
                                            Layout.alignment: Qt.AlignVCenter
                                            elide: Text.ElideRight
                                        }
                                    }
                                    MouseArea {
                                        id: suggMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onPositionChanged: WeatherService.suggestionIndex = index
                                        onClicked: { WeatherService.pickSuggestion(modelData); keyCatcher.forceActiveFocus() }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            visible: !WeatherService.hasData
                            spacing: 8
                            Text {
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                text: "↻"
                                color: Theme.textMuted
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fs(13)
                                RotationAnimator on rotation {
                                    running: !WeatherService.hasData && Theme.animationsEnabled
                                    from: 0; to: 360
                                    duration: 900
                                    loops: Animation.Infinite
                                }
                            }
                            Text {
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                text: "Fetching forecast…"
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fs(11)
                                font.italic: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: WeatherService.forecastDays.length > 0
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text {
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                    text: "3-DAY FORECAST"
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fs(10); font.weight: Font.Bold; font.letterSpacing: 1.0
                                    Layout.fillWidth: true
                                }
                                Rectangle {
                                    antialiasing: Theme.shapesAa
                                    implicitWidth: countLabel.implicitWidth + 16
                                    implicitHeight: 22
                                    radius: height / 2
                                    color: Theme.bgSelected
                                    border.color: Theme.divider
                                    border.width: 1
                                    Text {
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                        id: countLabel
                                        anchors.centerIn: parent
                                        text: WeatherService.forecastDays.length + " DAYS"
                                        color: Theme.textSecondary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fs(9); font.weight: Font.Bold; font.letterSpacing: 0.8
                                    }
                                }
                            }
                            Repeater {
                                model: WeatherService.forecastDays
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 68
                                    radius: Theme.cornerRadius
                                    color: Theme.cardBg
                                    border.color: Theme.divider
                                    border.width: Theme.panelBlur > 0.001 ? 0 : 1
                                    Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
                                    opacity: root.showWeather ? 1 : 0
                                    transform: Translate {
                                        y: root.showWeather ? 0 : 12
                                        Behavior on y {
                                            SequentialAnimation {
                                                PauseAnimation { duration: Theme.animStagger * 3 + index * Theme.animStagger * 2 }
                                                NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate }
                                            }
                                        }
                                    }
                                    Behavior on opacity {
                                        SequentialAnimation {
                                            PauseAnimation { duration: Theme.animStagger * 3 + index * Theme.animStagger * 2 }
                                            NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate }
                                        }
                                    }
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10; anchors.rightMargin: 12
                                        spacing: 10
                                        Rectangle {
                                            antialiasing: Theme.shapesAa
                                            Layout.preferredWidth: 38; Layout.preferredHeight: 38
                                            Layout.alignment: Qt.AlignVCenter
                                            radius: width / 2
                                            color: index % 3 === 0 ? Theme.accentDim : index % 3 === 1 ? Theme.secondary_container : Theme.tertiary_container
                                            Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
                                            Text {
                                                antialiasing: Theme.textAa
                                                renderType: Theme.textRenderType
                                                anchors.centerIn: parent
                                                text: WeatherService.dayIcon(modelData)
                                                font.family: Theme.fontFamily; font.pixelSize: Theme.fs(18)
                                                color: index % 3 === 0 ? Theme.on_primary_container : index % 3 === 1 ? Theme.on_secondary_container : Theme.on_tertiary_container
                                            }
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: 5
                                            Text {
                                                antialiasing: Theme.textAa
                                                renderType: Theme.textRenderType
                                                text: WeatherService.dayName(modelData.date)
                                                color: Theme.textPrimary
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fs(13); font.weight: Font.Medium
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }
                                            Item {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 4
                                                Rectangle {
                                                    antialiasing: Theme.shapesAa
                                                    anchors.fill: parent
                                                    radius: 2
                                                    color: Theme.divider
                                                    opacity: 0.6
                                                }
                                                Rectangle {
                                                    antialiasing: Theme.shapesAa
                                                    height: 4
                                                    radius: 2
                                                    color: Theme.accent
                                                    width: {
                                                        let lo = wxBox.weekLo(), hi = wxBox.weekHi()
                                                        let a = wxBox.rangeFrac(wxBox.dayNum(modelData, "min"), lo, hi)
                                                        let b = wxBox.rangeFrac(wxBox.dayNum(modelData, "max"), lo, hi)
                                                        return Math.max(8, (b - a) * parent.width)
                                                    }
                                                    x: {
                                                        let lo = wxBox.weekLo(), hi = wxBox.weekHi()
                                                        return wxBox.rangeFrac(wxBox.dayNum(modelData, "min"), lo, hi) * parent.width
                                                    }
                                                    Behavior on width { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate } }
                                                    Behavior on x { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate } }
                                                }
                                            }
                                        }
                                        Rectangle {
                                            antialiasing: Theme.shapesAa
                                            Layout.alignment: Qt.AlignVCenter
                                            implicitWidth: hiLabel.implicitWidth + 16
                                            implicitHeight: 28
                                            radius: height / 2
                                            color: Theme.accentDim
                                            Text {
                                                antialiasing: Theme.textAa
                                                renderType: Theme.textRenderType
                                                id: hiLabel
                                                anchors.centerIn: parent
                                                text: WeatherService.bareTempForDay(modelData, "max")
                                                color: Theme.on_primary_container
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fs(13); font.weight: Font.Bold
                                            }
                                        }
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            text: WeatherService.bareTempForDay(modelData, "min")
                                            color: Theme.textMuted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fs(13)
                                            Layout.alignment: Qt.AlignVCenter
                                            Layout.preferredWidth: 34
                                            horizontalAlignment: Text.AlignRight
                                        }
                                    }
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            opacity: root.showWeather ? 1 : 0
                            transform: Translate {
                                y: root.showWeather ? 0 : 12
                                Behavior on y {
                                    SequentialAnimation {
                                        PauseAnimation { duration: Theme.animStagger * 6 }
                                        NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate }
                                    }
                                }
                            }
                            Behavior on opacity {
                                SequentialAnimation {
                                    PauseAnimation { duration: Theme.animStagger * 6 }
                                    NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate }
                                }
                            }
                            Text {
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                Layout.fillWidth: true
                                visible: WeatherService.updatedLabel !== ""
                                text: "Updated " + WeatherService.updatedLabel
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fs(10)
                                elide: Text.ElideRight
                            }
                            Item { Layout.fillWidth: true; visible: WeatherService.updatedLabel === "" }
                            Rectangle {
                                antialiasing: Theme.shapesAa
                                id: footRefresh
                                implicitWidth: footRefreshRow.implicitWidth + 20
                                implicitHeight: 32
                                radius: height / 2
                                color: footRefreshMouse.containsMouse ? Theme.bgSelected : Theme.cardBg
                                border.color: Theme.divider
                                border.width: Theme.panelBlur > 0.001 ? 0 : 1
                                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
                                scale: Theme.animationsEnabled && footRefreshMouse.pressed ? Theme.pressScale : 1.0
                                Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
                                RowLayout {
                                    id: footRefreshRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text {
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                        text: "󰑓"
                                        color: footRefreshMouse.containsMouse ? Theme.accent : Theme.textSecondary
                                        font.family: Theme.iconFontFamily
                                        font.pixelSize: Theme.fs(13)
                                        Layout.alignment: Qt.AlignVCenter
                                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
                                        RotationAnimator on rotation {
                                            running: !WeatherService.hasData && Theme.animationsEnabled
                                            from: 0; to: 360
                                            duration: 900
                                            loops: Animation.Infinite
                                        }
                                    }
                                    Text {
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                        text: "Refresh"
                                        color: footRefreshMouse.containsMouse ? Theme.accent : Theme.textSecondary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fs(11)
                                        font.weight: Theme.textBold ? Font.Medium : Font.Normal
                                        Layout.alignment: Qt.AlignVCenter
                                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
                                    }
                                }
                                MouseArea {
                                    id: footRefreshMouse
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: WeatherService.refresh()
                                }
                            }
                        }
                    }
                }

                Item {
                    id: minimalWrap
                    visible: root.isMinimal
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
                                            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingSmooth } }
                                            RotationAnimator on rotation {
                                                running: !WeatherService.hasData && Theme.animationsEnabled
                                                from: 0; to: 360
                                                duration: 900
                                                loops: Animation.Infinite
                                            }
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
                                            RotationAnimator on rotation {
                                                running: WeatherService.savingLocation && Theme.animationsEnabled
                                                from: 0; to: 360
                                                duration: 800
                                                loops: Animation.Infinite
                                            }
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
