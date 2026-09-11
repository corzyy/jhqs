pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../themes"
import "../Ui"
import "./CalendarModel.js" as Cal

Scope {
    id: root
    property bool showCalendar: false
    signal dismissed()
    property bool _winVisible: showCalendar
    Timer { id: calHideTimer; interval: 0; repeat: false; onTriggered: if (!root.showCalendar) root._winVisible = false }
    onShowCalendarChanged: {
        if (showCalendar) { _winVisible = true; calHideTimer.stop() } else calHideTimer.restart()
    }

    // Merged from calendar/CalendarHeader.qml — month nav + hero date.
    component CalHeader: ColumnLayout {
        id: calHeaderRoot
        required property var scope
        property bool showNav: true
        property bool showHero: true
        property bool vertical: false

        Layout.fillWidth: true
        spacing: 8

        RowLayout {
            visible: calHeaderRoot.showNav
            Layout.fillWidth: true
            Layout.preferredHeight: monthLabel.implicitHeight + 10
            spacing: 8
            opacity: calHeaderRoot.scope.showCalendar ? 1 : 0
            transform: Translate {
                y: calHeaderRoot.scope.showCalendar ? 0 : 12
            }
            Rectangle {
                antialiasing: Theme.shapesAa
                Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 0
                color: "transparent"
                border.color: "transparent"
                border.width: 0
                scale: 1.0
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    anchors.centerIn: parent
                    text: "‹"
                    color: prevMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                    font.family: calHeaderRoot.scope.contentFontFamily; font.pixelSize: Theme.fs(18); font.bold: true
                }
                MouseArea { id: prevMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: calHeaderRoot.scope.moveMonth(-1) }
            }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                id: monthLabel
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                text: calHeaderRoot.scope.viewDate.toLocaleDateString(Qt.locale("en_US"), "MMMM yyyy").toUpperCase()
                color: Theme.textSecondary; font.family: calHeaderRoot.scope.contentFontFamily; font.pixelSize: Theme.fs(12); font.weight: Font.Bold; font.letterSpacing: 1
            }
            Rectangle {
                antialiasing: Theme.shapesAa
                Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 0
                color: "transparent"
                border.color: "transparent"
                border.width: 0
                scale: 1.0
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    anchors.centerIn: parent
                    text: "›"
                    color: nextMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                    font.family: calHeaderRoot.scope.contentFontFamily; font.pixelSize: Theme.fs(18); font.bold: true
                }
                MouseArea { id: nextMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: calHeaderRoot.scope.moveMonth(1) }
            }
        }


        Item {
            visible: calHeaderRoot.showHero
            Layout.fillWidth: true
            Layout.preferredHeight: minimalHeroRow.height
            opacity: calHeaderRoot.scope.showCalendar ? 1 : 0
            Row {
                id: minimalHeroRow
                anchors.centerIn: parent
                spacing: 22
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    anchors.baseline: minimalHeroDate.baseline
                    text: "󰃭"
                    color: minimalHeroMouse.containsMouse ? Theme.accent : Theme.textPrimary
                    font.family: calHeaderRoot.scope.contentFontFamily; font.pixelSize: Theme.fs(48)
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    id: minimalHeroDate
                    anchors.verticalCenter: parent.verticalCenter
                    text: calHeaderRoot.scope.today.toLocaleDateString(Qt.locale("en_US"), "MMMM d")
                    color: minimalHeroMouse.containsMouse ? Theme.accent : Theme.textPrimary
                    font.family: calHeaderRoot.scope.contentFontFamily
                    font.pixelSize: Theme.fs(52); font.weight: Font.Bold
                }
            }
            MouseArea {
                id: minimalHeroMouse
                x: minimalHeroRow.x; y: minimalHeroRow.y
                width: minimalHeroRow.width; height: minimalHeroRow.height
                enabled: !calHeaderRoot.scope.viewingCurrentMonth
                hoverEnabled: enabled
                cursorShape: Qt.PointingHandCursor
                onClicked: calHeaderRoot.scope.goToToday()
            }
        }
    }

    // Merged from calendar/CalendarGrid.qml — weekday header + month cells.
    component CalGrid: ColumnLayout {
        id: calGridRoot
        required property var scope

        Layout.fillWidth: true
        spacing: 3
        opacity: calGridRoot.scope.showCalendar ? 1 : 0
        transform: Translate {
            id: gridTrans
            x: 0
            y: calGridRoot.scope.showCalendar ? 0 : 12
        }
        Connections {
            target: calGridRoot.scope
            function onViewMonthChanged() { gridTrans.x = calGridRoot.scope._monthDir > 0 ? 14 : -14; slideBack.restart() }
            function onViewYearChanged() { gridTrans.x = calGridRoot.scope._monthDir > 0 ? 14 : -14; slideBack.restart() }
        }
        Timer { id: slideBack; interval: 10; repeat: false; onTriggered: gridTrans.x = 0 }

        Item {  Layout.fillWidth: true; Layout.preferredHeight: visible ? 10 : 0 }

        Row {
            id: headerRow
            Layout.fillWidth: true
            spacing: calGridRoot.scope.cellSpacing
            Rectangle {
                antialiasing: Theme.shapesAa
                width: calGridRoot.scope.weekColumnWidth; height: 16; radius: 0
                color: weekStartMouse.containsMouse ? Theme.bgHover : "transparent"
                scale: 1.0
                Text { anchors.centerIn: parent; text: "W"; color: weekStartMouse.containsMouse ? Theme.textPrimary : Theme.textMuted; font.family: calGridRoot.scope.contentFontFamily; font.pixelSize: Theme.fs(10); font.letterSpacing: 1; font.bold: true
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                MouseArea { id: weekStartMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: calGridRoot.scope.toggleWeekStart() }
            }
            Item { width: calGridRoot.scope.gutterWidth; height: 16}
            Repeater {
                model: calGridRoot.scope.weekdays
                delegate: Text {
                    required property var modelData
                    width: calGridRoot.scope.cellWidth; height: 16
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    text: calGridRoot.scope.weekdayLabel(modelData)
                    color: Theme.textMuted; font.family: calGridRoot.scope.contentFontFamily; font.pixelSize: Theme.fs(10); font.letterSpacing: 1; font.bold: true
                }
            }
        }

        Repeater {
            model: calGridRoot.scope.weeks
            delegate: Row {
                required property var modelData
                spacing: calGridRoot.scope.cellSpacing
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    width: calGridRoot.scope.weekColumnWidth; height: calGridRoot.scope.cellHeight
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    text: String(modelData.week)
                    color: Theme.textMuted; font.family: calGridRoot.scope.contentFontFamily; font.pixelSize: Theme.fs(10); opacity: 0.9
                }
                Item { width: calGridRoot.scope.gutterWidth; height: calGridRoot.scope.cellHeight }
                Repeater {
                    model: modelData.days
                    delegate: Rectangle {
                        required property var modelData
                        width: calGridRoot.scope.cellWidth; height: calGridRoot.scope.cellHeight; radius: 0
                        color: modelData.today ? ("transparent") : ("transparent")
                        border.width: modelData.today ? 1 : 0
                        border.color: Theme.withAlpha(Theme.textPrimary, 0.4)
                        scale: 1.0
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            id: dayText
                            anchors.centerIn: parent
                            text: String(modelData.day)
                            color: {
                                if (modelData.today) return Theme.textPrimary
                                if (!modelData.inMonth) return Theme.withAlpha(Theme.textMuted, 0.45)
                                if (modelData.weekend) return Theme.textSecondary
                                return Theme.textPrimary
                            }
                            font.family: calGridRoot.scope.contentFontFamily; font.pixelSize: Theme.fs(12); font.bold: modelData.today
                            opacity: modelData.inMonth ? 1.0 : 0.45
                        }
                        Connections {
                            target: calGridRoot.scope
                            function onShowCalendarChanged() {
                            }
                        }
                        MouseArea { id: dayMouse; anchors.fill: parent; hoverEnabled: true }
                    }
                }
            }
        }
    }

    // Merged from calendar/CalendarFooter.qml — year progress bar.
    component CalFooter: ColumnLayout {
        id: calFooterRoot
        required property var scope

        Layout.fillWidth: true
        spacing: 8
        opacity: calFooterRoot.scope.showCalendar ? 1 : 0
        transform: Translate {
            y: calFooterRoot.scope.showCalendar ? 0 : 12
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 14
            spacing: 12
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                text: String(calFooterRoot.scope.today.getFullYear())
                font.family: calFooterRoot.scope.contentFontFamily; font.pixelSize: Theme.fs(11)
                font.letterSpacing: 1
                color: Theme.textMuted
                Layout.alignment: Qt.AlignVCenter
            }
            Rectangle {
                antialiasing: Theme.shapesAa
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                height: 6; radius: 0
                color: Theme.withAlpha(Theme.textPrimary, 0.12)
                Rectangle {
                    antialiasing: Theme.shapesAa
                    width: Math.round(parent.width * calFooterRoot.scope.yearDone)
                    height: parent.height
                    color: Theme.accent
                }
            }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                text: calFooterRoot.scope.yearDonePercent + "%"
                font.family: calFooterRoot.scope.contentFontFamily; font.pixelSize: Theme.fs(11)
                color: Theme.textPrimary
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
    readonly property int barT: Theme.barThickness
    readonly property string barPos: Theme.barPosition
    readonly property int screenGap: 6
    property int panelGap: screenGap - Theme.barThickness

    FileView {
        id: calendarSettingsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/config/calendar.json"
        watchChanges: true
        onFileChanged: reload()
        blockLoading: true
        printErrors: false
        adapter: JsonAdapter {
            property string weekStartDay: "sunday"
        }
    }
    Process { id: calendarSettingsInitProc; command: ["bash", "-c", "echo"] }
    Timer {
        id: calendarSettingsInitTimer
        interval: 700
        running: true
        repeat: false
        onTriggered: {
            if (!calendarSettingsInitProc.running) {
                calendarSettingsInitProc.command = ["bash", "-c", "mkdir -p ~/.config/quickshell/jhqs; if [ ! -f ~/.config/quickshell/jhqs/config/calendar.json ]; then echo '{\"weekStartDay\":\"sunday\"}' > ~/.config/quickshell/jhqs/config/calendar.json; fi; echo done"]
                calendarSettingsInitProc.running = true
            }
        }
    }

    property date today: new Date()
    readonly property string todayKey: Cal.keyForDate(today)
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()
    readonly property date viewDate: new Date(viewYear, viewMonth, 1)
    readonly property bool viewingCurrentMonth: viewYear === today.getFullYear() && viewMonth === today.getMonth()

    readonly property real yearDone: Cal.yearProgress(today.getFullYear(), today.getMonth(), today.getDate())
    readonly property int yearDonePercent: Cal.yearProgressPercent(today.getFullYear(), today.getMonth(), today.getDate())

    readonly property int weekStart: Cal.normalizedWeekStart(calendarSettingsFile.adapter.weekStartDay, 0)
    readonly property var labelLocale: Qt.locale("en_US")
    readonly property var weekdays: Cal.weekdayOrder(weekStart)
    readonly property var weeks: Cal.monthGrid(viewYear, viewMonth, weekStart, todayKey)

    readonly property int cellWidth: 52
    readonly property int cellHeight: 34
    readonly property int cellSpacing: 2
    readonly property int weekColumnWidth: 32
    readonly property int gutterWidth: 14
    readonly property int minimalGridWidth: weekColumnWidth + gutterWidth + 7 * cellWidth + 8 * cellSpacing
    readonly property string contentFontFamily: Theme.iconFontFamily

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
        onDateChanged: {
            if (Cal.keyForDate(date) === root.todayKey) return
            var followToday = root.viewingCurrentMonth
            root.today = date
            if (followToday) goToToday()
        }
    }

    IpcHandler {
        target: "calendar"
        function toggle(): void { }
        function open(): void { }
        function close(): void { }
        function nextMonth(): void { root.moveMonth(1) }
        function prevMonth(): void { root.moveMonth(-1) }
        function state(): string { return "calendar=" + root.showCalendar + " view=" + root.viewYear + "-" + (root.viewMonth+1) }
    }

    function goToToday() { viewYear = today.getFullYear(); viewMonth = today.getMonth() }
    property int _monthDir: 0
    function moveMonth(delta) {
        _monthDir = delta
        var nxt = Cal.stepMonth(viewYear, viewMonth, delta)
        viewYear = nxt.year; viewMonth = nxt.month
    }
    function moveYear(delta) { moveMonth(delta * 12) }
    function persistWeekStart(day) {
        var next = Cal.normalizedWeekStart(day, root.weekStart)
        if (next === root.weekStart) return
        calendarSettingsFile.adapter.weekStartDay = Cal.weekStartSettingName(next)
        calendarSettingsFile.writeAdapter()
    }
    function toggleWeekStart() { persistWeekStart(Cal.toggledWeekStart(root.weekStart)) }
    function weekdayLabel(weekday) { return String(labelLocale.dayName(weekday, Locale.ShortFormat)).toUpperCase() }

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
            WlrLayershell.namespace: "calendar"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            MouseArea { anchors.fill: parent; onClicked: root.dismissed() }

            Loader {
                id: calLoader
                active: true
                BarAnchor {
                    id: calAnchor
                    moduleId: "clock"
                    barPos: root.barPos
                    panelWidth: calLoader.width
                    panelHeight: calLoader.height
                    screenWidth: calLoader.parent.width
                    screenHeight: calLoader.parent.height
                    gap: root.panelGap
                    fallbackX: (calLoader.parent.width - calLoader.width) / 2
                    fallbackY: calLoader.parent.height - calLoader.height - root.panelGap
                }
                x: calAnchor.panelX
                y: calAnchor.panelY
                PanelSpring {
                    id: calSpring
                    slideFade: true
                    shown: root.showCalendar
                    hiddenX: root.barPos === "left" ? -(calLoader.width + 5) : root.barPos === "right" ? (calLoader.width + 5) : 0
                    hiddenY: root.barPos === "top" ? -(calLoader.height + 5) : root.barPos === "bottom" ? (calLoader.height + 5) : 0
                }
                visible: calSpring.boxVisible
                opacity: calSpring.fade
                scale: calSpring.zoom
                transformOrigin: calAnchor.origin
                transform: Translate { x: calSpring.slideX; y: calSpring.slideY }
                sourceComponent: Item {
                    id: popupRoot
                    width: 560
                    implicitHeight: outerRect.implicitHeight
                    height: outerRect.implicitHeight
                    focus: true

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) { root.dismissed(); event.accepted = true }
                        else if (event.key === Qt.Key_Left) { root.moveMonth(-1); event.accepted = true }
                        else if (event.key === Qt.Key_Right) { root.moveMonth(1); event.accepted = true }
                        else if (event.key === Qt.Key_Up) { root.moveYear(-1); event.accepted = true }
                        else if (event.key === Qt.Key_Down) { root.moveYear(1); event.accepted = true }
                        else if (event.key === Qt.Key_Home || event.text === "t" || event.text === "T") { root.goToToday(); event.accepted = true }
                        else if (event.text === "w" || event.text === "W") { root.toggleWeekStart(); event.accepted = true }
                    }
                    Component.onCompleted: forceActiveFocus()
                    Connections {
                        target: root
                        function onShowCalendarChanged() {
                            if (root.showCalendar) {
                                root.today = new Date(); root.goToToday()
                                Qt.callLater(function() { popupRoot.forceActiveFocus() })
                            }
                        }
                    }
                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: event => {
                            if (event.angleDelta.y === 0) return
                            root.moveMonth(event.angleDelta.y > 0 ? -1 : 1)
                            event.accepted = true
                        }
                    }

                    Rectangle {
                        antialiasing: Theme.shapesAa
                        id: outerRect
                        anchors.fill: parent
                        implicitHeight: minimalWrap.implicitHeight + 36
                        color: Theme.bg
                        border.color: Theme.accent
                        border.width: 2
                        radius: Theme.cornerRadius
                        clip: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.AllButtons
                        onClicked: mouse => mouse.accepted = true
                        onPressed: mouse => mouse.accepted = true
                        onWheel: wheel => wheel.accepted = true
                    }


                    Item {
                        id: minimalWrap
                        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                        anchors.topMargin: 18; anchors.leftMargin: 18; anchors.rightMargin: 18; anchors.bottomMargin: 18
                        implicitHeight: minimalCol.implicitHeight
                        height: minimalCol.implicitHeight
                        clip: true
                        ColumnLayout {
                            id: minimalCol
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: root.minimalGridWidth
                            spacing: 8
                            CalHeader { scope: root; showNav: false }
                            CalFooter { scope: root }
                            CalGrid { scope: root }
                            CalHeader { scope: root; showHero: false }
                        }
                    }
                }
            }
        }
    }
}
