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
    Timer { id: hideTimer; interval: Theme.panelHideDelay; repeat: false; onTriggered: if (!root.showWeather) root._winVisible = false }
    onShowWeatherChanged: {
        if (showWeather) { _winVisible = true; hideTimer.stop() } else hideTimer.restart()
    }
    readonly property string barPos: Theme.barPosition
    // Attached-bar morph: tuck under the bar edge (see Theme.panelAttachOverlap)
    // instead of floating detached below it.
    property int panelGap: -(Theme.barThickness + Theme.panelAttachOverlap)

    IpcHandler {
        target: "weather"
        function refresh(): string { WeatherService.refresh(); return "refreshing " + WeatherService.status() }
        function status(): string { return WeatherService.status() }
        function state(): string { return "weather=" + root.showWeather + " " + WeatherService.status() + " o=" + root.springDbg.toFixed(3) }
        function setUnit(u: string): string { return WeatherService.setUnit(u) }
        function setRefreshMinutes(n: int): string { return WeatherService.setRefreshMinutes(n) }
    }

    readonly property string heroTitle: WeatherService.reportLocation !== "" ? WeatherService.reportLocation : "No location set"
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
    readonly property string heroSub: {
        if (!WeatherService.hasData) return ""
        return WeatherService.reportFeels !== "" ? "Feels " + WeatherService.reportFeels : ""
    }
    readonly property string statusText: WeatherService.hasData ? (WeatherService.reportTempNum + WeatherService.tempUnit) : "…"
    readonly property bool statusOk: WeatherService.hasData

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root._winVisible && Theme.isPrimaryScreen(modelData)
            color: "transparent"
            exclusiveZone: 0
            anchors { top: true; left: true; right: true; bottom: true }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "weather"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            // Disabled while the panel is closing: during a morph handoff
            // the outgoing window stays mapped for panelHideDelay and must
            // not eat the click that belongs to the panel now on top.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                enabled: root.showWeather
                onClicked: root.dismissed()
            }
            // Caelestia popout (Ui/CaelestiaPopout): curtain reveal from
            // behind the bar edge + slide + nested fades, all off one
            // offsetScale driver (1:1 with caelestia-dots/shell).
            CaelestiaPopout {
                id: wxPopout
                shown: root.showWeather
                morphId: "weather"
                morphActive: Theme.isPrimaryScreen(modelData)
                barPos: root.barPos
                fullWidth: 560
                fullHeight: wxBox.implicitHeight
                anchorCenter: wxAnchor.isVertical ? wxAnchor.cy : wxAnchor.cx
                edge: root.barPos === "bottom" ? wxAnchor.panelY + wxBox.implicitHeight : root.barPos === "right" ? wxAnchor.panelX + 560 : root.barPos === "left" ? wxAnchor.panelX : wxAnchor.panelY
                screenSize: wxAnchor.isVertical ? wxAnchor.screenHeight : wxAnchor.screenWidth
                margin: wxAnchor.margin
                onOffsetScaleChanged: root.springDbg = offsetScale

                BarAnchor {
                    id: wxAnchor
                    moduleId: "weather"
                    barPos: root.barPos
                    panelWidth: 560
                    panelHeight: wxBox.implicitHeight
                    screenWidth: wxPopout.parent.width
                    screenHeight: wxPopout.parent.height
                    gap: root.panelGap
                    fallbackX: (wxPopout.parent.width - 560) / 2
                    fallbackY: wxPopout.parent.height - wxBox.implicitHeight - root.panelGap
                }

                Rectangle {
                        antialiasing: Theme.shapesAa
                        id: wxBox
                        // The popout owns position/size: the card fills the
                        // holder, its implicit height is the open geometry the
                        // popout glides to when the forecast swaps.
                        width: parent.width
                        height: parent.height
                        function startLocationEdit(): void {
                            WeatherService.beginEditingLocation()
                            Qt.callLater(function() {
                                var f = locationField
                                f.text = WeatherService.configuredLocation
                                f.selectAll()
                                f.forceActiveFocus()
                            })
                        }
                        implicitHeight: Math.max(120, Math.min(contentCol.implicitHeight + 20, wxAnchor.screenHeight - wxAnchor.edgeOffset - 24))
                        // Fill comes from the popout's shadow layer (see
                        // CaelestiaPopout shadowSource): it paints the same
                        // rounded silhouette behind this card, so the shadow
                        // silhouette is only composited once.
                        color: "transparent"
                        border.color: Theme.panelBorderColor
                        border.width: 2
                        radius: Theme.cornerRadius
                        // Unclipped: the fillets paint outside the box; the inner
                        // Flickable already clips its own content.
                        clip: false
                        // Square fused corners (tray-menu joint); plain children,
                        // so they emerge with the card exactly like the box.
                        PanelCorner { fillColor: Theme.panelWindowBg; side: "left"; edge: root.barPos === "bottom" ? "bottom" : "top"; visible: wxPopout.offsetScale < 1 }
                        PanelCorner { fillColor: Theme.panelWindowBg; side: "right"; edge: root.barPos === "bottom" ? "bottom" : "top"; visible: wxPopout.offsetScale < 1 }
                        // Outward-curved shoulders on top of the fusion (Caelestia joint).
                        PanelFillet { fillColor: Theme.panelWindowBg; side: "left"; edge: root.barPos === "bottom" ? "bottom" : "top"; visible: wxPopout.offsetScale < 1 }
                        PanelFillet { fillColor: Theme.panelWindowBg; side: "right"; edge: root.barPos === "bottom" ? "bottom" : "top"; visible: wxPopout.offsetScale < 1 }
                        // Seam strip: erases the collar outline along the fused edge.
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            visible: Theme.panelAccentBorder
                            x: 0
                            y: root.barPos === "bottom" ? wxBox.height - 2 : 0
                            width: wxBox.width
                            height: 2
                            color: Theme.panelWindowBg
                        }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.AllButtons
                        // Off while closing: the window outlives the card
                        // (morph/close hold) and must not steal input.
                        enabled: root.showWeather
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
                        // Content travels on the popout's own driver (frame
                        // stretches first, content settles after) and keeps
                        // the full panel size so nothing reflows mid-stretch.
                        // contentFade hides it while the card morphs over to
                        // another panel's pose.
                        opacity: wxPopout.contentFade
                        x: 10 + wxPopout.contentX
                        y: 10 + wxPopout.contentY
                        width: wxPopout.fullWidth - 20
                        height: wxPopout.fullHeight - 20
                        contentHeight: contentCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: contentHeight > height
                        Column {
                            id: contentCol
                            // Full box width (never the growing pill width): no
                            // reflow mid-morph; the Flickable clip reveals it.
                            width: 560 - 20
                            spacing: 8
                            // Header: title + status pill + actions.
                            // The pinpoint is the only place to change the location.
                            RowLayout {
                                width: parent.width
                                spacing: 6
                                Text {
                                    text: root.heroTitle
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fs(13)
                                    font.weight: Font.Bold
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                                Rectangle {
                                    Layout.preferredHeight: 20
                                    Layout.preferredWidth: Math.max(52, statusTxt.implicitWidth + 18)
                                    radius: 10
                                    color: root.statusOk ? Theme.withAlpha(Theme.accent, 0.16) : Theme.withAlpha(Theme.textPrimary, 0.06)
                                    border.color: root.statusOk ? Theme.accent : Theme.divider
                                    border.width: 1
                                    Text {
                                        id: statusTxt
                                        anchors.centerIn: parent
                                        text: root.statusText
                                        color: root.statusOk ? Theme.textPrimary : Theme.textSecondary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fs(10)
                                        font.weight: Font.Bold
                                        font.letterSpacing: 1.0
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                    }
                                }
                                PanelKit.IconButton {
                                    glyph: "󰍎"
                                    active: WeatherService.editingLocation
                                    onClicked: {
                                        if (WeatherService.editingLocation) WeatherService.cancelEditingLocation()
                                        else wxBox.startLocationEdit()
                                    }
                                }
                                PanelKit.IconButton {
                                    glyph: "↻"
                                    onClicked: WeatherService.refresh()
                                }
                            }
                            // Location search editor — M3 fade enter/exit
                            // (stays in layout until the fade-out finished,
                            // then the panel height glides).
                            PanelKit.Card {
                                readonly property bool locEditing: WeatherService.editingLocation
                                opacity: locEditing ? 1 : 0
                                visible: opacity > 0.01
                                Behavior on opacity {
                                    enabled: Theme.animationsEnabled
                                    NumberAnimation { duration: Theme.durSmall; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMotion }
                                }
                                width: parent.width
                                implicitHeight: locCol.implicitHeight + 20
                                ColumnLayout {
                                    id: locCol
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 6
                                    PanelKit.SectionLabel { text: "SEARCH LOCATION" }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 36
                                            radius: Theme.cornerRadiusSmall
                                            antialiasing: Theme.shapesAa
                                            color: Theme.withAlpha(Theme.textPrimary, 0.04)
                                            border.color: locationField.activeFocus ? Theme.accent : Theme.divider
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
                                                font.family: Theme.fontFamily
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
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fs(12)
                                                antialiasing: Theme.textAa
                                                renderType: Theme.textRenderType
                                            }
                                        }
                                        Rectangle {
                                            Layout.preferredWidth: 34; Layout.preferredHeight: 36
                                            radius: Theme.cornerRadiusSmall
                                            antialiasing: Theme.shapesAa
                                            color: "transparent"
                                            border.color: Theme.divider
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
                                            StateLayer {
                                                id: clearMouse
                                                disabled: WeatherService.savingLocation
                                                radius: Theme.cornerRadiusSmall
                                                color: Theme.textPrimary
                                                onClicked: { WeatherService.clearLocation(); keyCatcher.forceActiveFocus() }
                                            }
                                        }
                                    }
                                    Column {
                                        visible: !WeatherService.savingLocation && WeatherService.locationSuggestions.length > 0
                                        width: parent.width
                                        spacing: 2
                                        Repeater {
                                            model: WeatherService.locationSuggestions
                                            delegate: Rectangle {
                                                required property var modelData
                                                required property int index
                                                width: parent.width
                                                implicitHeight: 36
                                                radius: Theme.cornerRadiusSmall
                                                antialiasing: Theme.shapesAa
                                                color: index === WeatherService.suggestionIndex ? Theme.withAlpha(Theme.accent, 0.14) : "transparent"
                                                border.color: index === WeatherService.suggestionIndex ? Theme.withAlpha(Theme.accent, 0.55) : "transparent"
                                                border.width: index === WeatherService.suggestionIndex ? 1 : 0
                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 10
                                                    anchors.rightMargin: 10
                                                    spacing: 8
                                                    Text {
                                                        Layout.fillWidth: true
                                                        Layout.alignment: Qt.AlignVCenter
                                                        text: modelData.name
                                                        color: index === WeatherService.suggestionIndex ? Theme.textPrimary : Theme.textSecondary
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: Theme.fs(12)
                                                        font.weight: index === WeatherService.suggestionIndex ? Font.DemiBold : Font.Normal
                                                        elide: Text.ElideRight
                                                        antialiasing: Theme.textAa
                                                        renderType: Theme.textRenderType
                                                    }
                                                    Text {
                                                        visible: text !== ""
                                                        Layout.alignment: Qt.AlignVCenter
                                                        text: modelData.description
                                                        color: Theme.textMuted
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: Theme.fs(10)
                                                        elide: Text.ElideRight
                                                        antialiasing: Theme.textAa
                                                        renderType: Theme.textRenderType
                                                    }
                                                }
                                                StateLayer {
                                                    id: sugMouse
                                                    radius: Theme.cornerRadiusSmall
                                                    color: Theme.accent
                                                    onPositionChanged: WeatherService.suggestionIndex = index
                                                    onClicked: { WeatherService.pickSuggestion(modelData); keyCatcher.forceActiveFocus() }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            // Middle row: now left, forecast right.
                            RowLayout {
                                width: parent.width
                                spacing: 8
                            // Hero now card. The set location lives here, under the temp.
                            PanelKit.Card {
                                Layout.preferredWidth: 296
                                Layout.alignment: Qt.AlignTop
                                implicitHeight: Math.max(heroCol.implicitHeight, fcCol.implicitHeight) + 20
                                ColumnLayout {
                                    id: heroCol
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 6
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10
                                        Rectangle {
                                            Layout.preferredWidth: 40; Layout.preferredHeight: 40
                                            Layout.alignment: Qt.AlignVCenter
                                            radius: Theme.cornerRadiusSmall
                                            color: WeatherService.hasData ? Theme.withAlpha(Theme.accent, 0.18) : Theme.withAlpha(Theme.textPrimary, 0.06)
                                            border.color: WeatherService.hasData ? Theme.withAlpha(Theme.accent, 0.5) : Theme.divider
                                            border.width: 1
                                            Text {
                                                anchors.centerIn: parent
                                                text: WeatherService.label || "—"
                                                color: WeatherService.hasData ? Theme.textPrimary : Theme.textMuted
                                                font.family: Theme.iconFontFamily
                                                font.pixelSize: Theme.fs(19)
                                                antialiasing: Theme.textAa
                                                renderType: Theme.textRenderType
                                            }
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: 2
                                            PanelKit.SectionLabel { text: "NOW" }
                                            Row {
                                                spacing: 2
                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: WeatherService.hasData ? WeatherService.reportTempNum : "—"
                                                    color: Theme.textPrimary
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fs(22)
                                                    font.weight: Font.Bold
                                                    antialiasing: Theme.textAa
                                                    renderType: Theme.textRenderType
                                                }
                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    anchors.verticalCenterOffset: -5
                                                    text: WeatherService.tempUnit
                                                    color: Theme.textSecondary
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fs(11)
                                                    font.weight: Font.Bold
                                                    antialiasing: Theme.textAa
                                                    renderType: Theme.textRenderType
                                                }
                                            }
                                        }
                                        PanelKit.TogglePill {
                                            Layout.alignment: Qt.AlignVCenter
                                            on: !WeatherService.useImperial
                                            onText: "°C"
                                            offText: "°F"
                                            offBgAlpha: 0.06
                                            offBorderColor: Theme.divider
                                            onClicked: WeatherService.setUnit(WeatherService.useImperial ? "metric" : "imperial")
                                        }
                                    }
                                    Text {
                                        visible: text !== ""
                                        Layout.fillWidth: true
                                        text: root.heroMeta
                                        color: Theme.textSecondary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fs(10)
                                        font.weight: Font.Bold
                                        font.letterSpacing: 1.2
                                        elide: Text.ElideRight
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                    }
                                    Text {
                                        visible: text !== ""
                                        Layout.fillWidth: true
                                        text: root.heroSub
                                        color: Theme.textMuted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fs(10)
                                        elide: Text.ElideRight
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                    }
                                    GridLayout {
                                        visible: WeatherService.hasData
                                        Layout.fillWidth: true
                                        columns: 3
                                        columnSpacing: 12
                                        rowSpacing: 4
                                        Repeater {
                                            model: ["Feels", "Wind", "Humidity"]
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
                                                    text: modelData.toUpperCase()
                                                    color: Theme.textMuted
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fs(10)
                                                    font.weight: Font.Bold
                                                    font.letterSpacing: 1.0
                                                    antialiasing: Theme.textAa
                                                    renderType: Theme.textRenderType
                                                }
                                                Text {
                                                    text: statValue
                                                    color: Theme.textPrimary
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fs(12)
                                                    font.weight: Font.DemiBold
                                                    elide: Text.ElideRight
                                                    width: parent.width
                                                    antialiasing: Theme.textAa
                                                    renderType: Theme.textRenderType
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                                // Forecast card.
                                PanelKit.Card {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    implicitHeight: Math.max(heroCol.implicitHeight, fcCol.implicitHeight) + 20
                                ColumnLayout {
                                    id: fcCol
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 6
                                    PanelKit.SectionLabel { text: "NEXT 3 DAYS" }
                                    Repeater {
                                        model: root.showWeather ? WeatherService.forecastDays : []
                                        delegate: Rectangle {
                                            required property var modelData
                                            readonly property string fIcon: WeatherService.dayIcon(modelData)
                                            readonly property string fName: WeatherService.dayName(modelData.date).toUpperCase()
                                            readonly property string fMax: WeatherService.bareTempForDay(modelData, "max")
                                            readonly property string fMin: WeatherService.bareTempForDay(modelData, "min")
                                            Layout.fillWidth: true
                                            implicitHeight: 40
                                            radius: Theme.cornerRadiusSmall
                                            antialiasing: Theme.shapesAa
                                            color: "transparent"
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8
                                                spacing: 8
                                                Text {
                                                    text: fIcon
                                                    color: Theme.textPrimary
                                                    font.family: Theme.iconFontFamily
                                                    font.pixelSize: Theme.fs(16)
                                                    Layout.preferredWidth: 24
                                                    horizontalAlignment: Text.AlignHCenter
                                                    Layout.alignment: Qt.AlignVCenter
                                                    antialiasing: Theme.textAa
                                                    renderType: Theme.textRenderType
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    Layout.alignment: Qt.AlignVCenter
                                                    text: fName
                                                    color: Theme.textPrimary
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fs(11)
                                                    font.weight: Font.DemiBold
                                                    font.letterSpacing: 0.6
                                                    elide: Text.ElideRight
                                                    antialiasing: Theme.textAa
                                                    renderType: Theme.textRenderType
                                                }
                                                Text {
                                                    Layout.alignment: Qt.AlignVCenter
                                                    text: fMin
                                                    color: Theme.textSecondary
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fs(12)
                                                    antialiasing: Theme.textAa
                                                    renderType: Theme.textRenderType
                                                }
                                                Text {
                                                    Layout.alignment: Qt.AlignVCenter
                                                    text: fMax
                                                    color: Theme.textPrimary
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fs(12)
                                                    font.weight: Font.Bold
                                                    antialiasing: Theme.textAa
                                                    renderType: Theme.textRenderType
                                                }
                                            }
                                        }
                                    }
                                    Text {
                                        visible: WeatherService.forecastDays.length === 0
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignCenter
                                        text: WeatherService.hasData ? "No forecast yet" : "Fetching forecast…"
                                        color: Theme.textMuted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fs(11)
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                    }
                                }
                            }
                            } // middle row
                        }
                    }
                }
            }
        }
    }
}
