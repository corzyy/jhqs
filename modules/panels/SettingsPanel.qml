pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../themes"
import "../services"
import "./settings" as S
import "./settings/pages" as Pages

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
    readonly property var sectionIds: ["global", "theming", "hypr", "bar", "modules", "workspaces", "notif", "osd", "search"]
    function selectSection(id: string): void {
        section = sectionIds.indexOf(id) >= 0 ? id : "global"
    }

    // Robust page swap: Components are direct children of Scope (same
    // lexical scope, so pageFor sees them under ComponentBehavior: Bound).
    // Pages size themselves via `width: parent ? parent.width : 400`,
    // so no width binding (which would need an out-of-scope id) is used.
    function pageFor(s: string): Component {
        switch (s) {
        case "theming": return themingComp
        case "hypr": return hyprComp
        case "bar": return barComp
        case "modules": return modulesComp
        case "workspaces": return workspacesComp
        case "notif": return notifComp
        case "osd": return osdComp
        case "search": return searchComp
        default: return globalComp
        }
    }

    onShowSettingsChanged: {
        if (showSettings) {
            SettingsService.refresh()
            ThemingService.refresh()
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
            visible: settingsScope.showSettings && modelData.name === "DP-1"
            color: "transparent"
            exclusiveZone: -1
            anchors { top: true; left: true; right: true; bottom: true }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "settings-backdrop"
            Rectangle {
                antialiasing: Theme.shapesAa
                anchors.fill: parent
                color: Theme.scrim
                opacity: 0.25
            }
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: settingsScope.dismissed() }
        }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: settingsScope.showSettings && modelData.name === "DP-1"
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
                    } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                        let i = event.key - Qt.Key_1
                        if (i >= 0 && i < settingsScope.sectionIds.length) settingsScope.selectSection(settingsScope.sectionIds[i])
                        event.accepted = true
                    }
                }
                Component.onCompleted: forceActiveFocus()
            }
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: settingsScope.dismissed() }
            Rectangle {
                antialiasing: Theme.shapesAa
                id: settingsBox
                width: 740
                implicitHeight: Math.min(600, parent.height - 60)
                x: (parent.width - width) / 2
                y: (parent.height - implicitHeight) / 2
                color: Theme.bg
                border.color: Theme.accent
                border.width: 2
                radius: 0
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
                    spacing: 14
                    Item {
                        width: parent.width
                        height: 36
                        Text { id: settingsTitle; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "  Settings"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(15); font.weight: Font.Bold; color: Theme.textPrimary
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }
                        Text { anchors.left: settingsTitle.right; anchors.leftMargin: 10; anchors.right: closeBtn.left; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: settingsScope.section.toUpperCase(); font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(10); font.weight: Font.Bold; font.letterSpacing: 1.2; color: Theme.textSecondary; elide: Text.ElideRight
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            id: closeBtn
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 36; height: 36
                            radius: 0
                            color: closeMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.08) : "transparent"
                            border.color: Theme.withAlpha(Theme.textPrimary, 0.25); border.width: 1
                            Text { anchors.centerIn: parent; text: "✕"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(13); color: Theme.textSecondary
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                            MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: settingsScope.dismissed() }
                        }
                    }
                    Row {
                        id: bodyRow
                        width: parent.width
                        height: parent.height - 36 - 14
                        spacing: 14
                        S.SettingsControls.SettingsSidebar {
                            height: bodyRow.height
                            current: settingsScope.section
                            query: settingsScope.filterText
                            onSelect: n => settingsScope.selectSection(n)
                            onQueryChanged2: t => settingsScope.filterText = t
                        }
                        Flickable {
                            id: pageFlick
                            width: parent.width - 200
                            height: parent.height
                            clip: true
                            contentHeight: pageCol.height
                            contentWidth: width
                            boundsBehavior: Flickable.StopAtBounds
                            flickableDirection: Flickable.VerticalFlick
                            Connections {
                                target: settingsScope
                                ignoreUnknownSignals: true
                                function onSectionChanged() { pageFlick.contentY = 0 }
                            }
                            Column {
                                id: pageCol
                                width: pageFlick.width
                                spacing: 14
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

    Component { id: globalComp; Pages.GlobalPage {} }
    Component { id: themingComp; Pages.ThemingPage {} }
    Component { id: hyprComp; Pages.HyprPage {} }
    Component { id: barComp; Pages.TopBarPage {} }
    Component { id: modulesComp; Pages.ModulesPage {} }
    Component { id: workspacesComp; Pages.WorkspacesPage {} }
    Component { id: notifComp; Pages.NotificationsPage {} }
    Component { id: osdComp; Pages.OsdPage {} }
    Component { id: searchComp; Pages.SearchPage {} }
}
