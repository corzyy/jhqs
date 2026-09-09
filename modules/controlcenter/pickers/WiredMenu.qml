pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../../themes"

Item {
    id: wiredMenuSlot
    required property var scope

    property real openH: wiredMenuCol.implicitHeight + 8
    Behavior on openH { NumberAnimation { duration: Theme.expanderDur; easing.type: Theme.easingStandard } }
    property real openProgress: 0
    Behavior on openProgress { NumberAnimation { duration: Theme.expanderDur; easing.type: Theme.easingStandard } }
    Layout.fillWidth: true
    implicitHeight: (openH + 24) * openProgress
    visible: openProgress > 0.02
    clip: true
    function syncExpander() {
        openProgress = (scope && scope.showWiredMenu) ? 1 : 0
    }
    Connections { target: scope; function onShowWiredMenuChanged() { wiredMenuSlot.syncExpander() } }

    property bool showConnected: true
    onShowConnectedChanged: connectedSlot.connProgress = showConnected ? 1 : 0
    property bool showEthernet: true
    onShowEthernetChanged: ethernetSlot.ethProgress = showEthernet ? 1 : 0
    property bool showWifi: true
    onShowWifiChanged: wifiSlot.wifiProgress = showWifi ? 1 : 0

    readonly property int connectedCount: scope.ethernetConns.filter(c => c.active).length + scope.wifiNetworks.filter(n => n.active).length
    readonly property int ethernetCount: scope.ethernetConns.filter(c => !c.active).length
    readonly property int wifiCount: scope.wifiNetworks.filter(n => !n.active).length

    Rectangle {
        antialiasing: Theme.shapesAa
        id: wiredMenuBox
        anchors.left: parent.left
        anchors.right: parent.right
        y: 12 * wiredMenuSlot.openProgress
        height: Math.max(0, wiredMenuSlot.height - 24 * wiredMenuSlot.openProgress)
        visible: wiredMenuSlot.openProgress > 0.02
        opacity: wiredMenuSlot.openProgress
        scale: 0.97 + 0.03 * wiredMenuSlot.openProgress
        transformOrigin: Item.Top
        transform: Translate { y: -8 * (1 - wiredMenuSlot.openProgress) }
        color: Theme.cardBg
        border.width: 0
        radius: Theme.cornerRadius
        clip: true
        Flickable {
            id: wiredFlick
            anchors.fill: parent
            anchors.margins: 4
            contentHeight: wiredMenuCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ColumnLayout {
                id: wiredMenuCol
                width: parent.width
                spacing: 4
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22
                    visible: wiredMenuSlot.connectedCount > 0
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 8
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            text: "󰖩"
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
                            color: connectedHeaderMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
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
                                text: wiredMenuSlot.connectedCount + ""
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fs(9)
                                color: Theme.textSecondary
                            }
                        }
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            text: wiredMenuSlot.showConnected ? "‹" : "›"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(12)
                            color: Theme.textSecondary
                        }
                    }
                    MouseArea {
                        id: connectedHeaderMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: wiredMenuSlot.showConnected = !wiredMenuSlot.showConnected
                    }
                }
                Item {
                    id: connectedSlot
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    Layout.minimumHeight: 0
                    property real connProgress: 1
                    Behavior on connProgress { NumberAnimation { duration: Theme.expanderDur; easing.type: Theme.easingStandard } }
                    implicitHeight: connectedCol.implicitHeight * connProgress
                    clip: true
                    visible: connProgress > 0.02
                    ColumnLayout {
                        id: connectedCol
                        width: parent.width
                        spacing: 4
                        Repeater {
                            model: scope.ethernetConns.filter(c => c.active)
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
                                            text: "󰈀"
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
                                            text: modelData.name || modelData.device
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
                                            text: (modelData.device ? modelData.device + " • " : "") + "Verbunden" + (modelData.state ? " • " + modelData.state : "")
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
                                            onClicked: scope.ethDisconnect(modelData.name)
                                        }
                                    }
                                }
                            }
                        }
                        Repeater {
                            model: scope.wifiNetworks.filter(n => n.active)
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
                                            text: "󰤨"
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
                                            text: modelData.ssid
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
                                            text: modelData.signal + "% • " + modelData.security + " • Verbunden"
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
                                            onClicked: scope.wifiDisconnect(modelData.ssid)
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
                    visible: wiredMenuSlot.ethernetCount > 0
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 8
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            text: "󰈀"
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.fs(13)
                            color: Theme.textSecondary
                            Layout.preferredWidth: 28
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            text: "Ethernet"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(9)
                            font.weight: Font.Medium
                            color: ethernetHeaderMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
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
                                text: wiredMenuSlot.ethernetCount + ""
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fs(9)
                                color: Theme.textSecondary
                            }
                        }
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            text: wiredMenuSlot.showEthernet ? "‹" : "›"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(12)
                            color: Theme.textSecondary
                        }
                    }
                    MouseArea {
                        id: ethernetHeaderMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: wiredMenuSlot.showEthernet = !wiredMenuSlot.showEthernet
                    }
                }
                Item {
                    id: ethernetSlot
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    Layout.minimumHeight: 0
                    property real ethProgress: 1
                    Behavior on ethProgress { NumberAnimation { duration: Theme.expanderDur; easing.type: Theme.easingStandard } }
                    implicitHeight: ethernetCol.implicitHeight * ethProgress
                    clip: true
                    visible: ethProgress > 0.02
                    ColumnLayout {
                        id: ethernetCol
                        width: parent.width
                        spacing: 4
                        Repeater {
                            model: scope.ethernetConns.filter(c => !c.active)
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                height: 48
                                radius: Theme.cornerRadiusSmall
                                color: ethAvailHover.containsMouse ? Theme.bgHover : "transparent"
                                border.color: ethAvailHover.containsMouse ? Theme.divider : "transparent"
                                border.width: 1
                                scale: Theme.animationsEnabled && ethAvailHover.containsMouse ? 1.015 : 1.0
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
                                            text: "󰈂"
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
                                            text: modelData.name
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
                                            text: (modelData.device ? modelData.device + " • " : "") + modelData.state
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
                                            onClicked: scope.ethConnect(modelData.name)
                                        }
                                    }
                                }
                                MouseArea {
                                    id: ethAvailHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    z: -1
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: scope.ethConnect(modelData.name)
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
                            text: "󰤨"
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.fs(13)
                            color: Theme.textSecondary
                            Layout.preferredWidth: 28
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            id: wifiHeaderLabel
                            text: "Wi-Fi"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(9)
                            font.weight: Font.Medium
                            color: wifiHeaderMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
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
                                text: wiredMenuSlot.wifiCount + ""
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
                            color: scope.wifiScanning ? Theme.accent : (wifiScanMouse.containsMouse ? Theme.bgHover : Theme.surface2)
                            border.color: scope.wifiScanning ? Theme.accent : Theme.divider
                            border.width: 1
                            scale: Theme.animationsEnabled && wifiScanMouse.containsMouse ? 1.04 : 1.0
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
                            Text {
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                anchors.centerIn: parent
                                text: scope.wifiScanning ? "Stop" : "Scannen"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fs(9)
                                color: scope.wifiScanning ? Theme.onAccent : Theme.textSecondary
                            }
                            MouseArea {
                                id: wifiScanMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: scope.toggleWifiScanning()
                            }
                        }
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            text: wiredMenuSlot.showWifi ? "‹" : "›"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(12)
                            color: Theme.textSecondary
                        }
                    }
                    MouseArea {
                        id: wifiHeaderMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        z: -1
                        cursorShape: Qt.PointingHandCursor
                        onClicked: wiredMenuSlot.showWifi = !wiredMenuSlot.showWifi
                    }
                }
                Item {
                    id: wifiSlot
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    Layout.minimumHeight: 0
                    property real wifiProgress: 1
                    Behavior on wifiProgress { NumberAnimation { duration: Theme.expanderDur; easing.type: Theme.easingStandard } }
                    implicitHeight: wifiCol.implicitHeight * wifiProgress
                    clip: true
                    visible: wifiProgress > 0.02
                    ColumnLayout {
                        id: wifiCol
                        width: parent.width
                        spacing: 4
                        Repeater {
                            model: scope.wifiNetworks.filter(n => !n.active)
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                height: 48
                                radius: Theme.cornerRadiusSmall
                                color: wifiAvailHover.containsMouse ? Theme.bgHover : "transparent"
                                border.color: wifiAvailHover.containsMouse ? Theme.divider : "transparent"
                                border.width: 1
                                scale: Theme.animationsEnabled && wifiAvailHover.containsMouse ? 1.015 : 1.0
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
                                            text: modelData.signal > 70 ? "󰤨" : modelData.signal > 40 ? "󰤥" : "󰤢"
                                            font.family: Theme.fontFamily
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
                                            text: modelData.ssid
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
                                            text: modelData.signal + "% • " + modelData.security
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
                                            onClicked: scope.wifiConnect(modelData.ssid)
                                        }
                                    }
                                }
                                MouseArea {
                                    id: wifiAvailHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    z: -1
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: scope.wifiConnect(modelData.ssid)
                                }
                            }
                        }
                    }
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    visible: scope.wifiNetworks.length === 0 && scope.ethernetConns.filter(c => c.active).length === 0 && scope.ethernetConns.filter(c => !c.active).length === 0
                    text: scope.wifiScanning ? "Suche läuft..." : "Keine Netzwerke gefunden"
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
                    visible: scope.wifiNetworks.length === 0 && scope.wifiScanning === false && scope.ethernetConns.length > 0
                    text: "Keine WLANs — Ethernet verbunden"
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
