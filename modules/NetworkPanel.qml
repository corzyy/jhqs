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
    property bool showNetwork: false
    signal dismissed()
    property bool _winVisible: showNetwork
    Timer { id: hideTimer; interval: Theme.panelAnimExit + 20; repeat: false; onTriggered: if (!scope.showNetwork) scope._winVisible = false }
    onShowNetworkChanged: {
        if (showNetwork) {
            _winVisible = true
            hideTimer.stop()
            NetworkService.refreshLink()
            NetworkService.refreshLists()
            NetworkService.refreshStats()
            NetworkService.refreshDns()
            NetworkService.rescan()
        } else hideTimer.restart()
    }
    readonly property string barPos: Theme.barPosition
    readonly property int screenGap: 6
    property int panelGap: screenGap - Theme.barThickness
    readonly property bool isMinimal: Theme.minimalTheme

    Timer { id: statsTimer; interval: 5000; running: scope.showNetwork; repeat: true; triggeredOnStart: false; onTriggered: NetworkService.refreshStats() }
    Timer { id: listTimer; interval: 10000; running: scope.showNetwork; repeat: true; triggeredOnStart: false; onTriggered: { NetworkService.refreshLink(); NetworkService.refreshLists(); NetworkService.refreshDns() } }

    property string pwSsid: ""
    property string busySsid: ""
    Timer { id: busyTimer; interval: 6000; repeat: false; onTriggered: scope.busySsid = "" }

    readonly property string heroTitle: {
        if (!NetworkService.netActive) return "Disconnected"
        if (NetworkService.activeType === "ethernet") return NetworkService.ssid !== "" ? NetworkService.ssid : "Ethernet"
        if (NetworkService.activeType === "wifi") return NetworkService.ssid !== "" ? NetworkService.ssid : "Wi-Fi"
        return "No connection"
    }
    readonly property string heroMeta: {
        if (!NetworkService.wifiEnabled && NetworkService.activeType !== "ethernet") return "WIFI OFF"
        if (!NetworkService.netActive) return "NOT CONNECTED"
        if (NetworkService.activeType === "wifi") return "SIGNAL " + NetworkService.signal + "%"
        if (NetworkService.activeType === "ethernet") return "WIRED"
        return ""
    }
    readonly property bool dnsVisible: NetworkService.netActive && NetworkService.activeConnUuid !== ""
    readonly property string dnsHeader: NetworkService.dnsBusy ? "DNS — APPLYING…" : "DNS"

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
    component DnsPill: Rectangle {
        id: dnsPill
        required property string label
        required property string sub
        required property string mode
        readonly property bool active: NetworkService.dnsMode === mode
        Layout.fillWidth: true
        implicitHeight: 40
        enabled: !NetworkService.dnsBusy
        antialiasing: Theme.shapesAa
        radius: 0
        color: active ? Theme.withAlpha(Theme.accent, 0.16) : Theme.withAlpha(Theme.textPrimary, 0.04)
        border.color: active ? Theme.accent : Theme.withAlpha(Theme.textPrimary, 0.25)
        border.width: active ? 2 : 1
        opacity: enabled ? 1 : 0.55
        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
        Column {
            anchors.centerIn: parent
            spacing: 0
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: dnsPill.label
                color: Theme.textPrimary
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fs(12)
                font.weight: Font.Bold
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: dnsPill.sub
                color: Theme.textSecondary
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fs(10)
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: dnsPill.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (dnsPill.enabled) NetworkService.setDnsPreset(dnsPill.mode)
        }
    }
    component WifiRow: Column {
        id: wifiCol
        required property var net
        spacing: 0
        Rectangle {
            antialiasing: Theme.shapesAa
            width: wifiCol.width
            implicitHeight: 48
            color: wifiMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.08) : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            Row {
                anchors.fill: parent
                anchors.leftMargin: 10; anchors.rightMargin: 10
                spacing: 10
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    text: NetworkService.wifiIconFor(wifiCol.net.signal)
                    color: wifiCol.net.active ? Theme.textPrimary : Theme.textSecondary
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fs(16)
                    width: 22
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenter: parent.verticalCenter
                }
                Column {
                    width: parent.width - 22 - 10 - 22 - 8 - 20
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        width: parent.width
                        text: wifiCol.net.ssid
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
                            if (scope.busySsid === wifiCol.net.ssid) return "Connecting…"
                            if (wifiCol.net.active) return "Connected"
                            return ""
                        }
                        color: Theme.textPrimary
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.fs(11)
                        elide: Text.ElideRight
                    }
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    visible: secured || (forgetHover.containsMouse && !wifiCol.net.active)
                    readonly property bool secured: wifiCol.net.security !== "--" && wifiCol.net.security !== ""
                    text: (forgetHover.containsMouse && !wifiCol.net.active) ? "󰅙" : ""
                    color: (forgetHover.containsMouse && !wifiCol.net.active) ? Theme.errorColor : Theme.textSecondary
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fs(13)
                    width: 22
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                    MouseArea {
                        id: forgetHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => { mouse.accepted = true; NetworkService.forgetWifi(wifiCol.net.ssid) }
                    }
                }
            }
            MouseArea {
                id: wifiMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    let n = wifiCol.net
                    if (n.active) { NetworkService.disconnectWifi(); return }
                    let secured = n.security !== "--" && n.security !== ""
                    if (secured) scope.pwSsid = (scope.pwSsid === n.ssid) ? "" : n.ssid
                    else { scope.busySsid = n.ssid; scope.busyTimer.restart(); NetworkService.connectWifi(n.ssid, "") }
                }
            }
        }
        Rectangle {
            visible: scope.pwSsid === wifiCol.net.ssid
            width: wifiCol.width
            height: visible ? 40 : 0
            clip: true
            color: "transparent"
            Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            Row {
                anchors.fill: parent
                anchors.leftMargin: 42; anchors.rightMargin: 10
                spacing: 8
                TextInput {
                    id: pwField
                    width: parent.width - 80
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    color: Theme.textPrimary
                    selectionColor: Theme.accent
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fs(12)
                    passwordCharacter: "•"
                    echoMode: TextInput.Password
                    onAccepted: {
                        scope.busySsid = wifiCol.net.ssid
                        scope.busyTimer.restart()
                        scope.pwSsid = ""
                        NetworkService.connectWifi(wifiCol.net.ssid, text)
                    }
                    Component.onCompleted: if (scope.pwSsid === wifiCol.net.ssid) forceActiveFocus()
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Connect"
                    color: pwGoMouse.containsMouse ? Theme.accent : Theme.textSecondary
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fs(12)
                    font.weight: Font.Bold
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    MouseArea {
                        id: pwGoMouse
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pwField.accepted()
                    }
                }
            }
        }
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
            WlrLayershell.namespace: "networkpanel"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        if (scope.pwSsid !== "") scope.pwSsid = ""
                        else scope.dismissed()
                        event.accepted = true
                    }
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
                id: netBox
                width: 380
                implicitHeight: Math.max(120, Math.min(contentCol.implicitHeight + 36, netAnchor.screenHeight - netAnchor.edgeOffset - 24))
                BarAnchor {
                    id: netAnchor
                    moduleId: "network"
                    barPos: scope.barPos
                    panelWidth: netBox.width
                    panelHeight: netBox.implicitHeight
                    screenWidth: netBox.parent.width
                    screenHeight: netBox.parent.height
                    gap: scope.panelGap
                    fallbackX: (netBox.parent.width - netBox.width) / 2
                    fallbackY: (netBox.parent.height - netBox.implicitHeight) / 2
                }
                x: netAnchor.panelX
                y: netAnchor.panelY
                Behavior on x { enabled: netAnchor.valid && netBox.width > 0 && netBox.implicitHeight > 0 && netSpring.offset === 0; NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingSmooth } }
                Behavior on y { enabled: netAnchor.valid && netBox.width > 0 && netBox.implicitHeight > 0 && netSpring.offset === 0; NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingSmooth } }
                color: scope.isMinimal ? Theme.bg : Theme.panelBg
                border.color: scope.isMinimal ? Theme.accent : Theme.panelBorderColor
                border.width: scope.isMinimal ? 2 : 1
                radius: scope.isMinimal ? 0 : Theme.cornerRadius
                clip: true
                Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingSmooth } }
                PanelSpring {
                    id: netSpring
                    slideFade: true
                    shown: scope.showNetwork
                    hiddenX: scope.barPos === "left" ? -(netBox.width + 5) : scope.barPos === "right" ? (netBox.width + 5) : 0
                    hiddenY: scope.barPos === "top" ? -(netBox.implicitHeight + 5) : scope.barPos === "bottom" ? (netBox.implicitHeight + 5) : 0
                }
                visible: netSpring.boxVisible
                opacity: netSpring.fade
                scale: netSpring.zoom
                transformOrigin: netAnchor.origin
                transform: Translate { x: netSpring.slideX; y: netSpring.slideY }
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
                        spacing: 12
                    Item {
                        width: parent.width
                        implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, wifiSwitch.implicitHeight)
                        Text {
                            id: heroIcon
                            text: NetworkService.icon
                            color: NetworkService.netActive ? Theme.textPrimary : Theme.textMuted
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.fs(24)
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }
                        OmSwitch {
                            id: wifiSwitch
                            checked: NetworkService.wifiEnabled
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: NetworkService.toggleWifi()
                        }
                        Column {
                            id: heroLabels
                            anchors.left: heroIcon.right
                            anchors.leftMargin: 14
                            anchors.right: parent.right
                            anchors.rightMargin: wifiSwitch.width + 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                width: parent.width
                                text: scope.heroTitle
                                color: Theme.textPrimary
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fs(16)
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                            Text {
                                visible: text !== ""
                                width: parent.width
                                text: scope.heroMeta
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
                    GridLayout {
                        visible: NetworkService.netActive
                        width: parent.width
                        columns: 4
                        columnSpacing: 20
                        rowSpacing: 4
                        Repeater {
                            model: [
                                { label: "IP Address", value: NetworkService.ipAddr !== "" ? NetworkService.ipAddr : "--" },
                                { label: "Gateway", value: NetworkService.gateway !== "" ? NetworkService.gateway : "--" },
                                { label: "Received", value: NetworkService.rxBytes },
                                { label: "Sent", value: NetworkService.txBytes },
                                { label: "Ping", value: NetworkService.pingMs !== "" ? NetworkService.pingMs : "--" },
                                { label: "Signal", value: NetworkService.activeType === "wifi" ? NetworkService.signal + "%" : (NetworkService.activeType === "ethernet" ? "Wired" : "--") }
                            ]
                            delegate: Column {
                                required property var modelData
                                spacing: 1
                                Layout.fillWidth: true
                                Text {
                                    text: modelData.label
                                    color: Theme.textSecondary
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: Theme.fs(10)
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                                Text {
                                    text: modelData.value
                                    color: Theme.textPrimary
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: Theme.fs(12)
                                    elide: Text.ElideRight
                                    width: parent.width
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                            }
                        }
                    }
                    Hairline { visible: scope.dnsVisible; width: parent.width }
                    Column {
                        visible: scope.dnsVisible
                        width: parent.width
                        spacing: 10
                        SectionHeader { text: scope.dnsHeader }
                        RowLayout {
                            width: parent.width
                            spacing: 8
                            DnsPill { label: "Auto"; sub: "DHCP"; mode: "auto" }
                            DnsPill { label: "Cloudflare"; sub: "1.1.1.1"; mode: "cloudflare" }
                            DnsPill { label: "Google"; sub: "8.8.8.8"; mode: "google" }
                        }
                        Text {
                            visible: NetworkService.dnsMode === "custom"
                            width: parent.width
                            text: "Custom DNS set externally — pick a pill to override"
                            color: Theme.textMuted
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.fs(10)
                            wrapMode: Text.WordWrap
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }
                    }
                    Hairline { visible: NetworkService.ethernetConns.length > 0; width: parent.width }
                    Column {
                        visible: NetworkService.ethernetConns.length > 0
                        width: parent.width
                        spacing: 10
                        SectionHeader { text: "ETHERNET" }
                        Repeater {
                            model: NetworkService.ethernetConns
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: parent.width
                                implicitHeight: 48
                                color: ethMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.08) : "transparent"
                                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                                antialiasing: Theme.shapesAa
                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10; anchors.rightMargin: 10
                                    spacing: 10
                                    Text {
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                        text: "󰈀"
                                        color: modelData.active ? Theme.textPrimary : Theme.textSecondary
                                        font.family: Theme.iconFontFamily
                                        font.pixelSize: Theme.fs(16)
                                        width: 22
                                        horizontalAlignment: Text.AlignHCenter
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Column {
                                        width: parent.width - 22 - 10 - 20
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 1
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            width: parent.width
                                            text: modelData.name
                                            color: Theme.textPrimary
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: Theme.fs(12)
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            visible: modelData.active
                                            width: parent.width
                                            text: "Connected"
                                            color: Theme.textPrimary
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: Theme.fs(11)
                                        }
                                    }
                                }
                                MouseArea {
                                    id: ethMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.active) NetworkService.ethDisconnect(modelData.name)
                                        else NetworkService.ethConnect(modelData.name)
                                    }
                                }
                            }
                        }
                    }
                    Hairline { visible: NetworkService.wifiEnabled; width: parent.width }
                    Column {
                        visible: NetworkService.wifiEnabled
                        width: parent.width
                        spacing: 10
                        Row {
                            width: parent.width
                            spacing: 8
                            SectionHeader {
                                text: NetworkService.wifiNetworks.length > 0 ? "KNOWN NETWORKS" : "WI-FI"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Item { width: 1; height: 1; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "↻"
                                color: rescanMouse.containsMouse ? Theme.accent : Theme.textSecondary
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fs(13)
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                                MouseArea {
                                    id: rescanMouse
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: NetworkService.rescan()
                                }
                            }
                        }
                        Repeater {
                            model: NetworkService.wifiNetworks
                            delegate: WifiRow {
                                required property var modelData
                                required property int index
                                net: modelData
                                width: parent.width
                            }
                        }
                        Text {
                            visible: NetworkService.wifiNetworks.length === 0
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "No networks found"
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
