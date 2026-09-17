pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../themes"
import "../../services"
import "../../Ui"

Scope {
    id: scope
    property bool showUpdates: false
    signal dismissed()
    property bool _winVisible: showUpdates
    Timer { id: hideTimer; interval: Theme.panelHideDelay; repeat: false; onTriggered: if (!scope.showUpdates) scope._winVisible = false }
    onShowUpdatesChanged: {
        if (showUpdates) {
            _winVisible = true
            hideTimer.stop()
            refresh()
        } else hideTimer.restart()
    }
    readonly property string barPos: Theme.barPosition
    property int panelGap: -(Theme.barThickness + Theme.panelAttachOverlap)

    property string completionPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/jhqs-update-center-complete"
    property string completionMarker: ""

    readonly property var updates: UpdateService.updates
    readonly property int updateCount: updates.length
    readonly property bool checking: UpdateService.checking
    readonly property var lastChecked: UpdateService.lastCheckedAt
    readonly property string lastCheckedLabel: lastChecked ? "Last check: " + Qt.formatDateTime(lastChecked, "ddd d MMM · HH:mm") : "Not checked yet"
    readonly property string updateScript: Quickshell.env("HOME") + "/.config/quickshell/jhqs/scripts/update.sh"
    property bool listExpanded: false
    property var selectedKeys: ({})

    function keyOf(item): string { return item.source + "\t" + item.name }
    function isSelected(item): bool { return selectedKeys[keyOf(item)] === true }
    function toggleSelected(item): void {
        let k = keyOf(item)
        let next = {}
        for (let key in selectedKeys) next[key] = selectedKeys[key]
        next[k] = !(next[k] === true)
        selectedKeys = next
    }
    readonly property int selectedCount: {
        let n = 0
        for (let i = 0; i < updates.length; i++) if (selectedKeys[keyOf(updates[i])] === true) n++
        return n
    }
    readonly property var selectedSourceList: {
        let seen = ({})
        let out = []
        for (let i = 0; i < updates.length; i++) {
            let item = updates[i]
            if (selectedKeys[keyOf(item)] === true && !seen[item.source]) {
                seen[item.source] = true
                out.push(item.source)
            }
        }
        return out
    }
    readonly property string primaryActionLabel: selectedCount > 0 ? "Update selected (" + selectedCount + ")" : "Update all (" + updateCount + ")"

    function refresh(): void { UpdateService.checkNow() }

    function shellQuote(value: string): string {
        return "'" + String(value).replace(/'/g, "'\\''") + "'"
    }
    function updateCommand(targets: var): string {
        let list = []
        if (typeof targets === "string") list = [targets]
        else if (targets && targets.length) list = targets
        if (list.length === 0) list = ["all"]
        return "bash " + shellQuote(updateScript) + " " + list.join(" ")
    }
    function runInTerminal(command: string, markDone: bool, hold: bool): void {
        if (termProc.running) {
            _termPending = { command: command, markDone: markDone, hold: hold }
            return
        }
        runInTerminalNow(command, markDone, hold)
    }
    property var _termPending: null
    function runInTerminalNow(command: string, markDone: bool, hold: bool): void {
        let full = command
        if (markDone) full += " && date +%s%N > " + shellQuote(completionPath) + " && printf '\\nUpdate OK.\\n'"
        if (hold) full += '; echo; read -n1 -s -r -p "Press any key to close…"'
        termProc.command = ["bash", "-c", "kitty --class jhqs-update --title Update bash -lc " + shellQuote(full) + " &"]
        termProc.running = true
    }
    function launch(targets: var): void { runInTerminal(updateCommand(targets), true, true) }
    function launchPrimary(): void {
        let targets = selectedCount > 0 ? selectedSourceList : "all"
        selectedKeys = ({})
        launch(targets)
    }

    Process {
        id: termProc
        command: ["bash", "-c", "echo"]
        onExited: {
            if (scope._termPending !== null && scope._termPending !== undefined) {
                let p = scope._termPending
                scope._termPending = null
                scope.runInTerminalNow(p.command, p.markDone, p.hold)
            }
        }
    }

    FileView {
        id: completionFile
        path: scope.completionPath
        watchChanges: scope.showUpdates || termProc.running
        printErrors: false
        onFileChanged: completionDebounce.restart()
        onLoaded: {
            let marker = String(text() || "").trim()
            if (marker !== "" && marker !== scope.completionMarker) {
                scope.completionMarker = marker
                if (scope.showUpdates) scope.refresh()
            }
        }
    }
    Timer {
        id: completionDebounce
        interval: 1000; repeat: false
        onTriggered: { try { completionFile.reload() } catch (e) { } }
    }

    component IconButton: Rectangle {
        id: iconBtn
        required property string icon
        property color iconColor: Theme.textSecondary
        property color hoverColor: Theme.accent
        property int iconSize: Theme.fs(14)
        signal clicked()
        implicitWidth: 28
        implicitHeight: 28
        radius: width / 2
        antialiasing: Theme.shapesAa
        color: iconMouse.containsMouse ? Theme.bgHover : "transparent"
        Text {
            id: iconGlyph
            anchors.centerIn: parent
            text: iconBtn.icon
            color: iconMouse.containsMouse ? iconBtn.hoverColor : iconBtn.iconColor
            font.family: Theme.iconFontFamily
            font.pixelSize: iconBtn.iconSize
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
        }
        MouseArea {
            id: iconMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: iconBtn.clicked()
        }
    }

    component Badge: Rectangle {
        id: badge
        required property string label
        implicitWidth: badgeLabel.implicitWidth + 12
        implicitHeight: 17
        radius: 5
        antialiasing: Theme.shapesAa
        color: Theme.withAlpha(Theme.accent, 0.18)
        Text {
            id: badgeLabel
            anchors.centerIn: parent
            text: badge.label
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(9)
            font.weight: Font.Bold
            font.capitalization: Font.AllUppercase
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
        }
    }

    component UpdateRow: Rectangle {
        id: row
        required property var item
        required property bool selected
        signal toggled()
        signal updateClicked()
        implicitHeight: 46
        radius: Theme.cornerRadiusSmall
        antialiasing: Theme.shapesAa
        color: rowMouse.containsMouse ? Theme.bgHover : row.selected ? Theme.bgSelected : Theme.withAlpha(Theme.textPrimary, 0.05)
        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.toggled()
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            spacing: 10
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 20
                implicitHeight: 20
                radius: 6
                antialiasing: Theme.shapesAa
                color: row.selected ? Theme.accent : "transparent"
                border.width: row.selected ? 0 : 1
                border.color: Theme.withAlpha(Theme.textPrimary, 0.4)
                Text {
                    anchors.centerIn: parent
                    visible: row.selected
                    text: "󰄬"
                    color: Theme.onAccent
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fs(11)
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
            }
            Column {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1
                RowLayout {
                    width: parent.width
                    spacing: 6
                    Text {
                        Layout.fillWidth: true
                        text: row.item.name
                        elide: Text.ElideRight
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(12)
                        font.weight: Font.Medium
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    Badge {
                        Layout.alignment: Qt.AlignVCenter
                        visible: row.item.source !== "system"
                        label: row.item.source
                    }
                }
                Text {
                    width: parent.width
                    text: row.item.detail
                    elide: Text.ElideRight
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(10)
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
            }
            IconButton {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 26
                implicitHeight: 26
                icon: "󰇚"
                iconColor: Theme.accent
                iconSize: Theme.fs(13)
                onClicked: row.updateClicked()
            }
        }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: scope._winVisible && Theme.isPrimaryScreen(modelData)
            color: "transparent"
            exclusiveZone: 0
            anchors { top: true; left: true; right: true; bottom: true }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "updatecenter"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) { scope.dismissed(); event.accepted = true }
                }
                Component.onCompleted: forceActiveFocus()
            }
            // Disabled while the panel is closing: during a morph handoff
            // the outgoing window stays mapped for panelHideDelay and must
            // not eat the click that belongs to the panel now on top.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                enabled: scope.showUpdates
                onClicked: scope.dismissed()
            }
            PanelShell {
                moduleId: "updates"
                screenActive: Theme.isPrimaryScreen(modelData)
                barPos: scope.barPos
                panelGap: scope.panelGap
                shown: scope.showUpdates
                boxWidth: 410
                contentMargins: 16
                contentSpacing: 12
                heightPadding: 32

                RowLayout {
                    width: parent.width
                    spacing: 8
                    IconButton {
                        icon: "󰑐"
                        iconColor: Theme.accent
                        iconSize: Theme.fs(16)
                        implicitWidth: 26
                        implicitHeight: 26
                        onClicked: scope.refresh()
                    }
                    Text {
                        text: "Updates"
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(15)
                        font.weight: Font.Bold
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    Rectangle {
                        visible: scope.updateCount > 0
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: heroCount.implicitWidth + 16
                        implicitHeight: 22
                        radius: 11
                        antialiasing: Theme.shapesAa
                        color: Theme.accent
                        Text {
                            id: heroCount
                            anchors.centerIn: parent
                            text: scope.updateCount
                            color: Theme.onAccent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(11)
                            font.weight: Font.Bold
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }
                    }
                    Text {
                        visible: scope.checking
                        text: "Checking…"
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(10)
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    Item { Layout.fillWidth: true }
                    IconButton {
                        icon: scope.listExpanded ? "󰖰" : "󰖯"
                        onClicked: scope.listExpanded = !scope.listExpanded
                    }
                    Item {
                        implicitWidth: 28
                        implicitHeight: 28
                        RotationAnimator on rotation {
                            running: scope.checking && Theme.animationsEnabled
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: Theme.durSpinner
                        }
                        IconButton {
                            anchors.centerIn: parent
                            icon: "󰑐"
                            onClicked: scope.refresh()
                        }
                    }
                    IconButton {
                        icon: "󰅖"
                        onClicked: scope.dismissed()
                    }
                }

                Rectangle {
                    id: primaryAction
                    visible: scope.updateCount > 0
                    width: parent.width
                    implicitHeight: 40
                    radius: Theme.cornerRadiusSmall
                    antialiasing: Theme.shapesAa
                    color: primaryMouse.containsMouse ? Theme.accentDim : Theme.accent
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            text: "󰇚"
                            color: Theme.onAccent
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.fs(14)
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }
                        Text {
                            text: scope.primaryActionLabel
                            color: Theme.onAccent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(12)
                            font.weight: Font.Bold
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }
                    }
                    MouseArea {
                        id: primaryMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: scope.launchPrimary()
                    }
                }

                Rectangle {
                    id: listCard
                    visible: scope.updateCount > 0
                    width: parent.width
                    implicitHeight: Math.min(listFlick.contentHeight + 12, scope.listExpanded ? 1e9 : 266)
                    // Expand/collapse: the container grows along y on the M3
                    // shared-axis timing (m3 transition patterns).
                    Behavior on implicitHeight {
                        enabled: Theme.animationsEnabled
                        NumberAnimation { duration: Theme.durMotionSharedAxis; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMotion }
                    }
                    radius: Theme.cornerRadiusSmall
                    antialiasing: Theme.shapesAa
                    color: Theme.cardBg
                    clip: true
                    Flickable {
                        id: listFlick
                        anchors.fill: parent
                        anchors.margins: 6
                        anchors.rightMargin: 14
                        contentWidth: width
                        contentHeight: listCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: contentHeight > height
                        Column {
                            id: listCol
                            width: listFlick.width
                            spacing: 6
                            Repeater {
                                model: scope.updates
                                delegate: UpdateRow {
                                    required property var modelData
                                    width: listCol.width
                                    item: modelData
                                    selected: scope.isSelected(modelData)
                                    onToggled: scope.toggleSelected(modelData)
                                    onUpdateClicked: scope.launch(modelData.source)
                                }
                            }
                        }
                    }
                    Rectangle {
                        visible: listFlick.contentHeight > listFlick.height
                        width: 4
                        height: Math.max(24, listFlick.visibleArea.heightRatio * (listCard.height - 12))
                        x: listCard.width - width - 5
                        y: 6 + listFlick.visibleArea.yPosition * (listCard.height - 12 - height)
                        radius: 2
                        antialiasing: Theme.shapesAa
                        color: Theme.withAlpha(Theme.textPrimary, 0.25)
                    }
                }

                Column {
                    visible: scope.updateCount === 0
                    width: parent.width
                    spacing: 4
                    topPadding: 18
                    bottomPadding: 18
                    Text {
                        width: parent.width
                        text: scope.checking ? "Checking for updates…" : "Everything is up to date"
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(13)
                        font.weight: Font.Medium
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    Text {
                        width: parent.width
                        text: scope.lastCheckedLabel
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(10)
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                }
            }
        }
    }
}
