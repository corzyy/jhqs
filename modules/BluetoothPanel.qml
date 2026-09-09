pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../themes"
import "../services"
import "../Ui"

Scope {
    id: scope
    property bool showBluetooth: false
    signal dismissed()
    property bool _winVisible: showBluetooth
    Timer { id: hideTimer; interval: Theme.panelAnimExit + 20; repeat: false; onTriggered: if (!scope.showBluetooth) scope._winVisible = false }
    onShowBluetoothChanged: {
        if (showBluetooth) {
            _winVisible = true
            hideTimer.stop()
            BluetoothService.refreshPower()
            BluetoothService.refreshDevices()
            BluetoothService.setScanning(true)
        } else {
            hideTimer.restart()
            BluetoothService.setScanning(false)
        }
    }
    readonly property string barPos: Theme.barPosition
    readonly property int screenGap: 6
    property int panelGap: screenGap - Theme.barThickness
    readonly property bool isMinimal: Theme.minimalTheme

    Timer {
        id: devTimer
        interval: 8000
        running: scope.showBluetooth
        repeat: true
        triggeredOnStart: false
        onTriggered: { BluetoothService.refreshDevices(); BluetoothService.refreshPower() }
    }

    component SectionHeader: Text {
        antialiasing: Theme.textAa
        renderType: Theme.textRenderType
        color: Theme.textSecondary
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.fs(10)
        font.weight: Font.Bold
    }
    component Hairline: Rectangle {
        antialiasing: Theme.shapesAa
        color: Theme.withAlpha(Theme.textPrimary, 0.12)
        height: 1
    }
    component OmSwitch: Item {
        id: swRoot
        property bool checked: false
        signal toggled()
        implicitWidth: 42
        implicitHeight: 22
        Rectangle {
            anchors.centerIn: parent
            width: 42; height: 22
            radius: 0
            color: swRoot.checked ? Theme.withAlpha(Theme.textPrimary, 0.18) : Theme.withAlpha(Theme.textPrimary, 0.04)
            border.color: swRoot.checked ? "transparent" : Theme.withAlpha(Theme.textPrimary, 0.4)
            border.width: swRoot.checked ? 0 : 1
            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            Rectangle {
                width: 16; height: 16
                radius: 0
                x: swRoot.checked ? parent.width - width - 3 : 3
                anchors.verticalCenter: parent.verticalCenter
                color: swRoot.checked ? Theme.textPrimary : Theme.textSecondary
                Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: swRoot.toggled()
        }
    }
    component DeviceRow: Rectangle {
        id: rowRect
        required property var dev
        required property string section
        antialiasing: Theme.shapesAa
        color: rowMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.08) : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
        Row {
            anchors.fill: parent
            anchors.leftMargin: 10; anchors.rightMargin: 10
            spacing: 10
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                text: rowRect.dev && rowRect.dev.connected ? "󰂱" : "󰂯"
                color: rowRect.dev && rowRect.dev.connected ? Theme.textPrimary : Theme.textSecondary
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fs(16)
                width: 22
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenter: parent.verticalCenter
            }
            Column {
                width: parent.width - 22 - 10 - (forgetBox.visible ? 22 + 8 : 0) - 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    width: parent.width
                    text: (rowRect.dev && rowRect.dev.name) || "Device"
                    color: Theme.textPrimary
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fs(12)
                    elide: Text.ElideRight
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    visible: text !== ""
                    width: parent.width
                    text: {
                        if (!rowRect.dev) return ""
                        if (rowRect.dev.connected) return rowRect.section === "connected" ? "" : "Connected"
                        if (!rowRect.dev.paired) return ""
                        return ""
                    }
                    color: Theme.textPrimary
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fs(11)
                    elide: Text.ElideRight
                }
            }
            Item {
                id: forgetBox
                visible: rowRect.dev && (rowRect.dev.paired || rowRect.dev.connected) && rowMouse.containsMouse
                width: 22; height: 22
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.centerIn: parent
                    text: "󰅙"
                    color: Theme.errorColor
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fs(13)
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => { mouse.accepted = true; BluetoothService.btRemove(rowRect.dev.mac) }
                }
            }
        }
        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!rowRect.dev) return
                if (rowRect.dev.connected) BluetoothService.btDisconnect(rowRect.dev.mac)
                else if (!rowRect.dev.paired) BluetoothService.btPair(rowRect.dev.mac)
                else BluetoothService.btConnect(rowRect.dev.mac)
            }
        }
    }

    property var connectedDevs: {
        let out = []
        try {
            for (let d of BluetoothService.btDevices) { if (d && d.connected) out.push(d) }
        } catch (e) {}
        return out
    }
    property var pairedDevs: {
        let out = []
        try {
            for (let d of BluetoothService.btDevices) { if (d && d.paired && !d.connected) out.push(d) }
        } catch (e) {}
        return out
    }
    property var availDevs: {
        let out = []
        try {
            for (let d of BluetoothService.btDevices) { if (d && !d.paired && !d.connected) out.push(d) }
        } catch (e) {}
        return out
    }
    readonly property string heroStatus: {
        if (!BluetoothService.btActive) return "TURNED OFF"
        if (scope.connectedDevs.length > 0) return "CONNECTED"
        if (BluetoothService.btScanning) return "SCANNING…"
        return "ON"
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: scope._winVisible && modelData.name === "DP-1"
            color: "transparent"
            exclusiveZone: 0
            anchors { top: true; left: true; right: true; bottom: true }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "bluetoothpanel"
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
                antialiasing: Theme.shapesAa
                id: btBox
                width: 380
                implicitHeight: Math.max(120, Math.min(contentCol.implicitHeight + 36, btAnchor.screenHeight - btAnchor.edgeOffset - 24))
                BarAnchor {
                    id: btAnchor
                    moduleId: "bluetooth"
                    barPos: scope.barPos
                    panelWidth: btBox.width
                    panelHeight: btBox.implicitHeight
                    screenWidth: btBox.parent.width
                    screenHeight: btBox.parent.height
                    gap: scope.panelGap
                    fallbackX: (btBox.parent.width - btBox.width) / 2
                    fallbackY: (btBox.parent.height - btBox.implicitHeight) / 2
                }
                x: btAnchor.panelX
                y: btAnchor.panelY
                Behavior on x { enabled: btAnchor.valid && btBox.width > 0 && btBox.implicitHeight > 0 && btSpring.offset === 0; NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingSmooth } }
                Behavior on y { enabled: btAnchor.valid && btBox.width > 0 && btBox.implicitHeight > 0 && btSpring.offset === 0; NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingSmooth } }
                color: scope.isMinimal ? Theme.bg : Theme.panelBg
                border.color: scope.isMinimal ? Theme.accent : Theme.panelBorderColor
                border.width: scope.isMinimal ? 2 : 1
                radius: scope.isMinimal ? 0 : Theme.cornerRadius
                clip: true
                Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingSmooth } }
                PanelSpring {
                    id: btSpring
                    slideFade: true
                    shown: scope.showBluetooth
                    hiddenX: scope.barPos === "left" ? -(btBox.width + 5) : scope.barPos === "right" ? (btBox.width + 5) : 0
                    hiddenY: scope.barPos === "top" ? -(btBox.implicitHeight + 5) : scope.barPos === "bottom" ? (btBox.implicitHeight + 5) : 0
                }
                visible: btSpring.boxVisible
                opacity: btSpring.fade
                scale: btSpring.zoom
                transformOrigin: btAnchor.origin
                transform: Translate { x: btSpring.slideX; y: btSpring.slideY }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onClicked: mouse => mouse.accepted = true
                    onPressed: mouse => mouse.accepted = true
                    onWheel: wheel => wheel.accepted = true
                }
                Flickable {
                    anchors.fill: parent
                    anchors.margins: 18
                    contentHeight: contentCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height
                    Column {
                        id: contentCol
                        width: parent.width
                        spacing: 14
                    Item {
                        width: parent.width
                        implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, powerSwitch.implicitHeight)
                        Text {
                            id: heroIcon
                            text: BluetoothService.icon
                            color: Theme.textPrimary
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.fs(24)
                            opacity: BluetoothService.btActive ? 1.0 : 0.5
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }
                        OmSwitch {
                            id: powerSwitch
                            checked: BluetoothService.btActive
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: BluetoothService.togglePower()
                        }
                        Column {
                            id: heroLabels
                            anchors.left: heroIcon.right
                            anchors.leftMargin: 14
                            anchors.right: parent.right
                            anchors.rightMargin: powerSwitch.width + 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                width: parent.width
                                text: "Bluetooth"
                                color: Theme.textPrimary
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fs(16)
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                            Text {
                                width: parent.width
                                text: scope.heroStatus
                                color: Theme.textSecondary
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fs(10)
                                font.weight: Font.Bold
                                font.letterSpacing: 1.2
                                elide: Text.ElideRight
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                        }
                    }
                    Hairline { width: parent.width }
                    Column {
                        visible: scope.connectedDevs.length > 0
                        width: parent.width
                        spacing: 10
                        SectionHeader { text: "CONNECTED" }
                        Repeater {
                            model: scope.connectedDevs
                            delegate: DeviceRow {
                                required property var modelData
                                required property int index
                                dev: modelData
                                section: "connected"
                                width: parent.width
                                implicitHeight: 48
                            }
                        }
                    }
                    Hairline { visible: scope.connectedDevs.length > 0 && (scope.pairedDevs.length > 0 || scope.availDevs.length > 0); width: parent.width }
                    Flickable {
                        width: parent.width
                        height: Math.min(listCol.implicitHeight, 400)
                        contentHeight: listCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        Column {
                            id: listCol
                            width: parent.width
                            spacing: 10
                            SectionHeader { visible: scope.pairedDevs.length > 0; text: "PAIRED" }
                            Repeater {
                                model: scope.pairedDevs
                                delegate: DeviceRow {
                                    required property var modelData
                                    required property int index
                                    dev: modelData
                                    section: "paired"
                                    width: listCol.width
                                    implicitHeight: 48
                                }
                            }
                            SectionHeader { visible: scope.availDevs.length > 0; text: "AVAILABLE" }
                            Repeater {
                                model: scope.availDevs
                                delegate: DeviceRow {
                                    required property var modelData
                                    required property int index
                                    dev: modelData
                                    section: "available"
                                    width: listCol.width
                                    implicitHeight: 48
                                }
                            }
                            Text {
                                visible: scope.pairedDevs.length === 0 && scope.availDevs.length === 0
                                width: listCol.width
                                horizontalAlignment: Text.AlignHCenter
                                text: !BluetoothService.btActive ? "Turn Bluetooth on to scan" : (BluetoothService.btScanning ? "Scanning…" : "No devices found")
                                color: Theme.textMuted
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fs(11)
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                        }
                    }
                }
            }
        }
    }
}

}
