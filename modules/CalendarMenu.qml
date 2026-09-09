pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../themes"
import "../Ui"
import "./calendar" as CalUI
import "./calendar/CalendarModel.js" as Cal

Scope {
    id: root
    property bool showCalendar: false
    signal dismissed()
    property bool _winVisible: showCalendar
    Timer { id: calHideTimer; interval: Theme.panelAnimExit + 20; repeat: false; onTriggered: if (!root.showCalendar) root._winVisible = false }
    onShowCalendarChanged: {
        if (showCalendar) { _winVisible = true; calHideTimer.stop() } else calHideTimer.restart()
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

    readonly property bool isMinimal: Theme.minimalTheme
    readonly property int cellWidth: isMinimal ? 52 : 48
    readonly property int cellHeight: isMinimal ? 34 : 30
    readonly property int cellSpacing: 2
    readonly property int weekColumnWidth: 32
    readonly property int gutterWidth: isMinimal ? 14 : 10
    readonly property int minimalGridWidth: weekColumnWidth + gutterWidth + 7 * cellWidth + 8 * cellSpacing
    readonly property string contentFontFamily: isMinimal ? Theme.iconFontFamily : Theme.fontFamily

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
                Behavior on x { enabled: calAnchor.valid && calLoader.width > 0 && calLoader.height > 0 && calSpring.offset === 0; NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingSmooth } }
                Behavior on y { enabled: calAnchor.valid && calLoader.width > 0 && calLoader.height > 0 && calSpring.offset === 0; NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingSmooth } }
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
                    width: root.isMinimal ? 560 : 658
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
                        implicitHeight: (root.isMinimal ? minimalWrap.implicitHeight + 36 : contentRow.implicitHeight + 24)
                        color: root.isMinimal ? Theme.bg : Theme.panelBg
                        border.color: root.isMinimal ? Theme.accent : Theme.panelBorderColor
                        border.width: root.isMinimal ? 2 : 1
                        radius: Theme.cornerRadius
                        clip: true
                        Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingSmooth } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.AllButtons
                        onClicked: mouse => mouse.accepted = true
                        onPressed: mouse => mouse.accepted = true
                        onWheel: wheel => wheel.accepted = true
                    }

                    RowLayout {
                        id: contentRow
                        visible: !root.isMinimal
                        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                        anchors.topMargin: 12; anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.bottomMargin: 12
                        spacing: 10
                        clip: true

                        ColumnLayout {
                            Layout.preferredWidth: 230
                            Layout.fillHeight: true
                            spacing: 10
                            CalUI.CalendarHeader { scope: root; showNav: false; vertical: true }
                            CalUI.CalendarFooter { scope: root }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            spacing: 8
                            CalUI.CalendarHeader { scope: root; showHero: false }
                            CalUI.CalendarGrid { scope: root }
                        }
                    }

                    Item {
                        id: minimalWrap
                        visible: root.isMinimal
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
                            CalUI.CalendarHeader { scope: root; showNav: false }
                            CalUI.CalendarFooter { scope: root }
                            CalUI.CalendarGrid { scope: root }
                            CalUI.CalendarHeader { scope: root; showHero: false }
                        }
                    }
                }
            }
        }
    }
}
