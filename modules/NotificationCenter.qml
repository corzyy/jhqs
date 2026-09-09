pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../themes"
import "../services"
import "../Ui"

Scope {
    id: root
    property bool showNotif: false
    property var notifServer: null
    signal dismissed()
    property bool _winVisible: showNotif
    Timer { id: hideTimer; interval: Theme.animSlow + 20; repeat: false; onTriggered: if (!root.showNotif) root._winVisible = false }
    onShowNotifChanged: {
        if (showNotif) { _winVisible = true; hideTimer.stop(); query = "" }
        else hideTimer.restart()
    }
    readonly property string barPos: Theme.barPosition
    readonly property int screenGap: 6
    property int panelGap: screenGap - Theme.barThickness
    readonly property bool isMinimal: Theme.minimalTheme

    property string query: ""

    function trackedVals(): var {
        try {
            if (!root.notifServer) return []
            let v = root.notifServer.trackedNotifications.values
            let vals = typeof v === "function" ? v() : v
            return vals ? vals.slice() : []
        } catch (e) { return [] }
    }
    readonly property var allNotifs: {
        let hist = HistoryService.history
        let tracked = root.trackedVals()
        let combined = []
        for (let i = tracked.length - 1; i >= 0; i--) {
            let n = tracked[i]
            combined.push({ summary: n.summary || n.appName || "Notification", body: stripTags(n.body || ""), appName: n.appName || "", appIcon: n.appIcon || "", image: n.image || "", id: n.id, time: null, urgency: n.urgency })
        }
        for (let i = hist.length - 1; i >= 0 && combined.length < 30; i--) {
            let h = hist[i]
            let dup = false
            for (let j = 0; j < combined.length; j++) if (combined[j].id === h.id) { dup = true; break }
            if (!dup) combined.push({ summary: h.summary || h.appName || "Notification", body: stripTags(h.body || ""), appName: h.appName || "", appIcon: h.appIcon || "", image: h.image || "", id: h.id, time: h.time || null, urgency: h.urgency })
        }
        return combined
    }
    readonly property var filtered: {
        let q = query.trim().toLowerCase()
        if (q === "") return allNotifs
        return allNotifs.filter(n => ((n.appName || "") + " " + (n.summary || "") + " " + (n.body || "")).toLowerCase().indexOf(q) >= 0)
    }
    readonly property int notifCount: allNotifs.length

    function stripTags(s: string): string {
        try { return String(s || "").replace(/<[^>]*>/g, "") } catch (e) { return String(s || "") }
    }
    function fmtTime(t: var): string {
        try {
            if (!t) return ""
            let d = t instanceof Date ? t : new Date(t)
            if (isNaN(d.getTime())) return ""
            if (d.toDateString() === new Date().toDateString()) return Qt.formatDateTime(d, "HH:mm")
            return Qt.formatDateTime(d, "MMM d")
        } catch (e) { return "" }
    }
    function iconSource(n: var): string {
        let im = (n.image || "").trim()
        if (im !== "") return im
        let ic = (n.appIcon || "").trim()
        if (ic === "") return ""
        if (ic.startsWith("/") || ic.startsWith("file://") || ic.startsWith("image://")) return ic
        if (Quickshell.hasThemeIcon(ic)) return Quickshell.iconPath(ic)
        let lc = ic.toLowerCase()
        if (Quickshell.hasThemeIcon(lc)) return Quickshell.iconPath(lc)
        return Quickshell.iconPath(ic)
    }
    function dismissOne(id: var): void {
        try { HistoryService.remove(id) } catch (e) { }
        let vals = trackedVals()
        for (let i = 0; i < vals.length; i++) if (vals[i].id === id) { try { vals[i].dismiss() } catch (e2) { } }
    }
    function clearAll(): void {
        if (notifCount === 0) return
        try { HistoryService.clear() } catch (e) { }
        let vals = trackedVals()
        for (let i = 0; i < vals.length; i++) { try { vals[i].dismiss() } catch (e2) { } }
    }

    IpcHandler {
        target: "notifcenter"
        function state(): string { return "notifcenter=" + root.showNotif + " count=" + root.notifCount }
        function clear(): string { root.clearAll(); return "cleared" }
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
            WlrLayershell.namespace: "notifcenter"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: root.dismissed()
            }
            Rectangle {
                antialiasing: Theme.shapesAa
                id: ncBox
                width: 420
                BarAnchor {
                    id: ncAnchor
                    moduleId: "notif"
                    barPos: root.barPos
                    panelWidth: ncBox.width
                    panelHeight: ncBox.implicitHeight
                    screenWidth: ncBox.parent.width
                    screenHeight: ncBox.parent.height
                    gap: root.panelGap
                    fallbackX: (ncBox.parent.width - ncBox.width) / 2
                    fallbackY: ncBox.parent.height - ncBox.implicitHeight - root.panelGap
                }
                x: ncAnchor.panelX
                y: ncAnchor.panelY
                implicitHeight: mainCol.implicitHeight + 24
                color: root.isMinimal ? Theme.bg : Theme.panelBg
                border.color: root.isMinimal ? Theme.accent : Theme.panelBorderColor
                border.width: root.isMinimal ? 2 : 1
                radius: root.isMinimal ? 0 : Theme.cornerRadius
                clip: true
                PanelSpring {
                    id: ncSpring
                    slideFade: true
                    shown: root.showNotif
                    hiddenX: root.barPos === "left" ? -(ncBox.width + 5) : root.barPos === "right" ? (ncBox.width + 5) : 0
                    hiddenY: root.barPos === "top" ? -(ncBox.implicitHeight + 5) : root.barPos === "bottom" ? (ncBox.implicitHeight + 5) : 0
                }
                visible: ncSpring.boxVisible
                opacity: ncSpring.fade
                scale: ncSpring.zoom
                transformOrigin: ncAnchor.origin
                transform: Translate { x: ncSpring.slideX; y: ncSpring.slideY }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onClicked: mouse => mouse.accepted = true
                    onPressed: mouse => mouse.accepted = true
                    onWheel: wheel => wheel.accepted = true
                }
                Item {
                    anchors.fill: parent
                    focus: !queryInput.activeFocus
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) { root.dismissed(); event.accepted = true }
                    }
                }

                ColumnLayout {
                    id: mainCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: "Notifications"
                            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(15); font.weight: Font.Bold
                            color: Theme.textPrimary
                            antialiasing: Theme.textAa; renderType: Theme.textRenderType
                        }
                        Text {
                            text: root.notifCount === 1 ? "1 notification" : root.notifCount + " notifications"
                            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11)
                            color: Theme.textMuted
                            antialiasing: Theme.textAa; renderType: Theme.textRenderType
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            Layout.preferredHeight: 24
                            Layout.preferredWidth: dndRow.implicitWidth + 18
                            radius: height / 2
                            color: Theme.dndEnabled ? Theme.accent : Theme.cardBg
                            border.color: Theme.dndEnabled ? "transparent" : Theme.divider
                            border.width: 1
                            Text {
                                id: dndRow
                                anchors.centerIn: parent
                                text: Theme.dndEnabled ? "DND on" : "DND off"
                                font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11); font.weight: Font.Medium
                                color: Theme.dndEnabled ? Theme.onAccent : Theme.textSecondary
                                antialiasing: Theme.textAa; renderType: Theme.textRenderType
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Theme.toggleDnd()
                            }
                        }
                        Rectangle {
                            Layout.preferredWidth: 24; Layout.preferredHeight: 24
                            radius: Theme.cornerRadiusSmall
                            color: "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                font.pixelSize: Theme.fs(11)
                                color: Theme.textSecondary
                                antialiasing: Theme.textAa; renderType: Theme.textRenderType
                            }
                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.dismissed()
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: Theme.cornerRadiusSmall
                        color: Theme.panelSurface
                        border.color: queryInput.activeFocus ? Theme.accent : Theme.divider
                        border.width: 1
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10; anchors.rightMargin: 10
                            spacing: 8
                            Text {
                                text: "⌕"
                                font.pixelSize: Theme.fs(13)
                                color: Theme.textMuted
                                antialiasing: Theme.textAa; renderType: Theme.textRenderType
                            }
                            TextInput {
                                id: queryInput
                                Layout.fillWidth: true
                                text: root.query
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13)
                                clip: true
                                focus: true
                                selectByMouse: true
                                selectionColor: Theme.accent
                                onTextChanged: if (text !== root.query) root.query = text
                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Escape) {
                                        if (root.query.length > 0) root.query = ""
                                        else root.dismissed()
                                        event.accepted = true
                                    }
                                }
                                Component.onCompleted: forceActiveFocus()
                            }
                            Text {
                                visible: root.query.length > 0
                                text: "✕"
                                font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(12)
                                color: Theme.textMuted
                                antialiasing: Theme.textAa; renderType: Theme.textRenderType
                                MouseArea {
                                    id: searchClearMouse
                                    anchors.fill: parent; anchors.margins: -6
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.query = ""
                                }
                            }
                        }
                        Text {
                            anchors.left: parent.left; anchors.leftMargin: 34
                            anchors.right: parent.right; anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.query.length === 0
                            text: "Search notifications"
                            color: Theme.textMuted
                            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13)
                            elide: Text.ElideRight
                            antialiasing: Theme.textAa; renderType: Theme.textRenderType
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            Layout.fillWidth: true
                            text: root.query.trim() === "" ? "Recent and live notifications" : root.filtered.length + " matching"
                            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11)
                            color: Theme.textMuted
                            elide: Text.ElideRight
                            antialiasing: Theme.textAa; renderType: Theme.textRenderType
                        }
                        Rectangle {
                            visible: root.notifCount > 0
                            Layout.preferredWidth: clearRow.implicitWidth + 18
                            Layout.preferredHeight: 24
                            radius: Theme.cornerRadiusSmall
                            color: "transparent"
                            border.color: Theme.divider
                            border.width: 1
                            Text {
                                id: clearRow
                                anchors.centerIn: parent
                                text: "Clear all"
                                font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11); font.weight: Font.Medium
                                color: Theme.textPrimary
                                antialiasing: Theme.textAa; renderType: Theme.textRenderType
                            }
                            MouseArea {
                                id: clearMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.clearAll()
                            }
                        }
                    }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(listInner.implicitHeight, 360)
                        visible: root.filtered.length > 0
                        contentHeight: listInner.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.VerticalFlick
                        ColumnLayout {
                            id: listInner
                            width: parent.width
                            spacing: 8
                            Repeater {
                                model: root.filtered
                                delegate: Item {
                                    id: wrap
                                    required property var modelData
                                    readonly property bool isCritical: modelData.urgency === NotificationUrgency.Critical
                                    readonly property string src: root.iconSource(modelData)
                                    property bool iconFailed: false
                                    onSrcChanged: iconFailed = false
                                    property bool leaving: false
                                    readonly property real dragFade: {
                                        let d = Math.abs(dragProxy.x)
                                        if (d <= 0.5) return 1.0
                                        return Math.max(0.0, 1.0 - (d / Math.max(1, wrap.width)))
                                    }
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: rowCard.height
                                    clip: true
                                    function swipeAway(dir: int): void {
                                        if (wrap.leaving) return
                                        wrap.leaving = true
                                        dragProxy.x = (dir >= 0 ? 1 : -1) * (wrap.width + 20)
                                        swipeTimer.restart()
                                    }
                                    Timer {
                                        id: swipeTimer
                                        interval: 200
                                        repeat: false
                                        onTriggered: root.dismissOne(wrap.modelData.id)
                                    }
                                    Item {
                                        id: dragProxy
                                        x: 0
                                        Behavior on x {
                                            enabled: !dragMouse.drag.active
                                            NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard }
                                        }
                                    }
                                    Rectangle {
                                        id: rowCard
                                        width: wrap.width
                                        height: Math.max(56, nCol.implicitHeight + 20)
                                        x: dragProxy.x
                                        opacity: wrap.leaving ? 0 : wrap.dragFade
                                        Behavior on opacity {
                                            enabled: !dragMouse.drag.active
                                            NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard }
                                        }
                                        radius: Theme.cornerRadiusSmall
                                        color: wrap.isCritical ? Theme.error_container : Theme.cardBg
                                        border.color: wrap.isCritical ? Theme.errorColor : Theme.divider
                                        border.width: 1
                                        clip: true
                                    RowLayout {
                                        id: nCol
                                        anchors.left: parent.left; anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.leftMargin: 12; anchors.rightMargin: 12
                                        anchors.topMargin: 10; anchors.bottomMargin: 10
                                        spacing: 12
                                        Item {
                                            Layout.preferredWidth: 32; Layout.preferredHeight: 32
                                            Layout.alignment: Qt.AlignVCenter
                                            visible: wrap.src !== "" || wrap.iconFailed
                                            Image {
                                                anchors.fill: parent
                                                source: wrap.src
                                                sourceSize.width: 64; sourceSize.height: 64
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: true
                                                smooth: true
                                                visible: !wrap.iconFailed && wrap.src !== ""
                                                onStatusChanged: if (status === Image.Error) wrap.iconFailed = true
                                            }
                                            Text {
                                                anchors.centerIn: parent
                                                visible: wrap.iconFailed
                                                text: ((modelData.appName || modelData.summary || "?").charAt(0) || "?").toUpperCase()
                                                color: wrap.isCritical ? Theme.on_error_container : Theme.textPrimary
                                                font.family: Theme.fontFamily; font.pixelSize: Theme.fs(15); font.weight: Font.Medium
                                                antialiasing: Theme.textAa; renderType: Theme.textRenderType
                                            }
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            Layout.rightMargin: 12
                                            spacing: 2
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.appName || "Notification"
                                                    font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10)
                                                    color: wrap.isCritical ? Theme.withAlpha(Theme.on_error_container, 0.8) : Theme.textMuted
                                                    elide: Text.ElideRight
                                                    antialiasing: Theme.textAa; renderType: Theme.textRenderType
                                                }
                                                Text {
                                                    text: root.fmtTime(modelData.time)
                                                    visible: text.length > 0
                                                    font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10)
                                                    color: wrap.isCritical ? Theme.withAlpha(Theme.on_error_container, 0.8) : Theme.textMuted
                                                    antialiasing: Theme.textAa; renderType: Theme.textRenderType
                                                }
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.summary || "Notification"
                                                font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13); font.weight: Font.Bold
                                                color: wrap.isCritical ? Theme.on_error_container : Theme.textPrimary
                                                elide: Text.ElideRight
                                                maximumLineCount: 2
                                                wrapMode: Text.WordWrap
                                                antialiasing: Theme.textAa; renderType: Theme.textRenderType
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                visible: (modelData.body || "").length > 0
                                                text: modelData.body || ""
                                                textFormat: Text.PlainText
                                                font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12)
                                                color: wrap.isCritical ? Theme.withAlpha(Theme.on_error_container, 0.85) : Theme.textSecondary
                                                elide: Text.ElideRight
                                                maximumLineCount: 3
                                                wrapMode: Text.WordWrap
                                                antialiasing: Theme.textAa; renderType: Theme.textRenderType
                                            }
                                        }
                                    }
                                    Item {
                                        anchors.top: parent.top; anchors.right: parent.right
                                        anchors.topMargin: 4; anchors.rightMargin: 4
                                        width: 18; height: 18
                                        Text {
                                            anchors.centerIn: parent
                                            text: "✕"
                                            font.pixelSize: Theme.fs(10)
                                            color: Theme.textMuted
                                            antialiasing: Theme.textAa; renderType: Theme.textRenderType
                                        }
                                    }
                                    MouseArea {
                                        id: dragMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                        drag.target: dragProxy
                                        drag.axis: Drag.XAxis
                                        drag.minimumX: -wrap.width
                                        drag.maximumX: wrap.width
                                        drag.smoothed: false
                                        onReleased: {
                                            if (wrap.leaving) return
                                            let dx = 0
                                            try { dx = dragProxy.x } catch (e) { dx = 0 }
                                            if (Math.abs(dx) > 80) {
                                                wrap.swipeAway(dx >= 0 ? 1 : -1)
                                            } else {
                                                try { dragProxy.x = 0 } catch (e2) { }
                                            }
                                        }
                                        onCanceled: {
                                            if (!wrap.leaving) {
                                                try { dragProxy.x = 0 } catch (e) { }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 140
                        visible: root.filtered.length === 0
                        spacing: 6
                        Item { Layout.fillHeight: true }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.query.trim() === "" ? "No notifications" : "No matching notifications"
                            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12)
                            color: Theme.textMuted
                            antialiasing: Theme.textAa; renderType: Theme.textRenderType
                        }
                        Item { Layout.fillHeight: true }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Drag to dismiss · Esc closes"
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10)
                        color: Theme.textMuted
                        horizontalAlignment: Text.AlignHCenter
                        antialiasing: Theme.textAa; renderType: Theme.textRenderType
                    }
                }
            }
        }
    }
}
