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
    property bool showNetwork: false
    signal dismissed()
    property bool _winVisible: showNetwork
    Timer { id: hideTimer; interval: Theme.panelHideDelay; repeat: false; onTriggered: if (!scope.showNetwork) scope._winVisible = false }
    onShowNetworkChanged: {
        if (showNetwork) {
            _winVisible = true
            hideTimer.stop()
            // PERF: stagger 5 proc spawns (was synchronous jank on open).
            staggerRefresh(0)
        } else hideTimer.restart()
    }
    // PERF: stagger link/lists/stats/dns/rescan 120ms apart so opening the
    // panel doesn't fork 5x nmcli at once on the GUI thread's event loop.
    Timer {
        id: staggerTimer
        interval: 120; repeat: false
        property int step: 0
        onTriggered: staggerRefresh(step)
    }
    function staggerRefresh(step: int): void {
        staggerTimer.step = step
        if (step === 0) { NetworkService.refreshLink(); staggerTimer.step = 1; staggerTimer.restart() }
        else if (step === 1) { NetworkService.refreshLists(); staggerTimer.step = 2; staggerTimer.restart() }
        else if (step === 2) { NetworkService.refreshStats(); staggerTimer.step = 3; staggerTimer.restart() }
        else if (step === 3) { NetworkService.refreshDns(); staggerTimer.step = 4; staggerTimer.restart() }
        else if (step === 4) { NetworkService.rescan() }
    }
    readonly property string barPos: Theme.barPosition
    // Attached-bar morph: tuck under the bar edge (see Theme.panelAttachOverlap)
    // instead of floating detached below it.
    property int panelGap: -(Theme.barThickness + Theme.panelAttachOverlap)

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
    readonly property string statusText: {
        if (!NetworkService.wifiEnabled && NetworkService.activeType !== "ethernet") return "OFF"
        if (!NetworkService.netActive) return "OFFLINE"
        if (NetworkService.activeType === "wifi") return NetworkService.signal + "%"
        return "WIRED"
    }
    readonly property bool statusOk: NetworkService.netActive
    readonly property bool dnsVisible: NetworkService.netActive && NetworkService.activeConnUuid !== ""
    readonly property string dnsHeader: NetworkService.dnsBusy ? "DNS — APPLYING…" : "DNS"
    function wifiIcon(sig: int): string {
        if (sig >= 75) return "󰤨"
        if (sig >= 55) return "󰤥"
        if (sig >= 35) return "󰤢"
        if (sig > 0) return "󰤟"
        return "󰤯"
    }

    component DnsPill: Rectangle {
        id: dnsPill
        required property string label
        required property string sub
        required property string mode
        readonly property bool active: NetworkService.dnsMode === mode
        Layout.fillWidth: true
        implicitHeight: 42
        enabled: !NetworkService.dnsBusy
        antialiasing: Theme.shapesAa
        radius: Theme.cornerRadiusSmall
        color: active ? Theme.withAlpha(Theme.accent, 0.14) : Theme.withAlpha(Theme.textPrimary, 0.04)
        border.color: active ? Theme.withAlpha(Theme.accent, 0.55) : Theme.divider
        border.width: 1
        opacity: enabled ? 1 : 0.55
        Column {
            anchors.centerIn: parent
            spacing: 1
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: dnsPill.label
                color: dnsPill.active ? Theme.textPrimary : Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(12)
                font.weight: Font.DemiBold
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: dnsPill.sub
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(10)
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
        }
        StateLayer {
            disabled: NetworkService.dnsBusy
            radius: Theme.cornerRadiusSmall
            color: Theme.textPrimary
            onClicked: if (dnsPill.enabled) NetworkService.setDnsPreset(dnsPill.mode)
        }
    }
    component WifiRow: Column {
        id: wifiCol
        required property var net
        // PERF: per-delegate cache — icon + status closure re-ran for
        // all N rows on any list/busy change. Evaluate once per delegate.
        readonly property string _icon: scope.wifiIcon(wifiCol.net.signal || 0)
        readonly property string _statusText: {
            if (scope.busySsid === wifiCol.net.ssid) return "Connecting…"
            if (wifiCol.net.active) return "Connected"
            return ""
        }
        readonly property bool _secured: wifiCol.net.security !== "--" && wifiCol.net.security !== ""
        spacing: 6
        Rectangle {
            antialiasing: Theme.shapesAa
            width: wifiCol.width
            implicitHeight: 40
            radius: Theme.cornerRadiusSmall
            color: wifiCol.net.active ? Theme.withAlpha(Theme.accent, 0.14) : "transparent"
            border.color: wifiCol.net.active ? Theme.withAlpha(Theme.accent, 0.55) : "transparent"
            border.width: wifiCol.net.active ? 1 : 0
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10; anchors.rightMargin: 10
                spacing: 10
                Rectangle {
                    Layout.preferredWidth: 10; Layout.preferredHeight: 10
                    Layout.alignment: Qt.AlignVCenter
                    radius: 5
                    color: wifiCol.net.active ? Theme.accent : "transparent"
                    border.color: wifiCol.net.active ? Theme.accent : Theme.textMuted
                    border.width: wifiCol.net.active ? 0 : 1
                }
                Text {
                    text: wifiCol._icon
                    color: wifiCol.net.active ? Theme.textPrimary : Theme.textSecondary
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fs(16)
                    Layout.preferredWidth: 22
                    horizontalAlignment: Text.AlignHCenter
                    Layout.alignment: Qt.AlignVCenter
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 1
                    Text {
                        Layout.fillWidth: true
                        text: wifiCol.net.ssid
                        color: wifiCol.net.active ? Theme.textPrimary : Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(12)
                        font.weight: wifiCol.net.active ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    Text {
                        visible: wifiCol._statusText !== ""
                        Layout.fillWidth: true
                        text: wifiCol._statusText
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(10)
                        elide: Text.ElideRight
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                }
                Text {
                    visible: wifiCol._secured
                    text: "󰌾"
                    color: Theme.textMuted
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fs(12)
                    Layout.alignment: Qt.AlignVCenter
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                Text {
                    visible: !wifiCol.net.active && wifiMouse.containsMouse
                    text: "󰅙"
                    color: Theme.errorColor
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fs(13)
                    Layout.alignment: Qt.AlignVCenter
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    StateLayer {
                        anchors.fill: parent
                        anchors.margins: -6
                        radius: Math.round(width / 2)
                        color: Theme.errorColor
                        onClicked: mouse => { mouse.accepted = true; NetworkService.forgetWifi(wifiCol.net.ssid) }
                    }
                }
            }
            StateLayer {
                id: wifiMouse
                radius: Theme.cornerRadiusSmall
                color: Theme.textPrimary
                onClicked: {
                    let n = wifiCol.net
                    if (n.active) { NetworkService.disconnectWifi(); return }
                    let secured = n.security !== "--" && n.security !== ""
                    if (secured) scope.pwSsid = (scope.pwSsid === n.ssid) ? "" : n.ssid
                    else { scope.busySsid = n.ssid; scope.busyTimer.restart(); NetworkService.connectWifi(n.ssid, "") }
                }
            }
        }
        // PERF: password editor instantiated per network row (N TextInputs in
        // focus chain + N onCompleted focus checks). Loader-gate to open row.
        // Inline drill-in: M3 fade enter/exit, loader stays alive until the
        // fade-out finished.
        Loader {
            readonly property bool pwOpen: scope.pwSsid === wifiCol.net.ssid
            active: visible
            visible: opacity > 0.01
            opacity: pwOpen ? 1 : 0
            Behavior on opacity {
                enabled: Theme.animationsEnabled
                NumberAnimation { duration: Theme.durSmall; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMotion }
            }
            width: wifiCol.width
            height: visible ? 40 : 0
            asynchronous: true
            sourceComponent: pwEditorComp
        }
        Component {
            id: pwEditorComp
            Rectangle {
            width: wifiCol.width
            height: 40
            clip: true
            radius: Theme.cornerRadiusSmall
            antialiasing: Theme.shapesAa
            color: Theme.withAlpha(Theme.textPrimary, 0.04)
            border.color: pwField.activeFocus ? Theme.accent : Theme.divider
            border.width: pwField.activeFocus ? 2 : 1
            Row {
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 12
                spacing: 6
                TextInput {
                    id: pwField
                    width: parent.width - 80
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    color: Theme.textPrimary
                    selectionColor: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(12)
                    passwordCharacter: "•"
                    echoMode: TextInput.Password
                    onAccepted: {
                        scope.busySsid = wifiCol.net.ssid
                        scope.busyTimer.restart()
                        scope.pwSsid = ""
                        NetworkService.connectWifi(wifiCol.net.ssid, text)
                    }
                    Component.onCompleted: forceActiveFocus()
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Connect"
                    color: pwGoMouse.containsMouse ? Theme.accent : Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(12)
                    font.weight: Font.Bold
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    StateLayer {
                        id: pwGoMouse
                        anchors.fill: parent
                        anchors.margins: -8
                        radius: 8
                        color: Theme.accent
                        onClicked: pwField.accepted()
                    }
                }
            }
            } // Rectangle (pwEditorComp)
        } // Component pwEditorComp
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
                    } else if (event.text === "r" || event.text === "R") {
                        NetworkService.rescan()
                        event.accepted = true
                    } else if (event.text === "w" || event.text === "W") {
                        NetworkService.toggleWifi()
                        event.accepted = true
                    }
                }
                Component.onCompleted: forceActiveFocus()
            }
            // Disabled while the panel is closing: during a morph handoff
            // the outgoing window stays mapped for panelHideDelay and must
            // not eat the click that belongs to the panel now on top.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                enabled: scope.showNetwork
                onClicked: scope.dismissed()
            }
            PanelShell {
                moduleId: "network"
                screenActive: Theme.isPrimaryScreen(modelData)
                barPos: scope.barPos
                panelGap: scope.panelGap
                shown: scope.showNetwork
                boxWidth: 320
                        // Header: title + status pill + rescan shortcut.
                        RowLayout {
                            width: parent.width
                            spacing: 6
                            Text {
                                text: "Network"
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fs(13)
                                font.weight: Font.Bold
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                            Rectangle {
                                Layout.preferredHeight: 20
                                Layout.preferredWidth: Math.max(52, statusTxt.implicitWidth + 18)
                                radius: 12
                                color: scope.statusOk ? Theme.withAlpha(Theme.accent, 0.16) : Theme.withAlpha(Theme.errorColor, 0.16)
                                border.color: scope.statusOk ? Theme.accent : Theme.errorColor
                                border.width: 1
                                Text {
                                    id: statusTxt
                                    anchors.centerIn: parent
                                    text: scope.statusText
                                    color: scope.statusOk ? Theme.textPrimary : Theme.errorColor
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fs(10)
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1.0
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                            }
                            PanelKit.IconButton {
                                glyph: "↻"
                                onClicked: NetworkService.rescan()
                            }
                        }
                        // Hero connection card.
                        PanelKit.Card {
                            width: parent.width
                            implicitHeight: heroCol.implicitHeight + 20
                            ColumnLayout {
                                id: heroCol
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 6
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    Rectangle {
                                        Layout.preferredWidth: 40; Layout.preferredHeight: 40
                                        Layout.alignment: Qt.AlignVCenter
                                        radius: Theme.cornerRadiusSmall
                                        color: NetworkService.netActive ? Theme.withAlpha(Theme.accent, 0.18) : Theme.withAlpha(Theme.textPrimary, 0.06)
                                        border.color: NetworkService.netActive ? Theme.withAlpha(Theme.accent, 0.5) : Theme.divider
                                        border.width: 1
                                        Text {
                                            anchors.centerIn: parent
                                            text: NetworkService.icon
                                            color: NetworkService.netActive ? Theme.textPrimary : Theme.textMuted
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: Theme.fs(19)
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 2
                                        PanelKit.SectionLabel { text: "CONNECTION" }
                                        Text {
                                            Layout.fillWidth: true
                                            text: scope.heroTitle
                                            color: Theme.textPrimary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fs(15)
                                            font.weight: Font.Bold
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                        }
                                        Text {
                                            visible: text !== ""
                                            Layout.fillWidth: true
                                            text: scope.heroMeta
                                            color: Theme.textSecondary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fs(10)
                                            font.weight: Font.Bold
                                            font.letterSpacing: 1.2
                                            elide: Text.ElideRight
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                        }
                                    }
                                    PanelKit.TogglePill {
                                        Layout.alignment: Qt.AlignVCenter
                                        on: NetworkService.wifiEnabled
                                        onText: "󰖩  ON"
                                        offText: "󰖪  OFF"
                                        offColor: Theme.errorColor
                                        offTextColor: Theme.errorColor
                                        onClicked: NetworkService.toggleWifi()
                                    }
                                }
                                GridLayout {
                                    visible: NetworkService.netActive
                                    Layout.fillWidth: true
                                    columns: 3
                                    columnSpacing: 12
                                    rowSpacing: 4
                                    Repeater {
                                        // PERF: static model (was array literal rebuilt on
                                        // every rx/tx/ping/signal tick, recreating 6 delegates
                                        // every 5s).
                                        model: ["IP Address", "Gateway", "Received", "Sent", "Ping", "Signal"]
                                        delegate: Column {
                                            required property var modelData
                                            required property int index
                                            // PERF: index-based value (no per-tick object alloc).
                                            readonly property string cellValue: {
                                                if (index === 0) return NetworkService.ipAddr !== "" ? NetworkService.ipAddr : "--"
                                                if (index === 1) return NetworkService.gateway !== "" ? NetworkService.gateway : "--"
                                                if (index === 2) return NetworkService.rxBytes
                                                if (index === 3) return NetworkService.txBytes
                                                if (index === 4) return NetworkService.pingMs !== "" ? NetworkService.pingMs : "--"
                                                return NetworkService.activeType === "wifi" ? NetworkService.signal + "%" : (NetworkService.activeType === "ethernet" ? "Wired" : "--")
                                            }
                                            spacing: 1
                                            Layout.fillWidth: true
                                            Text {
                                                text: modelData.toUpperCase()
                                                color: Theme.textMuted
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fs(10)
                                                font.weight: Font.Bold
                                                font.letterSpacing: 1.0
                                                antialiasing: Theme.textAa
                                                renderType: Theme.textRenderType
                                            }
                                            Text {
                                                text: cellValue
                                                color: Theme.textPrimary
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fs(12)
                                                font.weight: Font.DemiBold
                                                elide: Text.ElideRight
                                                width: parent.width
                                                antialiasing: Theme.textAa
                                                renderType: Theme.textRenderType
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        // DNS card.
                        PanelKit.Card {
                            visible: scope.dnsVisible
                            width: parent.width
                            implicitHeight: dnsCol.implicitHeight + 20
                            ColumnLayout {
                                id: dnsCol
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 6
                                PanelKit.SectionLabel { text: scope.dnsHeader }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    DnsPill { label: "Auto"; sub: "DHCP"; mode: "auto" }
                                    DnsPill { label: "Cloudflare"; sub: "1.1.1.1"; mode: "cloudflare" }
                                    DnsPill { label: "Google"; sub: "8.8.8.8"; mode: "google" }
                                }
                                Text {
                                    visible: NetworkService.dnsMode === "custom"
                                    Layout.fillWidth: true
                                    text: "Custom DNS set externally — pick a pill to override"
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fs(10)
                                    wrapMode: Text.WordWrap
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                            }
                        }
                        // Ethernet card.
                        PanelKit.Card {
                            visible: NetworkService.ethernetConns.length > 0
                            width: parent.width
                            implicitHeight: ethCol.implicitHeight + 20
                            ColumnLayout {
                                id: ethCol
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 6
                                PanelKit.SectionLabel { text: "ETHERNET  •  " + NetworkService.ethernetConns.length }
                                Repeater {
                                    model: NetworkService.ethernetConns
                                    delegate: PanelKit.DeviceRow {
                                        required property var modelData
                                        required property int index
                                        glyph: "󰈀"
                                        label: modelData.name
                                        sub: modelData.active ? "Connected" : ""
                                        isActive: !!modelData.active
                                        Layout.fillWidth: true
                                        onPicked: {
                                            if (modelData.active) NetworkService.ethDisconnect(modelData.name)
                                            else NetworkService.ethConnect(modelData.name)
                                        }
                                    }
                                }
                            }
                        }
                        // Wi-Fi card.
                        PanelKit.Card {
                            visible: NetworkService.wifiEnabled
                            width: parent.width
                            implicitHeight: wifiCardCol.implicitHeight + 20
                            ColumnLayout {
                                id: wifiCardCol
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 6
                                PanelKit.SectionLabel { text: NetworkService.wifiNetworks.length > 0 ? "WI-FI  •  " + NetworkService.wifiNetworks.length : "WI-FI" }
                                Repeater {
                                    model: NetworkService.wifiNetworks
                                    delegate: WifiRow {
                                        required property var modelData
                                        required property int index
                                        net: modelData
                                        Layout.fillWidth: true
                                    }
                                }
                                Text {
                                    visible: NetworkService.wifiNetworks.length === 0
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignCenter
                                    text: "No networks found"
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fs(10)
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                            }
                        }
            }
        }
    }
}
