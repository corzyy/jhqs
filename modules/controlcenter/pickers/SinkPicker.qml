pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../../themes"

Item {
    id: sinkPickerSlot
    required property var scope

    property real openH: sinkPickerCol.implicitHeight + 8
    Behavior on openH { NumberAnimation { duration: Theme.expanderDur; easing.type: Theme.easingStandard } }
    property real openProgress: 0
    Behavior on openProgress { NumberAnimation { duration: Theme.expanderDur; easing.type: Theme.easingStandard } }
    Layout.fillWidth: true
    implicitHeight: (openH + 24) * openProgress
    visible: openProgress > 0.02
    clip: true
    function syncExpander() {
        openProgress = (scope && scope.showSinkPicker) ? 1 : 0
    }
    Connections { target: scope; function onShowSinkPickerChanged() { sinkPickerSlot.syncExpander() } }
    property bool showOutputs: true
    onShowOutputsChanged: outputsSlot.outProgress = showOutputs ? 1 : 0
    property bool showInputs: false
    onShowInputsChanged: inputsSlot.inpProgress = showInputs ? 1 : 0

    Rectangle {
        antialiasing: Theme.shapesAa
        id: sinkPickerBox
        anchors.left: parent.left
        anchors.right: parent.right
        y: 12 * sinkPickerSlot.openProgress
        height: Math.max(0, sinkPickerSlot.height - 24 * sinkPickerSlot.openProgress)
        visible: sinkPickerSlot.openProgress > 0.02
        opacity: sinkPickerSlot.openProgress
        scale: 0.97 + 0.03 * sinkPickerSlot.openProgress
        transformOrigin: Item.Top
        transform: Translate { y: -8 * (1 - sinkPickerSlot.openProgress) }
        color: Theme.cardBg
        border.width: 0
        radius: Theme.cornerRadius
        clip: true
        Flickable {
            id: sinkFlick
            anchors.fill: parent
            anchors.margins: 4
            contentHeight: sinkPickerCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ColumnLayout {
                id: sinkPickerCol
                width: parent.width
                spacing: 4
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 8
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            text: "󰕾"
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.fs(13)
                            color: Theme.textSecondary
                            Layout.preferredWidth: 28
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            text: "Ausgabegeräte"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(9)
                            font.weight: Font.Medium
                            font.letterSpacing: 0
                            color: outputsHeaderMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                            Layout.fillWidth: true
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        }
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 18
                            radius: Math.min(9, Theme.cornerRadiusSmall)
                            color: Theme.surface2
                            border.color: Theme.divider
                            border.width: 1
                            Text {
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                anchors.centerIn: parent
                                text: scope.sinks.length + ""
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fs(9)
                                color: Theme.textSecondary
                            }
                        }
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            text: sinkPickerSlot.showOutputs ? "‹" : "›"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(12)
                            color: Theme.textSecondary
                        }
                    }
                    MouseArea {
                        id: outputsHeaderMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sinkPickerSlot.showOutputs = !sinkPickerSlot.showOutputs
                    }
                }
                Item {
                    id: outputsSlot
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    Layout.minimumHeight: 0
                    property real outProgress: 1
                    Behavior on outProgress { NumberAnimation { duration: Theme.expanderDur; easing.type: Theme.easingStandard } }
                    implicitHeight: outputsCol.implicitHeight * outProgress
                    clip: true
                    visible: outProgress > 0.02
                    ColumnLayout {
                        id: outputsCol
                        width: parent.width
                        spacing: 4
                Repeater {
                    model: scope.sinks
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool isActive: modelData.name === scope.defaultSinkName
                        Layout.fillWidth: true
                        height: 40
                        radius: Theme.cornerRadiusSmall
                        color: isActive ? Theme.bgSelected : sinkRowMouse.containsMouse ? Theme.bgHover : "transparent"
                        border.color: isActive ? Theme.divider : "transparent"
                        border.width: 1
                        scale: Theme.animationsEnabled && sinkRowMouse.containsMouse ? 1.015 : 1.0
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            spacing: 10
                            Rectangle {
                                antialiasing: Theme.shapesAa
                                width: 28
                                height: 28
                                radius: Theme.cornerRadiusSmall
                                color: isActive ? Theme.accent : Theme.iconBg
                                border.color: isActive ? Theme.accent : Theme.divider
                                border.width: 1
                                Text {
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                    anchors.centerIn: parent
                                    text: isActive ? "󰓃" : "󰕾"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fs(14)
                                    color: isActive ? Theme.onAccent : Theme.textSecondary
                                }
                            }
                            Text {
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                text: modelData.desc || modelData.name
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fs(11)
                                font.weight: Font.Medium
                                color: isActive ? Theme.textPrimary : Theme.textSecondary
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                            Text {
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                text: "󰄬"
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fs(14)
                                color: Theme.accent
                                Layout.preferredWidth: 18
                                horizontalAlignment: Text.AlignHCenter
                                opacity: isActive ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                            }
                        }
                        MouseArea {
                            id: sinkRowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: scope.switchSink(modelData.name)
                        }
                    }
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    visible: scope.sinks.length === 0
                    text: "Keine Geräte gefunden"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(11)
                    color: Theme.textSecondary
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    topPadding: 8
                    bottomPadding: 8
                }
                    }
                }
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 8
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            text: "󰍬"
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.fs(13)
                            color: Theme.textSecondary
                            Layout.preferredWidth: 28
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            text: "Eingabegeräte"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(9)
                            font.weight: Font.Medium
                            font.letterSpacing: 0
                            color: inputsHeaderMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                            Layout.fillWidth: true
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        }
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 18
                            radius: Math.min(9, Theme.cornerRadiusSmall)
                            color: Theme.surface2
                            border.color: Theme.divider
                            border.width: 1
                            Text {
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                anchors.centerIn: parent
                                text: scope.sources.length + ""
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fs(9)
                                color: Theme.textSecondary
                            }
                        }
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            text: sinkPickerSlot.showInputs ? "‹" : "›"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(12)
                            color: Theme.textSecondary
                        }
                    }
                    MouseArea {
                        id: inputsHeaderMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sinkPickerSlot.showInputs = !sinkPickerSlot.showInputs
                    }
                }
                Item {
                    id: inputsSlot
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    Layout.minimumHeight: 0
                    property real inpProgress: 0
                    Behavior on inpProgress { NumberAnimation { duration: Theme.expanderDur; easing.type: Theme.easingStandard } }
                    implicitHeight: inputsCol.implicitHeight * inpProgress
                    clip: true
                    visible: inpProgress > 0.02
                    ColumnLayout {
                        id: inputsCol
                        width: parent.width
                        spacing: 4
                Repeater {
                    model: scope.sources
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool isActive: modelData.name === scope.defaultSourceName
                        Layout.fillWidth: true
                        height: 40
                        radius: Theme.cornerRadiusSmall
                        color: isActive ? Theme.bgSelected : inputRowMouse.containsMouse ? Theme.bgHover : "transparent"
                        border.color: isActive ? Theme.divider : "transparent"
                        border.width: 1
                        scale: Theme.animationsEnabled && inputRowMouse.containsMouse ? 1.015 : 1.0
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            spacing: 10
                            Rectangle {
                                antialiasing: Theme.shapesAa
                                width: 28
                                height: 28
                                radius: Theme.cornerRadiusSmall
                                color: isActive ? Theme.accent : Theme.iconBg
                                border.color: isActive ? Theme.accent : Theme.divider
                                border.width: 1
                                Text {
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                    anchors.centerIn: parent
                                    text: "󰍬"
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: Theme.fs(14)
                                    color: isActive ? Theme.onAccent : Theme.textSecondary
                                }
                            }
                            Text {
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                text: modelData.desc || modelData.name
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fs(11)
                                font.weight: Font.Medium
                                color: isActive ? Theme.textPrimary : Theme.textSecondary
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                            Text {
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                text: "󰄬"
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fs(14)
                                color: Theme.accent
                                Layout.preferredWidth: 18
                                horizontalAlignment: Text.AlignHCenter
                                opacity: isActive ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                            }
                        }
                        MouseArea {
                            id: inputRowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: scope.switchSource(modelData.name)
                        }
                    }
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    visible: scope.sources.length === 0
                    text: "Keine Eingabegeräte gefunden"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(11)
                    color: Theme.textSecondary
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    topPadding: 8
                    bottomPadding: 8
                }
                    }
                }
            }
        }
    }
}
