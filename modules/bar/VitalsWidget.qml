import QtQuick
import QtQuick.Layouts
import "../../themes"
import "../../services"

Item {
    id: root
    signal clicked()
    signal middleClicked()
    property bool vertical: false
    // Label-toggle convention (see BarModule): right-click calls this when present.
    function toggleLabel(): void { VitalsService.setShowLabels(!VitalsService.showLabels) }
    implicitWidth: vertical ? col.implicitWidth + 12 : row.implicitWidth + 16
    implicitHeight: vertical ? col.implicitHeight + 10 : row.implicitHeight + 10
    visible: VitalsService.hasVisibleMetric

    // PERF: metricColor() + Math.round()+“%” ran 9x per tick + per hover move
    // (every call re-reads severity + containsMouse). Cache per metric; hover
    // is a single overlay color.
    readonly property bool _hovered: mouse.containsMouse
    readonly property string _cpuText: Math.round(VitalsService.cpuPct) + "%"
    readonly property string _ramText: Math.round(VitalsService.ramPct) + "%"
    readonly property string _gpuText: Math.round(VitalsService.gpuPct) + "%"
    readonly property color _cpuColor: _hovered ? Theme.accent : (VitalsService.severity(VitalsService.cpuPct) === 2 ? Theme.errorColor : (VitalsService.severity(VitalsService.cpuPct) === 1 ? Theme.tertiary : Theme.textPrimary))
    readonly property color _ramColor: _hovered ? Theme.accent : (VitalsService.severity(VitalsService.ramPct) === 2 ? Theme.errorColor : (VitalsService.severity(VitalsService.ramPct) === 1 ? Theme.tertiary : Theme.textPrimary))
    readonly property color _gpuColor: _hovered ? Theme.accent : (VitalsService.severity(VitalsService.gpuPct) === 2 ? Theme.errorColor : (VitalsService.severity(VitalsService.gpuPct) === 1 ? Theme.tertiary : Theme.textPrimary))

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
                color: root._cpuColor
                Layout.alignment: Qt.AlignVCenter
            }
            Text {
                visible: VitalsService.showLabels
                text: root._cpuText
                font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: Theme.textBold ? Font.Bold : Font.Normal
                color: root._cpuColor
                Layout.alignment: Qt.AlignVCenter
            }
        }
        RowLayout {
            visible: VitalsService.showRam
            spacing: 4
            Text {
                text: "󰍛"
                font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(13)
                color: root._ramColor
                Layout.alignment: Qt.AlignVCenter
            }
            Text {
                visible: VitalsService.showLabels
                text: root._ramText
                font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: Theme.textBold ? Font.Bold : Font.Normal
                color: root._ramColor
                Layout.alignment: Qt.AlignVCenter
            }
        }
        RowLayout {
            visible: VitalsService.showGpu && VitalsService.gpuAvailable
            spacing: 4
            Text {
                text: "󰢮"
                font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(13)
                color: root._gpuColor
                Layout.alignment: Qt.AlignVCenter
            }
            Text {
                visible: VitalsService.showLabels
                text: root._gpuText
                font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: Theme.textBold ? Font.Bold : Font.Normal
                color: root._gpuColor
                Layout.alignment: Qt.AlignVCenter
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
            text: "󰻠" + (VitalsService.showLabels ? " " + root._cpuText : "")
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10)
            color: root._cpuColor
            Layout.alignment: Qt.AlignHCenter
        }
        Text {
            visible: VitalsService.showRam
            text: "󰍛" + (VitalsService.showLabels ? " " + root._ramText : "")
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10)
            color: root._ramColor
            Layout.alignment: Qt.AlignHCenter
        }
        Text {
            visible: VitalsService.showGpu && VitalsService.gpuAvailable
            text: "󰢮" + (VitalsService.showLabels ? " " + root._gpuText : "")
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10)
            color: root._gpuColor
            Layout.alignment: Qt.AlignHCenter
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) root.toggleLabel()
            else if (mouse.button === Qt.MiddleButton) { VitalsService.refresh(); root.middleClicked() }
            else root.clicked()
        }
    }
}
