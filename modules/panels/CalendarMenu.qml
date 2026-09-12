pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../themes"
import "../../services"
import "../../Ui"
import "./CalendarModel.js" as Cal

Scope {
    id: root
    property bool showCalendar: false
    signal dismissed()
    property var notifServer: null
    property bool _winVisible: showCalendar
    Timer { id: calHideTimer; interval: 0; repeat: false; onTriggered: if (!root.showCalendar) root._winVisible = false }
    // PERF: shared debounce for wheel + arrow-key month navigation.
    Timer { id: _monthNavDebounce; interval: 100; repeat: false }
    onShowCalendarChanged: {
        if (showCalendar) { _winVisible = true; calHideTimer.stop() } else calHideTimer.restart()
    }

    // --- Month navigation header: prev / month-year / next + Today pill.
    component CalHeader: ColumnLayout {
        id: calHeaderRoot
        required property var scope
        property bool showNav: true

        Layout.fillWidth: true
        spacing: 4

        RowLayout {
            visible: calHeaderRoot.showNav
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            spacing: 4
            opacity: calHeaderRoot.scope.showCalendar ? 1 : 0

            Rectangle {
                antialiasing: Theme.shapesAa
                Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 0
                color: prevMouse.containsMouse ? Theme.bgHover : "transparent"
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
            Item { Layout.fillWidth: true; Layout.preferredHeight: 32
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    id: monthLabel
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    text: calHeaderRoot.scope.viewDate.toLocaleDateString(Qt.locale("en_US"), "MMMM yyyy")
                    color: Theme.textPrimary; font.family: calHeaderRoot.scope.contentFontFamily; font.pixelSize: Theme.fs(15); font.weight: Font.DemiBold
                }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true; cursorShape: calHeaderRoot.scope.viewingCurrentMonth ? Qt.ArrowCursor : Qt.PointingHandCursor
                    enabled: !calHeaderRoot.scope.viewingCurrentMonth
                    onClicked: calHeaderRoot.scope.goToToday()
                }
            }
            // Today pill — only when drifted away from current month.
            Rectangle {
                antialiasing: Theme.shapesAa
                visible: !calHeaderRoot.scope.viewingCurrentMonth
                Layout.preferredWidth: todayLabel.implicitWidth + 20; Layout.preferredHeight: 26; radius: 0
                color: todayMouse.containsMouse ? Theme.bgHover : Theme.withAlpha(Theme.textPrimary, 0.08)
                border.color: Theme.divider
                border.width: 1
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    id: todayLabel
                    anchors.centerIn: parent
                    text: "Today"
                    color: Theme.textPrimary
                    font.family: calHeaderRoot.scope.contentFontFamily; font.pixelSize: Theme.fs(11); font.weight: Font.Medium
                }
                MouseArea { id: todayMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: calHeaderRoot.scope.goToToday() }
            }
            Rectangle {
                antialiasing: Theme.shapesAa
                Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 0
                color: nextMouse.containsMouse ? Theme.bgHover : "transparent"
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
    }

    // --- Selected-day hero: big day number + weekday / meta. Click = back to today.
    component CalHero: Item {
        id: heroRoot
        required property var scope
        Layout.fillWidth: true
        Layout.preferredHeight: 62
        opacity: heroRoot.scope.showCalendar ? 1 : 0

        Row {
            id: heroRow
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                id: heroDayNum
                anchors.verticalCenter: parent.verticalCenter
                text: heroRoot.scope.selectedDate.getDate()
                color: heroMouse.containsMouse ? Theme.accent : Theme.textPrimary
                font.family: heroRoot.scope.contentFontFamily
                font.pixelSize: Theme.fs(44); font.weight: Font.Bold
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    text: heroRoot.scope.selectedDate.toLocaleDateString(Qt.locale("en_US"), "dddd")
                    color: Theme.textPrimary
                    font.family: heroRoot.scope.contentFontFamily; font.pixelSize: Theme.fs(14); font.weight: Font.DemiBold
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    text: heroRoot.scope.selectedDate.toLocaleDateString(Qt.locale("en_US"), "MMMM yyyy")
                    color: Theme.textSecondary
                    font.family: heroRoot.scope.contentFontFamily; font.pixelSize: Theme.fs(12)
                }
            }
        }
        MouseArea {
            id: heroMouse
            anchors.fill: parent
            enabled: heroRoot.scope.selectedKey !== heroRoot.scope.todayKey || !heroRoot.scope.viewingCurrentMonth
            hoverEnabled: enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: heroRoot.scope.goToToday()
        }
    }

    // --- Month grid: pill day cells with today / selected / hover states.
    component CalGrid: ColumnLayout {
        id: calGridRoot
        required property var scope

        Layout.fillWidth: true
        spacing: 2
        opacity: calGridRoot.scope.showCalendar ? 1 : 0

        Row {
            id: headerRow
            Layout.alignment: Qt.AlignHCenter
            spacing: calGridRoot.scope.cellSpacing
            Repeater {
                model: calGridRoot.scope.weekdays
                delegate: Text {
                    required property var modelData
                    width: calGridRoot.scope.cellWidth; height: 18
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    text: calGridRoot.scope.weekdayLabel(modelData)
                    color: Theme.textMuted; font.family: calGridRoot.scope.contentFontFamily; font.pixelSize: Theme.fs(10); font.bold: true
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
            }
        }

        Repeater {
            model: calGridRoot.scope.weeks
            delegate: Row {
                required property var modelData
                Layout.alignment: Qt.AlignHCenter
                spacing: calGridRoot.scope.cellSpacing
                Repeater {
                    model: modelData.days
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool isToday: modelData.key === calGridRoot.scope.todayKey
                        readonly property bool isSelected: modelData.key === calGridRoot.scope.selectedKey
                        width: calGridRoot.scope.cellWidth; height: calGridRoot.scope.cellHeight; radius: 0
                        color: {
                            if (isToday) return Theme.accent
                            if (isSelected) return Theme.withAlpha(Theme.accent, 0.22)
                            if (dayMouse.containsMouse) return Theme.bgHover
                            return "transparent"
                        }
                        border.width: (!isToday && isSelected) ? 1 : 0
                        border.color: Theme.accent
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            anchors.centerIn: parent
                            text: String(modelData.day)
                            color: {
                                if (parent.isToday) return Theme.onAccent
                                if (!modelData.inMonth) return Theme.withAlpha(Theme.textMuted, 0.55)
                                if (parent.isSelected) return Theme.textPrimary
                                if (modelData.weekend) return Theme.textSecondary
                                return Theme.textPrimary
                            }
                            font.family: calGridRoot.scope.contentFontFamily; font.pixelSize: Theme.fs(12); font.bold: parent.isToday || parent.isSelected
                            opacity: modelData.inMonth ? 1.0 : 0.55
                        }
                        MouseArea {
                            id: dayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calGridRoot.scope.selectDay(modelData)
                        }
                    }
                }
            }
        }
    }

    // --- Footer: slim year progress.
    component CalFooter: ColumnLayout {
        id: calFooterRoot
        required property var scope

        Layout.fillWidth: true
        opacity: calFooterRoot.scope.showCalendar ? 1 : 0

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 14
            spacing: 10
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                text: String(calFooterRoot.scope.today.getFullYear())
                font.family: calFooterRoot.scope.contentFontFamily; font.pixelSize: Theme.fs(11)
                color: Theme.textMuted
                Layout.alignment: Qt.AlignVCenter
            }
            Rectangle {
                antialiasing: Theme.shapesAa
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                height: 4; radius: 0
                color: Theme.withAlpha(Theme.textPrimary, 0.12)
                Rectangle {
                    antialiasing: Theme.shapesAa
                    width: Math.round(parent.width * calFooterRoot.scope.yearDone)
                    height: parent.height
                    radius: 0
                    color: Theme.accent
                }
            }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                text: calFooterRoot.scope.yearDonePercent + "%"
                font.family: calFooterRoot.scope.contentFontFamily; font.pixelSize: Theme.fs(11)
                color: Theme.textSecondary
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    // --- Single notification card (swipe-to-dismiss). Instantiated per
    // entry inside the app groups below.
    component NotifCard: Rectangle {
        id: cardRoot
        required property var scope
        required property var entry
        property bool leaving: false
        // Minimized stacks set this: tapping the card expands its group
        // instead of doing nothing (swipe still dismisses).
        property bool expandOnClick: false
        signal expandRequested()
        implicitHeight: notifInner.implicitHeight + 20
        height: leaving ? 0 : implicitHeight
        Behavior on height { enabled: cardRoot.leaving; NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
        opacity: leaving ? 0 : 1.0 - Math.min(0.5, Math.abs(swipeProxy.x) / Math.max(1, width) * 0.7)
        Behavior on opacity { enabled: cardRoot.leaving; NumberAnimation { duration: 160 } }
        transform: Translate { x: swipeProxy.x }
        clip: true
        radius: 0
        color: (entry.urgency === 2) ? Theme.error_container : Theme.withAlpha(Theme.textPrimary, 0.05)
        border.color: (entry.urgency === 2) ? Theme.errorColor : Theme.divider
        border.width: 1
        Item { id: swipeProxy; x: 0 }
        NumberAnimation { id: snapBack; target: swipeProxy; property: "x"; to: 0; duration: 160; easing.type: Easing.OutCubic }
        NumberAnimation {
            id: flyOut
            target: swipeProxy; property: "x"; duration: 160; easing.type: Easing.InQuad
            onFinished: { cardRoot.leaving = true; byeTimer.restart() }
        }
        Timer { id: byeTimer; interval: 220; repeat: false; onTriggered: cardRoot.scope.dismissHistoryEntry(cardRoot.entry) }
        MouseArea {
            id: swipeMouse
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            enabled: !cardRoot.leaving
            hoverEnabled: true
            cursorShape: cardRoot.expandOnClick ? Qt.PointingHandCursor : Qt.ArrowCursor
            drag.target: swipeProxy
            drag.axis: Drag.XAxis
            drag.minimumX: -cardRoot.width
            drag.maximumX: cardRoot.width
            drag.smoothed: false
            onPressed: mouse => { snapBack.stop(); flyOut.stop() }
            onReleased: {
                let dx = swipeProxy.x
                if (Math.abs(dx) > 90) {
                    flyOut.to = (dx >= 0 ? 1 : -1) * (cardRoot.width + 40)
                    flyOut.start()
                } else {
                    snapBack.start()
                }
            }
            onCanceled: snapBack.start()
            onClicked: {
                // Tap (not drag) on a minimized-stack card expands its group.
                try { if (Math.abs(swipeProxy.x) > 8) return } catch (e) { }
                if (cardRoot.expandOnClick) cardRoot.expandRequested()
            }
        }
        Column {
            id: notifInner
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.topMargin: 10
            anchors.bottomMargin: 10
            spacing: 3
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                width: parent.width
                horizontalAlignment: Text.AlignRight
                text: cardRoot.scope.timeAgo(cardRoot.entry.time)
                color: Theme.textMuted
                font.family: cardRoot.scope.contentFontFamily; font.pixelSize: Theme.fs(10)
            }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                width: parent.width
                visible: (entry.summary || "").length > 0
                text: entry.summary || ""
                color: (entry.urgency === 2) ? Theme.on_error_container : Theme.textPrimary
                font.family: cardRoot.scope.contentFontFamily; font.pixelSize: Theme.fs(12); font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                width: parent.width
                visible: (entry.body || "").length > 0
                text: entry.body || ""
                color: (entry.urgency === 2) ? Theme.withAlpha(Theme.on_error_container, 0.85) : Theme.textSecondary
                font.family: cardRoot.scope.contentFontFamily; font.pixelSize: Theme.fs(12)
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
        }
        Item {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 4
            anchors.rightMargin: 4
            width: 20; height: 20
            visible: dismissMouse.containsMouse || parentHover.hovered
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                anchors.centerIn: parent
                text: "✕"
                color: Theme.textMuted
                font.pixelSize: Theme.fs(10)
            }
            MouseArea { id: dismissMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: cardRoot.scope.dismissHistoryEntry(cardRoot.entry) }
        }
        HoverHandler { id: parentHover }
    }

    // --- GNOME-style notification center (left pane).
    component NotifCenter: ColumnLayout {
        id: notifRoot
        required property var scope
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            spacing: 8
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                text: "Notifications"
                color: Theme.textPrimary
                font.family: notifRoot.scope.contentFontFamily; font.pixelSize: Theme.fs(14); font.weight: Font.DemiBold
                Layout.fillWidth: true
                verticalAlignment: Text.AlignVCenter
            }
            Rectangle {
                antialiasing: Theme.shapesAa
                visible: notifRoot.scope.notifList.length > 0
                Layout.preferredWidth: clearLabel.implicitWidth + 20; Layout.preferredHeight: 26; radius: 0
                color: clearMouse.containsMouse ? Theme.bgHover : "transparent"
                border.color: Theme.divider
                border.width: 1
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    id: clearLabel
                    anchors.centerIn: parent
                    text: "Clear"
                    color: Theme.textSecondary
                    font.family: notifRoot.scope.contentFontFamily; font.pixelSize: Theme.fs(11); font.weight: Font.Medium
                }
                MouseArea { id: clearMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: notifRoot.scope.clearAllNotifications() }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            spacing: 10
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                text: "󰂛"
                color: Theme.textSecondary
                font.family: notifRoot.scope.contentFontFamily
                font.pixelSize: Theme.fs(15)
                Layout.alignment: Qt.AlignVCenter
            }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                text: "Do Not Disturb"
                color: Theme.textSecondary
                font.family: notifRoot.scope.contentFontFamily; font.pixelSize: Theme.fs(12)
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }
            Item {
                Layout.preferredWidth: 42; Layout.preferredHeight: 22
                Rectangle {
                    antialiasing: Theme.shapesAa
                    anchors.centerIn: parent
                    width: 42; height: 22
                    radius: 0
                    color: Theme.dndEnabled ? Theme.accent : Theme.withAlpha(Theme.textPrimary, 0.12)
                    Rectangle {
                        antialiasing: Theme.shapesAa
                        width: 16; height: 16
                        radius: 0
                        x: Theme.dndEnabled ? parent.width - width - 3 : 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.dndEnabled ? Theme.onAccent : Theme.textSecondary
                    }
                }
                MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Theme.setDndEnabled(!Theme.dndEnabled) }
            }
        }

        Rectangle {
            antialiasing: Theme.shapesAa
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.divider
            opacity: 0.7
        }

        // Empty state — same fixed height as the list (notifListHeight),
        // so the popup never resizes when notifications come and go.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: notifRoot.scope.notifListHeight
            visible: notifRoot.scope.notifList.length === 0
            spacing: 6
            Item { Layout.fillWidth: true; Layout.fillHeight: true }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                Layout.alignment: Qt.AlignHCenter
                text: "󰂚"
                color: Theme.textMuted
                font.family: notifRoot.scope.contentFontFamily
                font.pixelSize: Theme.fs(34)
                opacity: 0.6
            }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                Layout.alignment: Qt.AlignHCenter
                text: "No Notifications"
                color: Theme.textPrimary
                font.family: notifRoot.scope.contentFontFamily; font.pixelSize: Theme.fs(13); font.weight: Font.DemiBold
            }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                Layout.alignment: Qt.AlignHCenter
                text: "You're all caught up"
                color: Theme.textMuted
                font.family: notifRoot.scope.contentFontFamily; font.pixelSize: Theme.fs(11)
            }
            Item { Layout.fillWidth: true; Layout.fillHeight: true }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: notifRoot.scope.notifListHeight
            visible: notifRoot.scope.notifList.length > 0
            Flickable {
                id: notifFlick
                anchors.fill: parent
                contentWidth: width
                contentHeight: notifListCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                id: notifListCol
                width: notifFlick.width
                spacing: 8
                Repeater {
                    model: notifRoot.scope.notifGroups
                    delegate: Column {
                        id: groupCol
                        required property var modelData
                        readonly property bool isCollapsed: notifRoot.scope.isGroupCollapsed(modelData.appName)
                        width: notifListCol.width
                        spacing: 6
                        RowLayout {
                            width: parent.width
                            spacing: 6
                            Text {
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: (notifRoot.scope.isGroupCollapsed(modelData.appName) ? "▸  " : "▾  ") + (modelData.appName || "Notification").toUpperCase()
                                color: groupToggleMouse.containsMouse ? Theme.textPrimary : Theme.textMuted
                                font.family: notifRoot.scope.contentFontFamily; font.pixelSize: Theme.fs(10); font.weight: Font.Bold; font.letterSpacing: 0.5
                                MouseArea { id: groupToggleMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: notifRoot.scope.toggleGroupCollapsed(modelData.appName) }
                            }
                            Text {
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                visible: (modelData.entries ? modelData.entries.length : 0) > 1
                                text: "×" + modelData.entries.length
                                color: Theme.textMuted
                                font.family: notifRoot.scope.contentFontFamily; font.pixelSize: Theme.fs(10); font.weight: Font.Bold
                            }
                            Item {
                                width: 20; height: 20
                                Text {
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                    anchors.centerIn: parent
                                    text: "✕"
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fs(10)
                                }
                                MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: notifRoot.scope.clearGroupNotifications(modelData) }
                            }
                        }
                        Column {
                            id: flowStack
                            width: parent.width
                            spacing: 6
                            visible: !groupCol.isCollapsed
                            Repeater {
                                model: groupCol.isCollapsed ? [] : modelData.entries
                                delegate: NotifCard {
                                    required property var modelData
                                    scope: notifRoot.scope
                                    entry: modelData
                                    width: notifListCol.width
                                }
                            }
                        }
                        // Collapsed stack (minimized): the 2 latest notifications
                        // as real cards in a deck — newest on top, second
                        // peeking out beneath it. Opaque backing keeps the
                        // translucent card fills from showing through.
                        Item {
                            id: peekStack
                            width: parent.width
                            readonly property var firstEntry: (modelData.entries && modelData.entries.length > 0) ? modelData.entries[0] : null
                            readonly property var secondEntry: (modelData.entries && modelData.entries.length > 1) ? modelData.entries[1] : null
                            height: Math.max(topCard.height, secondCard.visible ? secondCard.y + secondCard.height : 0)
                            clip: true
                            visible: groupCol.isCollapsed && firstEntry !== null
                            NotifCard {
                                id: secondCard
                                scope: notifRoot.scope
                                entry: peekStack.secondEntry ? peekStack.secondEntry : ({})
                                visible: peekStack.secondEntry !== null
                                expandOnClick: true
                                onExpandRequested: notifRoot.scope.toggleGroupCollapsed(modelData.appName)
                                x: 12
                                y: 12
                                width: parent.width - 24
                            }
                            // Opaque backing for the top card.
                            Rectangle {
                                width: parent.width
                                height: topCard.height
                                color: Theme.bg
                            }
                            NotifCard {
                                id: topCard
                                scope: notifRoot.scope
                                entry: peekStack.firstEntry ? peekStack.firstEntry : ({})
                                width: parent.width
                                expandOnClick: true
                                onExpandRequested: notifRoot.scope.toggleGroupCollapsed(modelData.appName)
                            }
                        }
                    }
                }
                }
            }
            ScrollIndicator { flick: notifFlick }
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
            // Owned by Theme (setCalendarNotifSide) — declared here only so
            // week-start writes never drop it from the file.
            property string notifSide: "left"
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
    property date selectedDate: new Date()
    readonly property string selectedKey: Cal.keyForDate(selectedDate)
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

    // Notification center model: newest first.
    // CRASH FIX: rebuild plain snapshots here. History may still hold
    // legacy entries with QObjects (actions/image) from before the
    // HistoryService sanitizer — passing those raw maps into Repeaters
    // segfaults Qt (QV4::fromData/fromQVariantMap). Only id/appName/
    // summary/body/urgency/time (numbers+strings) ever reach the UI.
    readonly property var notifList: {
        try {
            let h = HistoryService.history
            if (!h || h.length === 0) return []
            let out = []
            for (let i = h.length - 1; i >= 0; i--) {
                try {
                    let e = h[i]
                    if (!e) continue
                    let t = e.time
                    let tMs = Date.now()
                    try {
                        if (typeof t === "number" && isFinite(t)) tMs = Math.round(t)
                        else if (t instanceof Date && !isNaN(t.getTime())) tMs = t.getTime()
                        else if (t !== undefined && t !== null) {
                            let d = new Date(t)
                            tMs = isNaN(d.getTime()) ? Date.now() : d.getTime()
                        }
                    } catch (e2) { tMs = Date.now() }
                    let urg = Number(e.urgency)
                    if (!isFinite(urg)) urg = 1
                    out.push({
                        id: (e.id !== undefined && isFinite(Number(e.id))) ? Math.round(Number(e.id)) : -1,
                        appName: String(e.appName || "Notification").slice(0, 120),
                        summary: String(e.summary || "").slice(0, 300),
                        body: String(e.body || "").slice(0, 500),
                        urgency: Math.round(urg),
                        time: Math.round(tMs)
                    })
                } catch (e3) { continue }
            }
            return out
        } catch (e) { return [] }
    }
    // Grouped by application (GNOME-style), newest group first.
    readonly property var notifGroups: {
        try {
            let list = root.notifList
            let groups = []
            let byApp = {}
            for (let i = 0; i < list.length; i++) {
                let e = list[i]
                if (!e) continue
                let app = (e && e.appName) ? String(e.appName).slice(0, 120) : "Notification"
                if (!byApp[app]) { byApp[app] = { appName: app, entries: [] }; groups.push(byApp[app]) }
                byApp[app].entries.push(e)
            }
            return groups
        } catch (e) { return [] }
    }
    // Collapsed groups (by app name) — minimized stack is the default;
    // header click expands a group, click again to minimize.
    // `collapsedApps` stores explicit opt-outs: absent/true = collapsed,
    // false = expanded.
    property var collapsedApps: ({})
    function groupKey(app) { return (app) ? String(app) : "Notification" }
    function isGroupCollapsed(app) {
        try { return collapsedApps[groupKey(app)] !== false } catch (e) { return true }
    }
    function toggleGroupCollapsed(app) {
        try {
            let k = groupKey(app)
            let next = {}
            try { for (let key in collapsedApps) next[key] = collapsedApps[key] } catch (e2) { }
            if (isGroupCollapsed(app)) next[k] = false
            else delete next[k]
            collapsedApps = next
        } catch (e) { }
    }

    readonly property int cellWidth: 54
    readonly property int cellHeight: 32
    readonly property int cellSpacing: 2
    readonly property int minimalGridWidth: 7 * cellWidth + 6 * cellSpacing
    readonly property int calPaneWidth: minimalGridWidth + 16
    readonly property int notifPaneWidth: 330
    // Fixed notification list height so the popup never resizes: left chrome
    // is 28 (header) + 26 (dnd) + 1 (divider) + 3*8 (gaps) = 79, and
    // 79 + 279 = 358 matches the calendar pane height (compact size).
    readonly property int notifListHeight: 279
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

    function goToToday() {
        viewYear = today.getFullYear(); viewMonth = today.getMonth()
        selectedDate = new Date(today.getFullYear(), today.getMonth(), today.getDate())
    }
    function selectDay(cell) {
        try {
            selectedDate = new Date(cell.year, cell.month, cell.day)
            if (cell.year !== viewYear || cell.month !== viewMonth) {
                _monthDir = (cell.year > viewYear || (cell.year === viewYear && cell.month > viewMonth)) ? 1 : -1
                viewYear = cell.year; viewMonth = cell.month
            }
        } catch (e) { }
    }
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

    function timeAgo(t) {
        try {
            let d = (t instanceof Date) ? t : new Date(t)
            if (isNaN(d.getTime())) return ""
            let diff = Date.now() - d.getTime()
            if (diff < 0) diff = 0
            let m = Math.floor(diff / 60000)
            if (m < 1) return "now"
            if (m < 60) return m + "m ago"
            let h = Math.floor(m / 60)
            if (h < 24) return h + "h ago"
            let days = Math.floor(h / 24)
            if (days === 1) return "Yesterday"
            if (days < 7) return days + "d ago"
            return d.toLocaleDateString(Qt.locale("en_US"), "MMM d")
        } catch (e) { return "" }
    }
    function dismissHistoryEntry(entry) {
        try {
            let id = entry ? entry.id : undefined
            if (id !== undefined) {
                try { HistoryService.remove(id) } catch (e) { }
                // Also drop a still-visible toast with the same id.
                try {
                    let srv = root.notifServer
                    let m = srv ? srv.trackedNotifications : null
                    let vals = m ? (m.values !== undefined ? m.values : m) : []
                    let n = vals ? vals.length : 0
                    for (let i = 0; i < n; i++) {
                        try { if (vals[i] && vals[i].id === id) vals[i].dismiss() } catch (e2) { }
                    }
                } catch (e3) { }
            }
        } catch (e) { }
    }
    function clearAllNotifications() {
        try { HistoryService.clear() } catch (e) { }
        try {
            let srv = root.notifServer
            let m = srv ? srv.trackedNotifications : null
            let vals = m ? (m.values !== undefined ? m.values : m) : []
            let n = vals ? vals.length : 0
            for (let i = 0; i < n; i++) {
                try { if (vals[i]) vals[i].dismiss() } catch (e2) { }
            }
        } catch (e) { }
    }
    function clearGroupNotifications(group) {
        try {
            let es = (group && group.entries) ? group.entries.slice() : []
            for (let i = 0; i < es.length; i++) dismissHistoryEntry(es[i])
        } catch (e) { }
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
            WlrLayershell.namespace: "calendar"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            MouseArea { anchors.fill: parent; onClicked: root.dismissed() }

            Loader {
                id: calLoader
                // PERF: hidden calendar kept an 840px popup + all Repeaters +
                // NotifCenter alive (always-active Loader). Gate on window.
                active: root._winVisible || root.showCalendar
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
                    width: 840
                    implicitHeight: outerRect.implicitHeight
                    height: outerRect.implicitHeight
                    focus: true

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) { root.dismissed(); event.accepted = true }
                        else if (!event.isAutoRepeat && (event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
                            if (root._monthNavDebounce.running) { event.accepted = true; return }
                            root._monthNavDebounce.start()
                            if (event.key === Qt.Key_Left) root.moveMonth(-1)
                            else if (event.key === Qt.Key_Right) root.moveMonth(1)
                            else if (event.key === Qt.Key_Up) root.moveYear(-1)
                            else root.moveYear(1)
                            event.accepted = true
                        }
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

                    Rectangle {
                        antialiasing: Theme.shapesAa
                        id: outerRect
                        anchors.fill: parent
                        implicitHeight: contentRow.implicitHeight + 36
                        color: Theme.bg
                        border.color: Theme.panelBorderColor
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

                    RowLayout {
                        id: contentRow
                        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                        anchors.topMargin: 18; anchors.leftMargin: 20; anchors.rightMargin: 20; anchors.bottomMargin: 18
                        spacing: 0
                        // Pane swap: RTL mirrors child order. Both panes pin
                        // LTR back so only the order flips, never the text.
                        layoutDirection: Theme.calendarNotifLeft ? Qt.LeftToRight : Qt.RightToLeft

                        NotifCenter { scope: root; layoutDirection: Qt.LeftToRight; Layout.preferredWidth: root.notifPaneWidth; Layout.fillHeight: true }

                        Item { Layout.preferredWidth: 20; Layout.fillHeight: true }
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            Layout.preferredWidth: 1
                            Layout.fillHeight: true
                            Layout.topMargin: 4
                            Layout.bottomMargin: 4
                            color: Theme.divider
                            opacity: 0.8
                        }
                        Item { Layout.preferredWidth: 20; Layout.fillHeight: true }

                        ColumnLayout {
                            id: calCol
                            layoutDirection: Qt.LeftToRight
                            Layout.preferredWidth: root.calPaneWidth
                            Layout.fillHeight: true
                            spacing: 8
                            CalHeader { scope: root; showNav: true }
                            CalHero { scope: root }
                            CalGrid { scope: root }
                            CalFooter { scope: root }
                            WheelHandler {
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                // PERF: fast scroll/key-repeat rebuilt the 42-cell
                                // grid per tick. Debounce to one nav per 100ms.
                                onWheel: event => {
                                    if (event.angleDelta.y === 0) return
                                    if (root._monthNavDebounce.running) { event.accepted = true; return }
                                    root._monthNavDebounce.start()
                                    root.moveMonth(event.angleDelta.y > 0 ? -1 : 1)
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
