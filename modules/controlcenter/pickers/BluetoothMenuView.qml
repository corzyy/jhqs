pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../../themes"

Item {
    id: btMenuSlot
    required property var scope

    property real openH: btMenuCol.implicitHeight + 8
    Behavior on openH { NumberAnimation { duration: Theme.expanderDur; easing.type: Theme.easingStandard } }
    property real openProgress: 0
    Behavior on openProgress { NumberAnimation { duration: Theme.expanderDur; easing.type: Theme.easingStandard } }
    Layout.fillWidth: true
    implicitHeight: (openH + 24) * openProgress
    visible: openProgress > 0.02
    clip: true
    function syncExpander() {
        openProgress = (scope && scope.showBluetoothMenu) ? 1 : 0
    }
    Connections { target: scope; function onShowBluetoothMenuChanged() { btMenuSlot.syncExpander() } }

    property bool showConnected: true
    onShowConnectedChanged: btConnectedSlot.connProgress = showConnected ? 1 : 0
    property bool showPaired: true
    onShowPairedChanged: btPairedSlot.pairProgress = showPaired ? 1 : 0
    property bool showAvailable: true
    onShowAvailableChanged: btAvailSlot.availProgress = showAvailable ? 1 : 0

    readonly property int connectedCount: scope.btDeviceList.filter(d => d.connected).length
    readonly property int pairedCount: scope.btDeviceList.filter(d => d.paired && !d.connected).length
    readonly property int availCount: scope.btDeviceList.filter(d => !d.paired).length

    Rectangle {
        antialiasing: Theme.shapesAa
        id: btMenuBox
        anchors.left: parent.left
        anchors.right: parent.right
        y: 12 * btMenuSlot.openProgress
        height: Math.max(0, btMenuSlot.height - 24 * btMenuSlot.openProgress)
        visible: btMenuSlot.openProgress > 0.02
        opacity: btMenuSlot.openProgress
        scale: 0.97 + 0.03 * btMenuSlot.openProgress
        transformOrigin: Item.Top
        transform: Translate { y: -8 * (1 - btMenuSlot.openProgress) }
        color: Theme.cardBg
        border.width: 0
        radius: Theme.cornerRadius
        clip: true
        Flickable {
            id: btFlick
            anchors.fill: parent
            anchors.margins: 4
            contentHeight: btMenuCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ColumnLayout {
                id: btMenuCol
                width: parent.width
                spacing: 4
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22
                    visible: btMenuSlot.connectedCount > 0
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 8
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            text: "󰂯"
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.fs(13)
                            color: Theme.textSecondary
                            Layout.preferredWidth: 28
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            text: "Verbunden"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(9)
                            font.weight: Font.Medium
                            color: btConnHeaderMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
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
                                text: btMenuSlot.connectedCount + ""
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fs(9)
                                color: Theme.textSecondary
                            }
                        }
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            text: btMenuSlot.showConnected ? "‹" : "›"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(12)
                            color: Theme.textSecondary
                        }
                    }
                    MouseArea {
                        id: btConnHeaderMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: btMenuSlot.showConnected = !btMenuSlot.showConnected
                    }
                }
                Item {
                    id: btConnectedSlot
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    Layout.minimumHeight: 0
                    property real connProgress: 1
                    Behavior on connProgress { NumberAnimation { duration: Theme.expanderDur; easing.type: Theme.easingStandard } }
                    implicitHeight: btConnectedCol.implicitHeight * connProgress
                    clip: true
                    visible: connProgress > 0.02
                    ColumnLayout {
                        id: btConnectedCol
                        width: parent.width
                        spacing: 4
                        Repeater {
                            model: scope.btDeviceList.filter(d => d.connected)
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                height: 48
                                radius: Theme.cornerRadiusSmall
                                color: Theme.bgSelected
                                border.color: Theme.divider
                                border.width: 1
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
                                        color: Theme.accent
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            anchors.centerIn: parent
                                            text: "󰂯"
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: Theme.fs(14)
                                            color: Theme.onAccent
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            text: modelData.name || modelData.mac
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fs(11)
                                            font.weight: Font.Medium
                                            color: Theme.textPrimary
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            text: modelData.mac + " • Verbunden" + (modelData.paired ? " • Gekoppelt" : "")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fs(9)
                                            color: Theme.textSecondary
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }
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
                                    }
                                    Rectangle {
                                        antialiasing: Theme.shapesAa
                                        width: 60
                                        height: 24
                                        radius: Theme.cornerRadiusSmall
                                        color: Theme.panelSurface
                                        border.color: Theme.divider
                                        border.width: 1
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            anchors.centerIn: parent
                                            text: "Trennen"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fs(10)
                                            color: Theme.textPrimary
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: scope.btDisconnect(modelData.mac)
                                        }
                                    }
                                    Rectangle {
                                        antialiasing: Theme.shapesAa
                                        width: 28
                                        height: 24
                                        radius: Theme.cornerRadiusSmall
                                        color: Theme.panelSurface
                                        border.color: Theme.divider
                                        border.width: 1
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            anchors.centerIn: parent
                                            text: "󰅖"
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: Theme.fs(12)
                                            color: Theme.textSecondary
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: scope.btRemove(modelData.mac)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22
                    visible: btMenuSlot.pairedCount > 0
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 8
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            text: "󰂱"
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.fs(13)
                            color: Theme.textSecondary
                            Layout.preferredWidth: 28
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            text: "Gekoppelt"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(9)
                            font.weight: Font.Medium
                            color: btPairHeaderMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
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
                                text: btMenuSlot.pairedCount + ""
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fs(9)
                                color: Theme.textSecondary
                            }
                        }
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            text: btMenuSlot.showPaired ? "‹" : "›"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(12)
                            color: Theme.textSecondary
                        }
                    }
                    MouseArea {
                        id: btPairHeaderMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: btMenuSlot.showPaired = !btMenuSlot.showPaired
                    }
                }
                Item {
                    id: btPairedSlot
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    Layout.minimumHeight: 0
                    property real pairProgress: 1
                    Behavior on pairProgress { NumberAnimation { duration: Theme.expanderDur; easing.type: Theme.easingStandard } }
                    implicitHeight: btPairedCol.implicitHeight * pairProgress
                    clip: true
                    visible: pairProgress > 0.02
                    ColumnLayout {
                        id: btPairedCol
                        width: parent.width
                        spacing: 4
                        Repeater {
                            model: scope.btDeviceList.filter(d => d.paired && !d.connected)
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                height: 48
                                radius: Theme.cornerRadiusSmall
                                color: btPairedHover.containsMouse ? Theme.bgHover : "transparent"
                                border.color: btPairedHover.containsMouse ? Theme.divider : "transparent"
                                border.width: 1
                                scale: Theme.animationsEnabled && btPairedHover.containsMouse ? 1.015 : 1.0
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
                                        color: Theme.iconBg
                                        border.color: Theme.divider
                                        border.width: 1
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            anchors.centerIn: parent
                                            text: "󰂱"
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: Theme.fs(14)
                                            color: Theme.textSecondary
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            text: modelData.name || modelData.mac
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fs(11)
                                            font.weight: Font.Medium
                                            color: Theme.textSecondary
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            text: modelData.mac + " • Gekoppelt"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fs(9)
                                            color: Theme.textSecondary
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }
                                    }
                                    Rectangle {
                                        antialiasing: Theme.shapesAa
                                        width: 70
                                        height: 24
                                        radius: Theme.cornerRadiusSmall
                                        color: Theme.accent
                                        border.color: Theme.accent
                                        border.width: 1
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            anchors.centerIn: parent
                                            text: "Verbinden"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fs(10)
                                            color: Theme.onAccent
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: scope.btConnect(modelData.mac)
                                        }
                                    }
                                    Rectangle {
                                        antialiasing: Theme.shapesAa
                                        width: 28
                                        height: 24
                                        radius: Theme.cornerRadiusSmall
                                        color: Theme.panelSurface
                                        border.color: Theme.divider
                                        border.width: 1
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            anchors.centerIn: parent
                                            text: "󰅖"
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: Theme.fs(12)
                                            color: Theme.textSecondary
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: scope.btRemove(modelData.mac)
                                        }
                                    }
                                }
                                MouseArea {
                                    id: btPairedHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    z: -1
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: scope.btConnect(modelData.mac)
                                }
                            }
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
                            text: "󰂲"
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.fs(13)
                            color: Theme.textSecondary
                            Layout.preferredWidth: 28
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            text: "Verfügbar"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(9)
                            font.weight: Font.Medium
                            color: btAvailHeaderMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
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
                                text: btMenuSlot.availCount + ""
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fs(9)
                                color: Theme.textSecondary
                            }
                        }
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            Layout.preferredWidth: 60
                            Layout.preferredHeight: 18
                            radius: Math.min(9, Theme.cornerRadiusSmall)
                            color: scope.btScanning ? Theme.accent : (btScanMouse.containsMouse ? Theme.bgHover : Theme.surface2)
                            border.color: scope.btScanning ? Theme.accent : Theme.divider
                            border.width: 1
                            scale: Theme.animationsEnabled && btScanMouse.containsMouse ? 1.04 : 1.0
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
                            Text {
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                anchors.centerIn: parent
                                text: scope.btScanning ? "Stop" : "Scannen"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fs(9)
                                color: scope.btScanning ? Theme.onAccent : Theme.textSecondary
                            }
                            MouseArea {
                                id: btScanMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: scope.toggleBtScanning()
                            }
                        }
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            text: btMenuSlot.showAvailable ? "‹" : "›"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(12)
                            color: Theme.textSecondary
                        }
                    }
                    MouseArea {
                        id: btAvailHeaderMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        z: -1
                        cursorShape: Qt.PointingHandCursor
                        onClicked: btMenuSlot.showAvailable = !btMenuSlot.showAvailable
                    }
                }
                Item {
                    id: btAvailSlot
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    Layout.minimumHeight: 0
                    property real availProgress: 1
                    Behavior on availProgress { NumberAnimation { duration: Theme.expanderDur; easing.type: Theme.easingStandard } }
                    implicitHeight: btAvailCol.implicitHeight * availProgress
                    clip: true
                    visible: availProgress > 0.02
                    ColumnLayout {
                        id: btAvailCol
                        width: parent.width
                        spacing: 4
                        Repeater {
                            model: scope.btDeviceList.filter(d => !d.paired)
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                height: 48
                                radius: Theme.cornerRadiusSmall
                                color: btAvailHover.containsMouse ? Theme.bgHover : "transparent"
                                border.color: btAvailHover.containsMouse ? Theme.divider : "transparent"
                                border.width: 1
                                scale: Theme.animationsEnabled && btAvailHover.containsMouse ? 1.015 : 1.0
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
                                        color: Theme.iconBg
                                        border.color: Theme.divider
                                        border.width: 1
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            anchors.centerIn: parent
                                            text: "󰂲"
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: Theme.fs(14)
                                            color: Theme.textSecondary
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            text: modelData.name || modelData.mac
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fs(11)
                                            font.weight: Font.Medium
                                            color: Theme.textSecondary
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            text: modelData.mac
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fs(9)
                                            color: Theme.textSecondary
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }
                                    }
                                    Rectangle {
                                        antialiasing: Theme.shapesAa
                                        width: 60
                                        height: 24
                                        radius: Theme.cornerRadiusSmall
                                        color: scope.btPairing ? Theme.accent : Theme.panelSurface
                                        border.color: scope.btPairing ? Theme.accent : Theme.divider
                                        border.width: 1
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            anchors.centerIn: parent
                                            text: scope.btPairing ? "…" : "Koppeln"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fs(10)
                                            color: scope.btPairing ? Theme.onAccent : Theme.textPrimary
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            z: 2
                                            enabled: !scope.btPairing
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: scope.btPair(modelData.mac)
                                        }
                                    }
                                }
                                MouseArea {
                                    id: btAvailHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    z: -1
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !scope.btPairing
                                    onClicked: scope.btPair(modelData.mac)
                                }
                            }
                        }
                    }
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    visible: scope.btDeviceList.length === 0
                    text: scope.bluetoothActive ? (scope.btScanning ? "Suche läuft..." : "Keine Geräte gefunden") : "Bluetooth ist aus"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(11)
                    color: Theme.textSecondary
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    topPadding: 8
                    bottomPadding: 8
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    visible: scope.btDeviceList.length === 0 && scope.bluetoothActive
                    text: "Geräte in Kopplungsmodus versetzen"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(9)
                    color: Theme.textSecondary
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
