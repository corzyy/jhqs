pragma ComponentBehavior: Bound
import QtQuick
import "../../../themes"
import "../../../services"
import ".."

Column {
    id: root
    width: parent ? parent.width : 400
    spacing: 10

    SettingsControls.SettingsSection {
        Grid {
            width: parent.width
            columns: 2
            spacing: 8
            Repeater {
                model: [
                    { id: "cpu", label: "CPU", icon: "󰻠" },
                    { id: "ram", label: "RAM", icon: "󰍛" },
                    { id: "gpu", label: "GPU", icon: "󰢮" },
                    { id: "top", label: "Processes", icon: "" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    readonly property string metricId: modelData.id
                    readonly property bool isAvail: metricId === "top" ? true : metricId !== "gpu" || VitalsService.gpuAvailable
                    readonly property bool isCurrent: !isAvail ? false : metricId === "cpu" ? VitalsService.showCpu : metricId === "ram" ? VitalsService.showRam : metricId === "gpu" ? VitalsService.showGpu : VitalsService.showTopProcs
                    readonly property string metricText: !isAvail ? "–" : metricId === "cpu" ? Math.round(VitalsService.cpuPct) + "%" : metricId === "ram" ? Math.round(VitalsService.ramPct) + "%" : metricId === "gpu" ? Math.round(VitalsService.gpuPct) + "%" : "" + VitalsService.topProcs.length
                    width: (parent.width - 8) / 2
                    height: 64
                    radius: Theme.cornerRadiusSmall
                    antialiasing: Theme.shapesAa
                    color: isCurrent ? Theme.withAlpha(Theme.accent, 0.16)
                        : metricMouse.containsMouse && isAvail ? (Theme.withAlpha(Theme.textPrimary, 0.08))
                        : (Theme.withAlpha(Theme.textPrimary, 0.04))
                    border.color: isCurrent ? Theme.accent : Theme.divider
                    border.width: isCurrent ? 2 : 1
                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 5
                            Text {
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                text: modelData.icon
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fs(14)
                                color: isCurrent ? Theme.textPrimary : Theme.textMuted
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                text: metricText
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fs(12)
                                font.weight: Font.Medium
                                color: isCurrent ? Theme.textPrimary : Theme.textMuted
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.fs(11)
                            font.weight: isCurrent ? Font.Medium : Font.Normal
                            color: isCurrent ? Theme.textPrimary : Theme.textSecondary
                        }
                    }
                    MouseArea {
                        id: metricMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: isAvail
                        cursorShape: isAvail ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        onClicked: {
                            if (metricId === "cpu") VitalsService.setShowCpu(!VitalsService.showCpu)
                            else if (metricId === "ram") VitalsService.setShowRam(!VitalsService.showRam)
                            else if (metricId === "gpu") { if (isAvail) VitalsService.setShowGpu(!VitalsService.showGpu) }
                            else VitalsService.setShowTopProcs(!VitalsService.showTopProcs)
                        }
                    }
                }
            }
        }
    }

    SettingsControls.SettingsSection {
        title: "Vitals"
        SettingsControls.SettingsSliderRow { label: "Refresh"; from: 1; to: 10; stepSize: 1; unit: "s"; value: VitalsService.refreshSeconds; onMoved: v => VitalsService.setRefreshSeconds(Math.round(v)); onApplied: v => VitalsService.setRefreshSeconds(Math.round(v)) }
        SettingsControls.SettingsSliderRow { label: "Warn at"; from: 10; to: 95; stepSize: 1; unit: "%"; value: VitalsService.warnThreshold; onMoved: v => VitalsService.setWarnThreshold(Math.round(v)); onApplied: v => VitalsService.setWarnThreshold(Math.round(v)) }
        SettingsControls.SettingsSliderRow { label: "Critical at"; from: 20; to: 99; stepSize: 1; unit: "%"; value: VitalsService.critThreshold; onMoved: v => VitalsService.setCritThreshold(Math.round(v)); onApplied: v => VitalsService.setCritThreshold(Math.round(v)) }
    }

}
