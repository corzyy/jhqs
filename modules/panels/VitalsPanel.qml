pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../themes"
import "../../services"
import "../../Ui"

Scope {
    id: scope
    property bool showVitals: false
    signal dismissed()
    property bool _winVisible: showVitals
    Timer { id: hideTimer; interval: 0; repeat: false; onTriggered: if (!scope.showVitals) scope._winVisible = false }
    onShowVitalsChanged: {
        if (showVitals) {
            _winVisible = true
            hideTimer.stop()
            VitalsService.refresh()
        } else hideTimer.restart()
    }
    readonly property string barPos: Theme.barPosition
    readonly property int screenGap: 6
    property int panelGap: screenGap - Theme.barThickness

    // PERF: barColor()/fmtGb() ran 2x per card + subtitle concat per tick.
    // Cache inside the card (one severity eval per card per tick).
    function fmtGb(v: real): string { return (Math.round(v * 10) / 10).toFixed(1) + "G" }
    readonly property string _ramSubtitle: fmtGb(VitalsService.ramUsedGb) + " / " + fmtGb(VitalsService.ramTotalGb) + " used"

    component MetricCard: Rectangle {
        id: card
        required property string glyph
        required property string title
        required property real pct
        required property string subtitle
        // PERF: single severity eval per card (was scope.barColor(pct) 2x per
        // card per tick + Math.round in binding).
        readonly property color _bar: {
            let s = VitalsService.severity(card.pct)
            if (s === 2) return Theme.errorColor
            if (s === 1) return Theme.tertiary
            return Theme.accent
        }
        readonly property string _pctText: Math.round(card.pct) + "%"
        width: parent ? parent.width : 300
        implicitHeight: 64
        radius: Theme.cornerRadiusSmall
        color: Theme.cardBg
        border.color: Theme.divider
        border.width: 1
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12; anchors.rightMargin: 12
            anchors.topMargin: 8; anchors.bottomMargin: 8
            spacing: 10
            Rectangle {
                Layout.preferredWidth: 42; Layout.preferredHeight: 42
                Layout.alignment: Qt.AlignVCenter
                radius: Theme.cornerRadiusSmall
                color: Theme.iconBg
                border.color: Theme.divider
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: card.glyph
                    font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(18)
                    color: Theme.textPrimary
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                        text: card.title
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: Font.Medium
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Text {
                        text: card._pctText
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: Font.Bold
                        color: card._bar
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 4
                    radius: 2
                    color: Theme.divider
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, card.pct / 100))
                        height: parent.height
                        radius: parent.radius
                        color: card._bar
                    }
                }
                Text {
                    text: card.subtitle
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10)
                    color: Theme.textSecondary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
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
            WlrLayershell.namespace: "vitals"
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
                id: vitBox
                width: 380
                implicitHeight: Math.max(200, Math.min(contentCol.implicitHeight + 36, vitAnchor.screenHeight - vitAnchor.edgeOffset - 24))
                BarAnchor {
                    id: vitAnchor
                    moduleId: "vitals"
                    barPos: scope.barPos
                    panelWidth: vitBox.width
                    panelHeight: vitBox.implicitHeight
                    screenWidth: vitBox.parent.width
                    screenHeight: vitBox.parent.height
                    gap: scope.panelGap
                    fallbackX: (vitBox.parent.width - vitBox.width) / 2
                    fallbackY: (vitBox.parent.height - vitBox.implicitHeight) / 2
                }
                x: vitAnchor.panelX
                y: vitAnchor.panelY
                radius: 0
                color: Theme.bg
                border.color: Theme.panelBorderColor
                border.width: 2
                clip: true
                PanelSpring {
                    id: vitSpring
                    slideFade: true
                    shown: scope.showVitals
                    hiddenX: scope.barPos === "left" ? -(vitBox.width + 5) : scope.barPos === "right" ? (vitBox.width + 5) : 0
                    hiddenY: scope.barPos === "top" ? -(vitBox.implicitHeight + 5) : scope.barPos === "bottom" ? (vitBox.implicitHeight + 5) : 0
                }
                visible: vitSpring.boxVisible
                opacity: vitSpring.fade
                scale: vitSpring.zoom
                transformOrigin: vitAnchor.origin
                transform: Translate { x: vitSpring.slideX; y: vitSpring.slideY }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onClicked: mouse => mouse.accepted = true
                    onPressed: mouse => mouse.accepted = true
                    onWheel: wheel => wheel.accepted = true
                }
                Flickable {
                    anchors.fill: parent
                    anchors.margins: 12
                    contentHeight: contentCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height
                    Column {
                        id: contentCol
                        width: parent.width
                        spacing: 10
                        RowLayout {
                            width: parent.width
                            spacing: 8
                            Text {
                                text: "󰻠  Vitals"
                                font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(15); font.weight: Font.Bold
                                color: Theme.textPrimary
                                Layout.fillWidth: true
                            }
                            Text {
                                visible: VitalsService.loadAvg.length > 0
                                text: "load " + VitalsService.loadAvg
                                font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11)
                                color: Theme.textSecondary
                            }
                            Rectangle {
                                Layout.preferredWidth: 32; Layout.preferredHeight: 32
                                radius: Theme.cornerRadiusSmall
                                color: refMouse.containsMouse ? Theme.bgHover : "transparent"
                                border.color: Theme.divider
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰑐"
                                    font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14)
                                    color: Theme.textSecondary
                                }
                                MouseArea { id: refMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: VitalsService.refresh() }
                            }
                        }
                        MetricCard {
                            visible: VitalsService.showCpu
                            glyph: "󰻠"; title: "CPU"
                            pct: VitalsService.cpuPct
                            subtitle: VitalsService.loadAvg.length > 0 ? "load avg " + VitalsService.loadAvg : "processor"
                        }
                        MetricCard {
                            visible: VitalsService.showRam
                            glyph: "󰍛"; title: "RAM"
                            pct: VitalsService.ramPct
                            subtitle: scope._ramSubtitle
                        }
                        MetricCard {
                            visible: VitalsService.showGpu && VitalsService.gpuAvailable
                            glyph: "󰢮"; title: "GPU"
                            pct: VitalsService.gpuPct
                            subtitle: VitalsService.gpuName.length > 0 ? VitalsService.gpuName : "graphics"
                        }
                        Column {
                            width: parent.width
                            spacing: 4
                            visible: VitalsService.showTopProcs && VitalsService.topProcs.length > 0
                            Text {
                                text: "TOP PROCESSES"
                                font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10)
                                font.weight: Font.Bold; font.letterSpacing: 0.8
                                color: Theme.textMuted
                            }
                            Repeater {
                                // PERF: hidden panel keeps zero delegates.
                                model: scope.showVitals ? VitalsService.topProcs : []
                                delegate: RowLayout {
                                    required property var modelData
                                    width: parent.width
                                    height: 22
                                    spacing: 8
                                    Text {
                                        text: (modelData.name || "?")
                                        font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12)
                                        color: Theme.textSecondary
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: (modelData.cpu || 0).toFixed(1) + "%"
                                        font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11)
                                        color: Theme.textMuted
                                    }
                                }
                            }
                        }
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignCenter
                            text: "Configure in Settings → Vitals"
                            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10)
                            color: Theme.textMuted
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
}
