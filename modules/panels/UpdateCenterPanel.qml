pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../themes"
import "../services"
import "../Ui"

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
    readonly property bool checking: UpdateService.checking
    readonly property var lastChecked: UpdateService.lastCheckedAt
    readonly property string checkSchedule: UpdateService.checkSchedule
    readonly property bool offerShutdownAction: UpdateService.offerShutdownAction

    readonly property string headerTitle: checking ? "Checking updates…" : (updates.length > 0 ? updates.length + " updates available" : "Everything is up to date")
    readonly property string lastCheckedLabel: lastChecked ? "Last check: " + Qt.formatDateTime(lastChecked, "ddd d MMM · HH:mm") : "Not checked yet"
    readonly property string updateScript: Quickshell.env("HOME") + "/.config/quickshell/jhqs/scripts/update.sh"

    function refresh(): void { UpdateService.checkNow() }

    function count(source: string): int {
        let total = 0
        for (let i = 0; i < updates.length; i++) if (updates[i].source === source) total++
        return total
    }
    function sectionRows(source: string): var {
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
        if (source === "system" && !sectionExpanded(source)) return []
        if (source === "flatpak" && rows.length > 1 && !sectionExpanded(source)) return []
        return sectionExpanded(source) ? rows : rows.slice(0, compactRowLimit)
    }
    function detailsVisible(source: string): bool {
        if (source === "system") return count(source) > 0
        if (source === "flatpak") return count(source) > 1
        return count(source) > compactRowLimit
    }
    function setCheckSchedule(schedule: string): void { UpdateService.setCheckSchedule(schedule) }

    function shellQuote(value: string): string {
        return "'" + String(value).replace(/'/g, "'\\''") + "'"
    }
    function runInTerminal(command: string, markDone: bool, hold: bool): void {
        let full = command
        if (markDone) full += " && date +%s%N > " + shellQuote(completionPath) + " && printf '\\nUpdate OK.\\n'"
        if (hold) full += '; echo; read -n1 -s -r -p "Press any key to close…"'
        termProc.command = ["bash", "-c", "kitty --class jhqs-update --title Update bash -lc " + shellQuote(full) + " &"]
        if (!termProc.running) termProc.running = true
    }
    function systemCommand(): string {
        return "bash " + shellQuote(updateScript) + " system"
    }
    function aurCommand(): string {
        return "bash " + shellQuote(updateScript) + " aur"
    }
    function flatpakCommand(): string {
        return "bash " + shellQuote(updateScript) + " flatpak"
    }
    function allCommand(): string { return "bash " + shellQuote(updateScript) + " all" }
    function launch(kind: string): void {
        if (kind === "system") runInTerminal(systemCommand(), true, true)
        else if (kind === "aur") runInTerminal(aurCommand(), true, true)
        else if (kind === "flatpak") runInTerminal(flatpakCommand(), true, true)
        else runInTerminal(allCommand(), true, true)
    }
    function updateThenShutdown(): void {
        runInTerminal("bash " + shellQuote(updateScript) + " all -y && systemctl poweroff", false, false)
    }
    function shutdownAnyway(): void {
        runInTerminal("systemctl poweroff", false, false)
    }

    Process { id: termProc; command: ["bash", "-c", "echo"] }

    FileView {
        path: scope.completionPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            let marker = String(text() || "").trim()
            if (marker !== "" && marker !== scope.completionMarker) {
                scope.completionMarker = marker
                scope.refresh()
            }
        }
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
        scale: 1.0
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
                border.color: Theme.accent
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
                        Item {
                            width: parent.width
                            implicitHeight: Math.max(heroLabels.implicitHeight, refreshBtn.implicitHeight)
                            Column {
                                id: heroLabels
                                anchors.left: parent.left
                                anchors.right: refreshBtn.visible ? refreshBtn.left : parent.right
                                anchors.rightMargin: refreshBtn.visible ? 10 : 0
                                anchors.verticalCenter: parent.verticalCenter
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
                                id: refreshBtn
                                visible: !scope.checking
                                label: "Refresh"
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                onClicked: scope.refresh()
                            }
                        }
                        Text {
                            width: parent.width
                            visible: scope.updates.length > 0
                            text: "Nothing is installed automatically. Updates ask for your password once in the terminal."
                            wrapMode: Text.WordWrap
                            color: Theme.textSecondary
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.fs(11)
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }
                        Column {
                            visible: scope.updates.length > 0 && scope.offerShutdownAction
                            width: parent.width
                            spacing: 8
                            Hairline { width: parent.width }
                            PillButton {
                                label: "Update everything"
                                highlighted: true
                                width: parent.width
                                onClicked: scope.launch("all")
                            }
                            Row {
                                width: parent.width
                                spacing: 8
                                PillButton {
                                    label: "Update & shut down"
                                    width: (parent.width - parent.spacing) / 2
                                    onClicked: scope.updateThenShutdown()
                                }
                                PillButton {
                                    label: "Shut down anyway"
                                    width: (parent.width - parent.spacing) / 2
                                    onClicked: scope.shutdownAnyway()
                                }
                            }
                        }
                        Repeater {
                            model: [
                                { id: "system", title: "System", action: "Update system" },
                                { id: "aur", title: "AUR", action: "Update AUR" },
                                { id: "flatpak", title: "Flatpak", action: "Update Flatpak" }
                            ]
                            delegate: Column {
                                required property var modelData
                                width: contentCol.width
                                spacing: 6
                                visible: scope.count(modelData.id) > 0
                                Hairline { width: parent.width }
                                Row {
                                    width: parent.width
                                    spacing: 8
                                    Text {
                                        width: parent.width - updateBtn.width - (detailsBtn.visible ? detailsBtn.width + 16 : 8)
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.title + " · " + scope.count(modelData.id)
                                        color: Theme.textPrimary
                                        font.family: Theme.iconFontFamily
                                        font.pixelSize: Theme.fs(12)
                                        font.weight: Font.Bold
                                        elide: Text.ElideRight
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                    }
                                    PillButton {
                                        id: updateBtn
                                        label: modelData.action
                                        anchors.verticalCenter: parent.verticalCenter
                                        onClicked: scope.launch(modelData.id)
                                    }
                                    PillButton {
                                        id: detailsBtn
                                        visible: scope.detailsVisible(modelData.id)
                                        label: scope.sectionExpanded(modelData.id) ? "Less" : "Show all (" + scope.count(modelData.id) + ")"
                                        anchors.verticalCenter: parent.verticalCenter
                                        onClicked: scope.toggleSection(modelData.id)
                                    }
                                }
                                Repeater {
                                    model: scope.visibleSectionRows(modelData.id)
                                    delegate: Row {
                                        required property var modelData
                                        width: parent.width
                                        spacing: 10
                                        Text {
                                            width: parent.width * 0.54
                                            text: modelData.name
                                            elide: Text.ElideRight
                                            color: Theme.textPrimary
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: Theme.fs(11)
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                        }
                                        Text {
                                            width: parent.width * 0.42
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
                                    model: [
                                        { value: "At startup only", label: "Startup" },
                                        { value: "Every 30 minutes", label: "30 min" },
                                        { value: "Every 2 hours", label: "2 h" },
                                        { value: "Every 6 hours", label: "6 h" },
                                        { value: "Every 12 hours", label: "12 h" },
                                        { value: "Every 24 hours", label: "24 h" }
                                    ]
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
