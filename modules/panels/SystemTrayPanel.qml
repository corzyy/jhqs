pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../../themes"
import "../../Ui"

Scope {
    id: trayScope
    property bool showTray: false
    signal dismissed()
    property bool _winVisible: showTray
    Timer { id: trayHideTimer; interval: 0; repeat: false; onTriggered: if (!trayScope.showTray) trayScope._winVisible = false }
    onShowTrayChanged: {
        if (showTray) { _winVisible = true; trayHideTimer.stop() } else trayHideTimer.restart()
    }
    readonly property string barPos: Theme.barPosition
    readonly property int screenGap: 6
    property int panelGap: screenGap - Theme.barThickness

    // PERF: hidden panel keeps zero items (was rebuilding the array + all
    // row delegates on every tray signal even when closed).
    readonly property var rawItems: {
        if (!trayScope.showTray) return []
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
                color: Theme.bg
                border.color: Theme.panelBorderColor
                border.width: 2
                radius: 0
                clip: true
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
                    contentWidth: trayCol.width
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
                                model: trayScope.showTray ? trayScope.rawItems : []
                                delegate: Rectangle {
                                    id: trayRow
                                    required property var modelData
                                    required property int index
                                    property var item: modelData
                                    property string iid: String((modelData && modelData.id) || "")
                                    property bool isPinned: Theme.isTrayPinned(iid)
                                    property bool isHidden: Theme.isTrayHidden(iid)
                                    // PERF: per-delegate cache — displayName() does
                                    // String+slice+try/catch; symbolic avoids a
                                    // string split per reveal frame.
                                    readonly property string iconSrc: String((trayRow.item && trayRow.item.icon) || "")
                                    readonly property bool symbolic: {
                                        let n = iconSrc.split("?")[0]
                                        return n.slice(-9) === "-symbolic"
                                    }
                                    readonly property string dName: {
                                        try {
                                            let t = String(trayRow.item.title || "").trim()
                                            if (t.length > 0) return t
                                            let tt = String(trayRow.item.tooltipTitle || "").trim()
                                            if (tt.length > 0) return tt
                                            let id = String(trayRow.item.id || "")
                                            let slash = id.lastIndexOf("/")
                                            if (slash !== -1) id = id.substring(slash + 1)
                                            if (id.length > 0) return id
                                        } catch (e) { }
                                        return "Unknown"
                                    }
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 40
                                    radius: Theme.cornerRadiusSmall
                                    color: rowMouse.containsMouse ? Theme.bgHover : "transparent"
                                    border.color: rowMouse.containsMouse ? Theme.divider : "transparent"
                                    border.width: 1
                                    opacity: isHidden ? 0.55 : 1.0
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
                                                // PERF: fixed 36px decode (was DPR-scaled,
                                                // refetching all icons on DPR change).
                                                sourceSize.width: 36
                                                sourceSize.height: 36
                                                source: trayRow.symbolic ? "" : trayRow.iconSrc
                                                asynchronous: true
                                                cache: true
                                                visible: !trayRow.symbolic
                                                onStatusChanged: if (status === Image.Error && source !== "") source = ""
                                            }
                                            // PERF: MultiEffect is an offscreen pass per
                                            // row — Loader-gate to symbolic icons only.
                                            Loader {
                                                anchors.fill: parent
                                                active: trayRow.symbolic
                                                asynchronous: true
                                                sourceComponent: traySymbolFx
                                            }
                                            Component {
                                                id: traySymbolFx
                                                MultiEffect {
                                                    source: rowImg
                                                    colorization: 1.0
                                                    colorizationColor: Theme.textPrimary
                                                }
                                            }
                                        }
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            Layout.fillWidth: true
                                            text: trayRow.dName
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
