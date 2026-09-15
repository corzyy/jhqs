pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../themes"
import "../../services"
import "../settings" as S
import "../settings/pages" as Pages

// Settings rework: one synchronous Loader for the active page (no async
// blank races, no 9-loader flip flapping), one source of truth for the
// section, no hide-timer / _winVisible two-stage visibility.
Scope {
    id: settingsScope
    property bool showSettings: false
    property string section: "global"
    property string filterText: ""
    signal dismissed()

    // All valid sections in sidebar order. Unknown ids fall back to global
    // so a stale id can never blank the panel.
    readonly property var sectionIds: ["global", "mango", "bar", "vitals", "workspaces", "calendar", "notif"]
    readonly property var sectionTitles: ["Global", "Mango", "Top Bar", "Vitals", "Workspaces", "Calendar", "Notifications"]
    readonly property var sectionIcons: ["󰔎", "󰖳", "󰍹", "󰻠", "", "󰃭", "󰂚"]
    function sectionTitle(id: string): string {
        let i = sectionIds.indexOf(id)
        return i >= 0 ? sectionTitles[i] : "Global"
    }
    function sectionIcon(id: string): string {
        let i = sectionIds.indexOf(id)
        return i >= 0 ? sectionIcons[i] : "󰔎"
    }
    function selectSection(id: string): void {
        let nid = (id === "modules") ? "vitals" : id
        section = sectionIds.indexOf(nid) >= 0 ? nid : "global"
    }

    // Robust page swap: Components are direct children of Scope (same
    // lexical scope, so pageFor sees them under ComponentBehavior: Bound).
    // Pages size themselves via `width: parent ? parent.width : 400`,
    // so no width binding (which would need an out-of-scope id) is used.
    function pageFor(s: string): Component {
        switch (s) {
        case "mango": return mangoComp
        case "bar": return barComp
        case "vitals": return vitalsComp
        case "workspaces": return workspacesComp
        case "calendar": return calendarComp
        case "notif": return notifComp
        default: return globalComp
        }
    }

    onShowSettingsChanged: {
        if (showSettings) {
            SettingsService.refresh()
            try { MangoService.refresh() } catch (e) {}
        } else {
            filterText = ""
        }
    }

    IpcHandler {
        target: "settings"
        function state(): string { return "visible=" + settingsScope.showSettings + " section=" + settingsScope.section }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: settingsScope.showSettings && Theme.isPrimaryScreen(modelData)
            color: "transparent"
            exclusiveZone: 0
            anchors { top: true; left: true; right: true; bottom: true }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "settings"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        if (settingsScope.filterText.length > 0) settingsScope.filterText = ""
                        else settingsScope.dismissed()
                        event.accepted = true
                    } else if (event.modifiers === Qt.NoModifier && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                        let i = event.key - Qt.Key_1
                        if (i >= 0 && i < settingsScope.sectionIds.length) settingsScope.selectSection(settingsScope.sectionIds[i])
                        event.accepted = true
                    } else if (event.modifiers === Qt.NoModifier && event.key === Qt.Key_0) {
                        if (settingsScope.sectionIds.length > 9) settingsScope.selectSection(settingsScope.sectionIds[9])
                        event.accepted = true
                    }
                }
                Component.onCompleted: forceActiveFocus()
            }
            // Dim lives in the SAME layer surface as the dialog: a separate
            // backdrop surface has no defined stacking order vs. the dialog,
            // and on mango it can sit on top, dismissing the panel on ANY
            // click (even inside the dialog).
            Rectangle {
                antialiasing: Theme.shapesAa
                anchors.fill: parent
                color: Theme.scrim
                opacity: 0.25
            }
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: settingsScope.dismissed() }
            Rectangle {
                antialiasing: Theme.shapesAa
                id: settingsBox
                // STABILITY: clamp to small screens (was fixed 760px,
                // overflowing <800px displays with no way to reach buttons).
                width: Math.min(760, parent.width - 32)
                implicitHeight: Math.min(620, parent.height - 60)
                x: (parent.width - width) / 2
                y: (parent.height - implicitHeight) / 2
                color: Theme.bg
                border.color: Theme.panelBorderColor
                border.width: 2
                radius: Theme.cornerRadius
                clip: true
                visible: settingsScope.showSettings
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onClicked: mouse => mouse.accepted = true
                    onPressed: mouse => mouse.accepted = true
                    onWheel: wheel => wheel.accepted = true
                }
                Column {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12
                    Row {
                        id: headerRow
                        width: parent.width
                        height: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, closeBtn.height)
                        spacing: 14
                        Text {
                            id: heroIcon
                            text: settingsScope.sectionIcon(settingsScope.section)
                            color: Theme.textPrimary
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.fs(24)
                            anchors.verticalCenter: parent.verticalCenter
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }
                        Column {
                            id: heroLabels
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - heroIcon.width - closeBtn.width - 28
                            Text {
                                width: parent.width
                                text: "Settings"
                                color: Theme.textPrimary
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fs(16)
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                        }
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            id: closeBtn
                            anchors.verticalCenter: parent.verticalCenter
                            width: 32; height: 32
                            radius: Theme.cornerRadiusSmall
                            color: closeMouse.containsMouse ? Theme.bgHover : "transparent"
                            border.color: Theme.divider; border.width: 1
                            Text { anchors.centerIn: parent; text: "✕"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(13); color: Theme.textSecondary
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                            MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: settingsScope.dismissed() }
                        }
                    }
                    Rectangle {
                        width: parent.width; height: 1
                        color: Theme.withAlpha(Theme.textPrimary, 0.12)
                        antialiasing: Theme.shapesAa
                    }
                    Row {
                        id: bodyRow
                        width: parent.width
                        height: parent.height - headerRow.height - 1 - 24
                        spacing: 0
                        S.SettingsControls.SettingsSidebar {
                            height: bodyRow.height
                            current: settingsScope.section
                            query: settingsScope.filterText
                            onSelect: n => settingsScope.selectSection(n)
                            onQueryChanged2: t => settingsScope.filterText = t
                        }
                        Item { width: 16; height: parent.height }
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            width: 1
                            height: parent.height - 8
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.divider
                            opacity: 0.8
                        }
                        Item { width: 16; height: parent.height }
                        Item {
                            width: parent.width - 200 - 1 - 32
                            height: parent.height
                        Flickable {
                            id: pageFlick
                            anchors.fill: parent
                            clip: true
                            contentHeight: pageCol.implicitHeight
                            contentWidth: width
                            boundsBehavior: Flickable.StopAtBounds
                            flickableDirection: Flickable.VerticalFlick
                            Connections {
                                target: settingsScope
                                function onSectionChanged() { pageFlick.contentY = 0 }
                            }
                            Column {
                                id: pageCol
                                width: pageFlick.width
                                spacing: 12
                                // RAM + robustness: exactly one page exists at a
                                // time, loaded synchronously so a click swaps
                                // content in the same frame (no blank races).
                                // Unloaded when the panel closes.
                                Loader {
                                    id: pageLoader
                                    width: parent.width
                                    active: settingsScope.showSettings
                                    asynchronous: false
                                    sourceComponent: settingsScope.pageFor(settingsScope.section)
                                }
                            }
                        }
                        }
                    }
                }
            }
        }
    }

    Component { id: globalComp; Pages.GlobalPage {} }
    Component { id: mangoComp; Pages.MangoPage {} }
    Component { id: barComp; Pages.TopBarPage {} }
    Component { id: vitalsComp; Pages.VitalsPage {} }
    Component { id: workspacesComp; Pages.WorkspacesPage {} }
    Component { id: calendarComp; Pages.CalendarPage {} }
    Component { id: notifComp; Pages.NotificationsPage {} }
}
