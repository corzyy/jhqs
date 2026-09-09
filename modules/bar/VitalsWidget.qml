import QtQuick
import QtQuick.Layouts
import "../../themes"
import "../../services"

Item {
    id: root
    signal clicked()
    property bool vertical: false
    implicitWidth: vertical ? col.implicitWidth + 12 : row.implicitWidth + 16
    implicitHeight: vertical ? col.implicitHeight + 10 : row.implicitHeight + 10
    visible: VitalsService.hasVisibleMetric
    scale: Theme.animationsEnabled && mouse.containsMouse ? 1.06 : 1.0
    Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
    Behavior on implicitWidth { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }

    function metricColor(pct: real): color {
        let s = VitalsService.severity(pct)
        if (mouse.containsMouse) return Theme.accent
        if (s === 2) return Theme.errorColor
        if (s === 1) return Theme.tertiary
        return Theme.textPrimary
    }

    RowLayout {
        id: row
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 8
        RowLayout {
            visible: VitalsService.showCpu
            spacing: 4
            Text {
                text: "󰻠"
                font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(13)
                color: root.metricColor(VitalsService.cpuPct)
                Layout.alignment: Qt.AlignVCenter
                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            }
            Text {
                visible: VitalsService.showLabels
                text: Math.round(VitalsService.cpuPct) + "%"
                font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: Theme.textBold ? Font.Bold : Font.Normal
                color: root.metricColor(VitalsService.cpuPct)
                Layout.alignment: Qt.AlignVCenter
                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            }
        }
        RowLayout {
            visible: VitalsService.showRam
            spacing: 4
            Text {
                text: "󰍛"
                font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(13)
                color: root.metricColor(VitalsService.ramPct)
                Layout.alignment: Qt.AlignVCenter
                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            }
            Text {
                visible: VitalsService.showLabels
                text: Math.round(VitalsService.ramPct) + "%"
                font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: Theme.textBold ? Font.Bold : Font.Normal
                color: root.metricColor(VitalsService.ramPct)
                Layout.alignment: Qt.AlignVCenter
                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            }
        }
        RowLayout {
            visible: VitalsService.showGpu && VitalsService.gpuAvailable
            spacing: 4
            Text {
                text: "󰢮"
                font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(13)
                color: root.metricColor(VitalsService.gpuPct)
                Layout.alignment: Qt.AlignVCenter
                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            }
            Text {
                visible: VitalsService.showLabels
                text: Math.round(VitalsService.gpuPct) + "%"
                font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: Theme.textBold ? Font.Bold : Font.Normal
                color: root.metricColor(VitalsService.gpuPct)
                Layout.alignment: Qt.AlignVCenter
                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            }
        }
        RowLayout {
            visible: VitalsService.showDisk
            spacing: 4
            Text {
                text: "󰋊"
                font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(13)
                color: root.metricColor(VitalsService.diskPct)
                Layout.alignment: Qt.AlignVCenter
                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            }
            Text {
                visible: VitalsService.showLabels
                text: Math.round(VitalsService.diskPct) + "%"
                font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: Theme.textBold ? Font.Bold : Font.Normal
                color: root.metricColor(VitalsService.diskPct)
                Layout.alignment: Qt.AlignVCenter
                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            }
        }
    }

    ColumnLayout {
        id: col
        visible: root.vertical
        anchors.centerIn: parent
        spacing: 4
        Text {
            visible: VitalsService.showCpu
            text: "󰻠" + (VitalsService.showLabels ? " " + Math.round(VitalsService.cpuPct) + "%" : "")
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10)
            color: root.metricColor(VitalsService.cpuPct)
            Layout.alignment: Qt.AlignHCenter
        }
        Text {
            visible: VitalsService.showRam
            text: "󰍛" + (VitalsService.showLabels ? " " + Math.round(VitalsService.ramPct) + "%" : "")
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10)
            color: root.metricColor(VitalsService.ramPct)
            Layout.alignment: Qt.AlignHCenter
        }
        Text {
            visible: VitalsService.showGpu && VitalsService.gpuAvailable
            text: "󰢮" + (VitalsService.showLabels ? " " + Math.round(VitalsService.gpuPct) + "%" : "")
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10)
            color: root.metricColor(VitalsService.gpuPct)
            Layout.alignment: Qt.AlignHCenter
        }
        Text {
            visible: VitalsService.showDisk
            text: "󰋊" + (VitalsService.showLabels ? " " + Math.round(VitalsService.diskPct) + "%" : "")
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10)
            color: root.metricColor(VitalsService.diskPct)
            Layout.alignment: Qt.AlignHCenter
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
