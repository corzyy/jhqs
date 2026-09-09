pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../themes"
import "../Ui"

Scope {
    id: trayScope
    property bool showTray: false
    signal dismissed()
    property bool _winVisible: showTray
    Timer { id: trayHideTimer; interval: Theme.animSlow + 20; repeat: false; onTriggered: if (!trayScope.showTray) trayScope._winVisible = false }
    onShowTrayChanged: {
        if (showTray) { _winVisible = true; trayHideTimer.stop() } else trayHideTimer.restart()
    }
    readonly property string barPos: Theme.barPosition
    readonly property int screenGap: 6
    property int panelGap: screenGap - Theme.barThickness
    readonly property bool isMinimal: Theme.minimalTheme

    readonly property var rawItems: {
        let out = []
        try {
            let vals = SystemTray.items.values
            for (let i = 0; i < vals.length; i++) {
                let it = vals[i]
                if (!it || it.status === Status.Passive) continue
                out.push(it)
            }
        } catch (e) { }
        return out
    }
    function displayName(item): string {
        try {
            let t = String(item.title || "").trim()
            if (t.length > 0) return t
            let tt = String(item.tooltipTitle || "").trim()
            if (tt.length > 0) return tt
            let id = String(item.id || "")
            let slash = id.lastIndexOf("/")
            if (slash !== -1) id = id.substring(slash + 1)
            if (id.length > 0) return id
        } catch (e) { }
        return "Unknown"
    }
    function iconIsSymbolic(icon): bool {
        let name = String(icon || "").split("?")[0]
        return name.slice(-9) === "-symbolic"
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: trayScope._winVisible && modelData.name === "DP-1"
            color: "transparent"
            exclusiveZone: 0
            anchors { top: true; left: true; right: true; bottom: true }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "systemtray"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) { trayScope.dismissed(); event.accepted = true }
                }
                Component.onCompleted: forceActiveFocus()
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: trayScope.dismissed()
            }
            Rectangle {
                antialiasing: Theme.shapesAa
                id: trayBox
                width: 340
                implicitHeight: Math.max(120, Math.min(24 + trayFlick.contentHeight, 440))
                Behavior on implicitHeight { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingSmooth } }
                BarAnchor {
                    id: trayAnchor
                    moduleId: "systemtray"
                    barPos: trayScope.barPos
                    panelWidth: trayBox.width
                    panelHeight: trayBox.implicitHeight
                    screenWidth: trayBox.parent.width
                    screenHeight: trayBox.parent.height
                    gap: trayScope.panelGap
                    fallbackX: (trayBox.parent.width - trayBox.width) / 2
                    fallbackY: (trayBox.parent.height - trayBox.implicitHeight) / 2
                }
                x: trayAnchor.panelX
                y: trayAnchor.panelY
                Behavior on x { enabled: trayAnchor.valid && traySpring.offset === 0; NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingSmooth } }
                Behavior on y { enabled: trayAnchor.valid && traySpring.offset === 0; NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingSmooth } }
                color: trayScope.isMinimal ? Theme.bg : Theme.panelBg
                border.color: trayScope.isMinimal ? Theme.accent : Theme.panelBorderColor
                border.width: trayScope.isMinimal ? 2 : 1
                radius: trayScope.isMinimal ? 0 : Theme.cornerRadius
                clip: true
                Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingSmooth } }
                PanelSpring {
                    id: traySpring
                    slideFade: true
                    shown: trayScope.showTray
                    hiddenX: trayScope.barPos === "left" ? -(trayBox.width + 5) : trayScope.barPos === "right" ? (trayBox.width + 5) : 0
                    hiddenY: trayScope.barPos === "top" ? -(trayBox.implicitHeight + 5) : trayScope.barPos === "bottom" ? (trayBox.implicitHeight + 5) : 0
                }
                visible: traySpring.boxVisible
                opacity: traySpring.fade
                scale: traySpring.zoom
                transformOrigin: trayAnchor.origin
                transform: Translate { x: traySpring.slideX; y: traySpring.slideY }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onClicked: mouse => mouse.accepted = true
                    onPressed: mouse => mouse.accepted = true
                    onWheel: wheel => wheel.accepted = true
                }
                Flickable {
                    id: trayFlick
                    anchors.fill: parent
                    anchors.margins: 12
                    contentHeight: trayCol.implicitHeight
                    contentWidth: width
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick
                    ColumnLayout {
                        id: trayCol
                        width: parent.width
                        spacing: 10
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                Layout.fillWidth: true
                                text: "System Tray"
                                font.family: Theme.fontFamily; font.pixelSize: Theme.fs(14); font.weight: Font.Bold
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                            }
                            Text {
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                Layout.fillWidth: true
                                text: "Angeheftet bleibt sichtbar · Versteckt nie"
                                font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10)
                                color: Theme.textSecondary
                                elide: Text.ElideRight
                            }
                        }
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            visible: trayScope.rawItems.length === 0
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            topPadding: 12
                            text: "Keine Tray-Icons aktiv"
                            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12); font.italic: true
                            color: Theme.textMuted
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Repeater {
                                model: trayScope.rawItems
                                delegate: Rectangle {
                                    id: trayRow
                                    required property var modelData
                                    required property int index
                                    property var item: modelData
                                    property string iid: String((modelData && modelData.id) || "")
                                    property bool isPinned: Theme.isTrayPinned(iid)
                                    property bool isHidden: Theme.isTrayHidden(iid)
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 40
                                    radius: Theme.cornerRadiusSmall
                                    color: rowMouse.containsMouse ? Theme.bgHover : "transparent"
                                    border.color: rowMouse.containsMouse ? Theme.divider : "transparent"
                                    border.width: 1
                                    opacity: isHidden ? 0.55 : 1.0
                                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                                    MouseArea {
                                        id: rowMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 8
                                        Item {
                                            Layout.preferredWidth: 18
                                            Layout.preferredHeight: 18
                                            Image {
                                                smooth: Theme.imageSmooth
                                                mipmap: Theme.imageMipmap
                                                id: rowImg
                                                anchors.fill: parent
                                                fillMode: Image.PreserveAspectFit
                                                sourceSize.width: Math.round(18 * Screen.devicePixelRatio)
                                                sourceSize.height: Math.round(18 * Screen.devicePixelRatio)
                                                source: String(trayRow.item.icon || "")
                                                asynchronous: true
                                                cache: true
                                                visible: !trayScope.iconIsSymbolic(trayRow.item.icon)
                                                onStatusChanged: if (status === Image.Error) source = ""
                                            }
                                            MultiEffect {
                                                anchors.fill: parent
                                                source: rowImg
                                                visible: trayScope.iconIsSymbolic(trayRow.item.icon)
                                                colorization: 1.0
                                                colorizationColor: Theme.textPrimary
                                            }
                                        }
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            Layout.fillWidth: true
                                            text: trayScope.displayName(trayRow.item)
                                            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12)
                                            color: Theme.textPrimary
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }
                                        Rectangle {
                                            antialiasing: Theme.shapesAa
                                            id: pinBtn
                                            Layout.preferredWidth: 52
                                            Layout.preferredHeight: 28
                                            radius: Theme.cornerRadiusSmall
                                            color: trayRow.isPinned ? Theme.bgSelected : (pinMouse.containsMouse ? Theme.bgHover : Theme.panelSurface)
                                            border.color: Theme.divider
                                            border.width: 1
                                            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                                            Text {
                                                antialiasing: Theme.textAa
                                                renderType: Theme.textRenderType
                                                anchors.centerIn: parent
                                                text: trayRow.isPinned ? "Fix" : "Pin"
                                                font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10); font.weight: Font.Medium
                                                color: trayRow.isPinned ? Theme.textPrimary : Theme.textSecondary
                                            }
                                            MouseArea {
                                                id: pinMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: Theme.toggleTrayPinned(trayRow.iid)
                                            }
                                        }
                                        Rectangle {
                                            antialiasing: Theme.shapesAa
                                            id: hideBtn
                                            Layout.preferredWidth: 52
                                            Layout.preferredHeight: 28
                                            radius: Theme.cornerRadiusSmall
                                            color: trayRow.isHidden ? Theme.bgSelected : (hideMouse.containsMouse ? Theme.bgHover : Theme.panelSurface)
                                            border.color: Theme.divider
                                            border.width: 1
                                            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                                            Text {
                                                antialiasing: Theme.textAa
                                                renderType: Theme.textRenderType
                                                anchors.centerIn: parent
                                                text: trayRow.isHidden ? "Zeigen" : "Hide"
                                                font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10); font.weight: Font.Medium
                                                color: trayRow.isHidden ? Theme.textPrimary : Theme.textSecondary
                                            }
                                            MouseArea {
                                                id: hideMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: Theme.toggleTrayHidden(trayRow.iid)
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
    }
}
