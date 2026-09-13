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
    Timer { id: hideTimer; interval: 0; repeat: false; onTriggered: if (!scope.showUpdates) scope._winVisible = false }
    onShowUpdatesChanged: {
        if (showUpdates) {
            _winVisible = true
            hideTimer.stop()
            refresh()
        } else hideTimer.restart()
    }
    readonly property string barPos: Theme.barPosition
    readonly property int screenGap: 6
    property int panelGap: screenGap - Theme.barThickness

    readonly property int compactRowLimit: 3
    property var expandedSections: ({})
    property string completionPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/jhqs-update-center-complete"
    property string completionMarker: ""

    readonly property var updates: UpdateService.updates
    readonly property int updateCount: updates.length
    readonly property bool checking: UpdateService.checking
    readonly property var lastChecked: UpdateService.lastCheckedAt
    readonly property string checkSchedule: UpdateService.checkSchedule

    readonly property string headerTitle: checking ? "Checking updates…" : (updateCount > 0 ? updateCount + " updates available" : "Everything is up to date")
    readonly property string lastCheckedLabel: lastChecked ? "Last check: " + Qt.formatDateTime(lastChecked, "ddd d MMM · HH:mm") : "Not checked yet"
    readonly property string updateScript: Quickshell.env("HOME") + "/.config/quickshell/jhqs/scripts/update.sh"

    readonly property var sections: [
        { id: "system", title: "System", action: "Update system" },
        { id: "flatpak", title: "Flatpak", action: "Update Flatpak" }
    ]
    readonly property var scheduleOptions: [
        { value: "At startup only", label: "Startup" },
        { value: "Every 30 minutes", label: "30 min" },
        { value: "Every 2 hours", label: "2 h" },
        { value: "Every 6 hours", label: "6 h" },
        { value: "Every 12 hours", label: "12 h" },
        { value: "Every 24 hours", label: "24 h" }
    ]

    function refresh(): void { UpdateService.checkNow() }

    // PERF: memoized per-section rows + counts. Old code ran filter() +
    // slice() + count() (O(n) scans) in every delegate binding — a nested
    // Repeater rebuild on any single update. One pass per updates change.
    readonly property var _systemRows: updates.filter(function(item) { return item.source === "system" })
    readonly property var _flatpakRows: updates.filter(function(item) { return item.source === "flatpak" })
    readonly property int _systemCount: _systemRows.length
    readonly property int _flatpakCount: _flatpakRows.length

    // Single canonical counter lives in UpdateService — don't re-scan here.
    function count(source: string): int {
        if (source === "system") return _systemCount
        if (source === "flatpak") return _flatpakCount
        return UpdateService.count(source)
    }
    function sectionRows(source: string): var {
        if (source === "system") return _systemRows
        if (source === "flatpak") return _flatpakRows
        return updates.filter(function(item) { return item.source === source })
    }
    function sectionExpanded(source: string): bool {
        return expandedSections[source] === true
    }
    function toggleSection(source: string): void {
        let next = ({})
        for (let key in expandedSections) next[key] = expandedSections[key]
        next[source] = !sectionExpanded(source)
        expandedSections = next
    }
    function visibleSectionRows(source: string): var {
        let rows = sectionRows(source)
        return sectionExpanded(source) ? rows : rows.slice(0, compactRowLimit)
    }
    function detailsVisible(source: string): bool {
        // System uses the small arrow button instead of the "Show all" pill.
        if (source === "system") return false
        return count(source) > compactRowLimit
    }
    function setCheckSchedule(schedule: string): void { UpdateService.setCheckSchedule(schedule) }

    function shellQuote(value: string): string {
        return "'" + String(value).replace(/'/g, "'\\''") + "'"
    }
    function updateCommand(kind: string): string {
        let target = (kind === "system" || kind === "flatpak") ? kind : "all"
        return "bash " + shellQuote(updateScript) + " " + target
    }
    function runInTerminal(command: string, markDone: bool, hold: bool): void {
        // STABILITY: disable launch buttons while running (see panel body) —
        // belt-and-suspenders: queue instead of dropping rapid double-clicks.
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
    function launch(kind: string): void {
        runInTerminal(updateCommand(kind), true, true)
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
    // STABILITY: completion file watcher used to spawn the checker even with
    // the panel closed. Gate + debounce.
    Timer {
        id: completionDebounce
        interval: 1000; repeat: false
        onTriggered: { try { completionFile.reload() } catch (e) { } }
    }

    component SectionHeader: Text {
        antialiasing: Theme.textAa
        renderType: Theme.textRenderType
        color: Theme.textSecondary
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.fs(10)
        font.weight: Font.Bold
    }
    component Hairline: Rectangle {
        antialiasing: Theme.shapesAa
        color: Theme.withAlpha(Theme.textPrimary, 0.12)
        height: 1
    }
    component PillButton: Rectangle {
        id: pillBtn
        required property string label
        property bool highlighted: false
        property bool compact: false
        signal clicked()
        implicitHeight: 30
        implicitWidth: Math.max(compact ? 52 : 64, pillLabel.implicitWidth + (compact ? 12 : 20))
        antialiasing: Theme.shapesAa
        radius: Theme.cornerRadiusSmall
        color: pillMouse.containsMouse ? Theme.bgHover : (highlighted ? Theme.bgSelected : Theme.cardBg)
        border.color: highlighted ? Theme.accent : Theme.divider
        border.width: 1
        Text {
            id: pillLabel
            anchors.centerIn: parent
            text: pillBtn.label
            color: pillMouse.containsMouse ? Theme.accent : Theme.textPrimary
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.fs(12)
            font.weight: Font.Medium
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
        }
        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pillBtn.clicked()
        }
    }
    component ArrowButton: Rectangle {
        id: arrowBtn
        required property bool expanded
        signal clicked()
        implicitWidth: 28
        implicitHeight: 28
        antialiasing: Theme.shapesAa
        radius: Theme.cornerRadiusSmall
        color: expanded ? Theme.bgSelected : arrowMouse.containsMouse ? Theme.bgHover : "transparent"
        border.color: expanded ? Theme.accent : "transparent"
        border.width: expanded ? 1 : 0
        Text {
            anchors.centerIn: parent
            text: "›"
            color: arrowMouse.containsMouse || arrowBtn.expanded ? Theme.textPrimary : Theme.textSecondary
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.fs(14)
            rotation: arrowBtn.expanded ? 90 : 0
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
        }
        MouseArea {
            id: arrowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: arrowBtn.clicked()
        }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: scope._winVisible && modelData.name === "DP-1"
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
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: scope.dismissed()
            }
            Rectangle {
                antialiasing: Theme.shapesAa
                id: updBox
                width: 410
                implicitHeight: Math.max(120, Math.min(contentCol.implicitHeight + 36, updAnchor.screenHeight - updAnchor.edgeOffset - 24))
                BarAnchor {
                    id: updAnchor
                    moduleId: "updates"
                    barPos: scope.barPos
                    panelWidth: updBox.width
                    panelHeight: updBox.implicitHeight
                    screenWidth: updBox.parent.width
                    screenHeight: updBox.parent.height
                    gap: scope.panelGap
                    fallbackX: (updBox.parent.width - updBox.width) / 2
                    fallbackY: (updBox.parent.height - updBox.implicitHeight) / 2
                }
                x: updAnchor.panelX
                y: updAnchor.panelY
                color: Theme.bg
                border.color: Theme.panelBorderColor
                border.width: 2
                radius: 0
                clip: true
                PanelSpring {
                    id: updSpring
                    slideFade: true
                    shown: scope.showUpdates
                    hiddenX: scope.barPos === "left" ? -(updBox.width + 5) : scope.barPos === "right" ? (updBox.width + 5) : 0
                    hiddenY: scope.barPos === "top" ? -(updBox.implicitHeight + 5) : scope.barPos === "bottom" ? (updBox.implicitHeight + 5) : 0
                }
                visible: updSpring.boxVisible
                opacity: updSpring.fade
                scale: updSpring.zoom
                transformOrigin: updAnchor.origin
                transform: Translate { x: updSpring.slideX; y: updSpring.slideY }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onClicked: mouse => mouse.accepted = true
                    onPressed: mouse => mouse.accepted = true
                    onWheel: wheel => wheel.accepted = true
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
                        spacing: 14
                        RowLayout {
                            width: parent.width
                            spacing: 10
                            Column {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    width: parent.width
                                    text: scope.headerTitle
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
                                    text: scope.lastCheckedLabel
                                    color: Theme.textSecondary
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: Theme.fs(10)
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                            }
                            PillButton {
                                visible: !scope.checking
                                label: "Refresh"
                                onClicked: scope.refresh()
                            }
                            Text {
                                visible: scope.checking
                                text: "Checking…"
                                color: Theme.textSecondary
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fs(12)
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                        }
                        Text {
                            width: parent.width
                            visible: scope.updateCount === 0 && !scope.checking
                            text: "You're all set — new updates will show up here."
                            wrapMode: Text.WordWrap
                            color: Theme.textSecondary
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.fs(11)
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }
                        Text {
                            width: parent.width
                            visible: scope.updateCount > 0
                            text: "Nothing is installed automatically. Updates ask for your password once in the terminal."
                            wrapMode: Text.WordWrap
                            color: Theme.textSecondary
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.fs(11)
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }
                        Column {
                            visible: scope.updateCount > 0
                            width: parent.width
                            spacing: 8
                            Hairline { width: parent.width }
                            PillButton {
                                label: "Update everything"
                                highlighted: true
                                width: parent.width
                                onClicked: scope.launch("all")
                            }
                        }
                        Repeater {
                            model: scope.sections
                            delegate: Column {
                                required property var modelData
                                width: contentCol.width
                                spacing: 6
                                visible: scope.count(modelData.id) > 0
                                Hairline { width: parent.width }
                                RowLayout {
                                    width: parent.width
                                    spacing: 8
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.title + " · " + scope.count(modelData.id)
                                        color: Theme.textPrimary
                                        font.family: Theme.iconFontFamily
                                        font.pixelSize: Theme.fs(12)
                                        font.weight: Font.Bold
                                        elide: Text.ElideRight
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                    }
                                    ArrowButton {
                                        visible: modelData.id === "system" && scope.count(modelData.id) > scope.compactRowLimit
                                        expanded: scope.sectionExpanded(modelData.id)
                                        onClicked: scope.toggleSection(modelData.id)
                                    }
                                    PillButton {
                                        label: modelData.action
                                        onClicked: scope.launch(modelData.id)
                                    }
                                    PillButton {
                                        visible: scope.detailsVisible(modelData.id)
                                        label: scope.sectionExpanded(modelData.id) ? "Less" : "Show all (" + scope.count(modelData.id) + ")"
                                        onClicked: scope.toggleSection(modelData.id)
                                    }
                                }
                                Repeater {
                                    model: scope.visibleSectionRows(modelData.id)
                                    delegate: RowLayout {
                                        required property var modelData
                                        width: parent.width
                                        spacing: 10
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name
                                            elide: Text.ElideRight
                                            color: Theme.textPrimary
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: Theme.fs(11)
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                        }
                                        Text {
                                            Layout.preferredWidth: Math.round(parent.width * 0.38)
                                            Layout.maximumWidth: Math.round(parent.width * 0.38)
                                            text: modelData.detail
                                            elide: Text.ElideRight
                                            horizontalAlignment: Text.AlignRight
                                            color: Theme.textSecondary
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: Theme.fs(11)
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                        }
                                    }
                                }
                            }
                        }
                        Column {
                            width: parent.width
                            spacing: 8
                            Hairline { width: parent.width }
                            SectionHeader { text: "CHECK FOR UPDATES" }
                            Flow {
                                width: parent.width
                                spacing: 4
                                Repeater {
                                    model: scope.scheduleOptions
                                    delegate: PillButton {
                                        required property var modelData
                                        compact: true
                                        label: scope.checkSchedule === modelData.value ? "✓ " + modelData.label : modelData.label
                                        highlighted: scope.checkSchedule === modelData.value
                                        onClicked: scope.setCheckSchedule(modelData.value)
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
