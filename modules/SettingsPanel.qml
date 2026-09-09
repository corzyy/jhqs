pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../themes"
import "../services"
import "../Ui"
import "./settings" as S
import "./settings/pages" as Pages

Scope {
    id: settingsScope
    property bool showSettings: false
    property string section: "global"
    property string filterText: ""
    signal dismissed()

    property bool _winVisible: showSettings
    Timer { id: settingsHideTimer; interval: Theme.animSlow + 20; repeat: false; onTriggered: if (!settingsScope.showSettings) settingsScope._winVisible = false }
    onShowSettingsChanged: {
        if (showSettings) {
            _winVisible = true
            settingsHideTimer.stop()
            SettingsService.refresh()
        } else {
            settingsHideTimer.restart()
            filterText = ""
        }
    }

    readonly property string barPos: Theme.barPosition
    readonly property int screenGap: 6
    property int panelGap: screenGap - Theme.barThickness
    readonly property bool isMinimal: Theme.minimalTheme

    IpcHandler {
        target: "settings"
        function state(): string { return "visible=" + settingsScope.showSettings + " section=" + settingsScope.section }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: settingsScope._winVisible && modelData.name === "DP-1"
            color: "transparent"
            exclusiveZone: -1
            anchors { top: true; left: true; right: true; bottom: true }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "settings-backdrop"
            Rectangle {
                antialiasing: Theme.shapesAa
                anchors.fill: parent
                color: Theme.scrim
                opacity: settingsScope.showSettings ? 0.25 : 0.0
                Behavior on opacity { NumberAnimation { duration: settingsScope.showSettings ? Theme.panelAnimFade : Theme.animSlow; easing.type: settingsScope.showSettings ? Theme.panelEasingFade : Theme.panelEasingExit } }
            }
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: settingsScope.dismissed() }
        }
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: settingsScope._winVisible && modelData.name === "DP-1"
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
                    } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_8) {
                        let ids = ["global", "hypr", "bar", "modules", "workspaces", "notif", "osd", "search"]
                        let i = event.key - Qt.Key_1
                        if (i >= 0 && i < ids.length) settingsScope.section = ids[i]
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
                color: settingsScope.isMinimal ? Theme.bg : Theme.panelBg
                border.color: settingsScope.isMinimal ? Theme.accent : Theme.panelBorderColor
                border.width: settingsScope.isMinimal ? 2 : 1
                radius: settingsScope.isMinimal ? 0 : Theme.cornerRadius
                clip: true
                Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingSmooth } }
                PanelSpring {
                    id: settingsSpring
                    slideFade: true
                    shown: settingsScope.showSettings
                    hiddenX: 0
                    hiddenY: -(settingsBox.implicitHeight + 5)
                }
                visible: settingsSpring.boxVisible
                opacity: settingsSpring.fade
                scale: settingsSpring.zoom
                transformOrigin: Item.Center
                transform: Translate { x: settingsSpring.slideX; y: settingsSpring.slideY }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onClicked: mouse => mouse.accepted = true
                    onPressed: mouse => mouse.accepted = true
                    onWheel: wheel => wheel.accepted = true
                }
                Column {
                    anchors.fill: parent
                    anchors.margins: settingsScope.isMinimal ? 18 : 12
                    spacing: settingsScope.isMinimal ? 14 : 10
                    Item {
                        width: parent.width
                        height: 36
                        Text { id: settingsTitle; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "󰒓  Settings"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(15); font.weight: Font.Bold; color: Theme.textPrimary
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }
                        Text { anchors.left: settingsTitle.right; anchors.leftMargin: 10; anchors.right: closeBtn.left; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: settingsScope.isMinimal ? settingsScope.section.toUpperCase() : "—  " + settingsScope.section; font.family: settingsScope.isMinimal ? Theme.iconFontFamily : Theme.fontFamily; font.pixelSize: Theme.fs(settingsScope.isMinimal ? 10 : 12); font.weight: settingsScope.isMinimal ? Font.Bold : Font.Normal; font.letterSpacing: settingsScope.isMinimal ? 1.2 : 0.8; color: settingsScope.isMinimal ? Theme.textSecondary : Theme.textMuted; elide: Text.ElideRight
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            id: closeBtn
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 36; height: 36
                            radius: settingsScope.isMinimal ? 0 : Theme.cornerRadiusSmall
                            color: closeMouse.containsMouse ? (settingsScope.isMinimal ? Theme.withAlpha(Theme.textPrimary, 0.08) : Theme.bgHover) : "transparent"
                            border.color: settingsScope.isMinimal ? Theme.withAlpha(Theme.textPrimary, 0.25) : Theme.divider; border.width: 1
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
                        height: parent.height - 36 - (settingsScope.isMinimal ? 14 : 10)
                        spacing: settingsScope.isMinimal ? 14 : 10
                        S.SettingsSidebar {
                            height: bodyRow.height
                            current: settingsScope.section
                            query: settingsScope.filterText
                            onSelect: n => settingsScope.section = n
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
                            onContentHeightChanged: contentY = 0
                            Column {
                                id: pageCol
                                width: pageFlick.width
                                spacing: settingsScope.isMinimal ? 14 : 10
                                Pages.GlobalPage { visible: settingsScope.section === "global"; width: parent.width }
                                Pages.HyprPage { visible: settingsScope.section === "hypr"; width: parent.width }
                                Pages.TopBarPage { visible: settingsScope.section === "bar"; width: parent.width }
                                Pages.ModulesPage { visible: settingsScope.section === "modules"; width: parent.width }
                                Pages.WorkspacesPage { visible: settingsScope.section === "workspaces"; width: parent.width }
                                Pages.NotificationsPage { visible: settingsScope.section === "notif"; width: parent.width }
                                Pages.OsdPage { visible: settingsScope.section === "osd"; width: parent.width }
                                Pages.SearchPage { visible: settingsScope.section === "search"; width: parent.width }
                            }
                        }
                    }
                }
            }
        }
    }
}
