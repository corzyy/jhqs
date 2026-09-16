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
    Timer { id: trayHideTimer; interval: Theme.panelHideDelay; repeat: false; onTriggered: if (!trayScope.showTray) trayScope._winVisible = false }
    onShowTrayChanged: {
        if (showTray) { _winVisible = true; trayHideTimer.stop() } else trayHideTimer.restart()
    }
    readonly property string barPos: Theme.barPosition
    // Attached-bar morph: tuck under the bar edge (see Theme.panelAttachOverlap)
    // instead of floating detached below it.
    property int panelGap: -(Theme.barThickness + Theme.panelAttachOverlap)

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
            visible: trayScope._winVisible && Theme.isPrimaryScreen(modelData)
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
            // Caelestia popout (Ui/CaelestiaPopout): curtain reveal from
            // behind the bar edge + slide + nested fades, all off one
            // offsetScale driver (1:1 with caelestia-dots/shell).
            CaelestiaPopout {
                id: trayPopout
                shown: trayScope.showTray
                barPos: trayScope.barPos
                fullWidth: 340
                fullHeight: trayBox.implicitHeight
                anchorCenter: trayAnchor.isVertical ? trayAnchor.cy : trayAnchor.cx
                edge: trayScope.barPos === "bottom" ? trayAnchor.panelY + trayBox.implicitHeight : trayScope.barPos === "right" ? trayAnchor.panelX + 340 : trayScope.barPos === "left" ? trayAnchor.panelX : trayAnchor.panelY
                screenSize: trayAnchor.isVertical ? trayAnchor.screenHeight : trayAnchor.screenWidth
                margin: trayAnchor.margin

                BarAnchor {
                    id: trayAnchor
                    moduleId: "systemtray"
                    barPos: trayScope.barPos
                    panelWidth: 340
                    panelHeight: trayBox.implicitHeight
                    screenWidth: trayPopout.parent.width
                    screenHeight: trayPopout.parent.height
                    gap: trayScope.panelGap
                    fallbackX: (trayPopout.parent.width - 340) / 2
                    fallbackY: (trayPopout.parent.height - trayBox.implicitHeight) / 2
                }

                Rectangle {
                    antialiasing: Theme.shapesAa
                    id: trayBox
                        // The popout owns position/size: the card fills the
                        // holder, its implicit height is the open geometry the
                        // popout glides to when the tray content changes.
                        width: parent.width
                        height: parent.height
                        implicitHeight: Math.max(120, Math.min(24 + trayFlick.contentHeight, 440))
                        color: Theme.bg
                        border.color: Theme.panelBorderColor
                        border.width: 2
                        radius: Theme.cornerRadius
                        // Unclipped: the fillets paint outside the box; the inner
                        // Flickable already clips its own content.
                        clip: false
                        // Square fused corners (tray-menu joint); plain children,
                        // so they emerge with the card exactly like the box.
                        PanelCorner { side: "left"; edge: trayScope.barPos === "bottom" ? "bottom" : "top"; visible: trayPopout.offsetScale < 1 }
                        PanelCorner { side: "right"; edge: trayScope.barPos === "bottom" ? "bottom" : "top"; visible: trayPopout.offsetScale < 1 }
                        // Outward-curved shoulders on top of the fusion (Caelestia joint).
                        PanelFillet { side: "left"; edge: trayScope.barPos === "bottom" ? "bottom" : "top"; visible: trayPopout.offsetScale < 1 }
                        PanelFillet { side: "right"; edge: trayScope.barPos === "bottom" ? "bottom" : "top"; visible: trayPopout.offsetScale < 1 }
                        // Seam strip: erases the collar outline along the fused edge.
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            x: 0
                            y: trayScope.barPos === "bottom" ? trayBox.height - 2 : 0
                            width: trayBox.width
                            height: 2
                            color: Theme.bg
                        }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.AllButtons
                        onClicked: mouse => mouse.accepted = true
                        onPressed: mouse => mouse.accepted = true
                        onWheel: wheel => wheel.accepted = true
                    }
                    Flickable {
                        id: trayFlick
                        // Content travels on the popout's own driver (frame
                        // stretches first, content settles after) and keeps
                        // the full panel size so nothing reflows mid-stretch.
                        x: 12 + trayPopout.contentX
                        y: 12 + trayPopout.contentY
                        width: trayPopout.fullWidth - 24
                        height: trayPopout.fullHeight - 24
                        contentHeight: trayCol.implicitHeight
                        contentWidth: trayCol.width
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.VerticalFlick
                        ColumnLayout {
                            id: trayCol
                            // Full box width (never the growing pill width): no
                            // reflow mid-morph; the Flickable clip reveals it.
                            width: 340 - 24
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
                                    text: "Pinned stays visible · never hidden"
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
                                text: "No tray icons active"
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
}
