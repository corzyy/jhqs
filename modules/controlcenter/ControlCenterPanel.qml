pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Wayland
import "../../themes"
import "../../services"
import "../../Ui"

Scope {
    id: scope

    property bool showControlCenter: false
    signal dismissed()
    signal settingsRequested()
    signal powerRequested()

    property bool editing: false
    property bool flashlightOn: false
    property var hiddenTiles: ({})

    property bool _winVisible: showControlCenter
    Timer {
        id: hideTimer
        interval: Theme.panelHideDelay
        repeat: false
        onTriggered: if (!scope.showControlCenter) scope._winVisible = false
    }
    onShowControlCenterChanged: {
        if (showControlCenter) {
            _winVisible = true
            hideTimer.stop()
        } else {
            editing = false
            hideTimer.restart()
        }
    }

    readonly property string barPos: Theme.barPosition
    property int panelGap: -(Theme.barThickness + Theme.panelAttachOverlap)

    function tileHidden(id: string): bool { return hiddenTiles[id] === true }
    function tileVisible(id: string): bool { return editing || !tileHidden(id) }
    function toggleTile(id: string): void {
        const next = {}
        for (const key in hiddenTiles) next[key] = hiddenTiles[key]
        next[id] = !tileHidden(id)
        hiddenTiles = next
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: scope.showControlCenter
    }

    readonly property var battery: UPower.displayDevice
    readonly property bool batteryVisible: battery !== null && battery.ready && battery.isPresent
    readonly property int batteryPct: batteryVisible ? Math.round(battery.percentage * 100) : 0
    readonly property bool batteryCharging: batteryVisible
        && (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged)

    function batteryGlyph(pct: int, charging: bool): string {
        if (charging) return "󰂄"
        if (pct >= 90) return "󰁹"
        if (pct >= 80) return "󰂁"
        if (pct >= 60) return "󰁿"
        if (pct >= 40) return "󰁽"
        if (pct >= 20) return "󰁻"
        return "󰂃"
    }

    readonly property bool flightModeOn: !NetworkService.wifiEnabled && !BluetoothService.btActive
    function toggleFlightMode(): void {
        if (flightModeOn) {
            if (!NetworkService.wifiEnabled) NetworkService.setWifiEnabled(true)
            if (!BluetoothService.btActive) BluetoothService.togglePower()
        } else {
            if (NetworkService.wifiEnabled) NetworkService.toggleWifi()
            if (BluetoothService.btActive) BluetoothService.togglePower()
        }
    }

    readonly property int btConnected: BluetoothService.connectedDevs ? BluetoothService.connectedDevs.length : 0

    readonly property string timeText: Qt.formatDateTime(clock.date, "HH:mm")
    readonly property string dateText: Qt.formatDateTime(clock.date, "ddd, d. MMM")

    function wifiStatus(): string {
        if (!NetworkService.wifiEnabled) return "Aus"
        if (!NetworkService.netActive) return "Kein Netz"
        if (NetworkService.activeType === "ethernet") return NetworkService.ssid !== "" ? NetworkService.ssid : "Ethernet"
        return NetworkService.ssid !== "" ? NetworkService.ssid : "Verbunden"
    }
    function bluetoothStatus(): string {
        if (!BluetoothService.btActive) return "Aus"
        if (btConnected > 0) return btConnected + (btConnected === 1 ? " Gerät" : " Geräte")
        return "An"
    }

    component HeaderStatusIcon: Text {
        color: Theme.textPrimary
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.fs(16)
        antialiasing: Theme.textAa
        renderType: Theme.textRenderType
        verticalAlignment: Text.AlignVCenter
    }

    component FooterButton: Item {
        id: footerButton
        property string glyph
        property bool emphasized: false
        signal clicked()
        implicitWidth: 42
        implicitHeight: 42

        Rectangle {
            anchors.fill: parent
            radius: Theme.cornerRadiusSmall
            antialiasing: Theme.shapesAa
            color: footerMouse.containsMouse ? Theme.withAlpha(Theme.on_surface, 0.1) : "transparent"

            Behavior on color {
                enabled: Theme.animationsEnabled
                ColorAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
            }

            Text {
                anchors.centerIn: parent
                text: footerButton.glyph
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fs(18)
                color: footerButton.emphasized ? Theme.primary : (footerMouse.containsMouse ? Theme.primary : Theme.textPrimary)
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType

                Behavior on color {
                    enabled: Theme.animationsEnabled
                    ColorAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
                }
            }
        }

        MouseArea {
            id: footerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: footerButton.clicked()
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
            WlrLayershell.namespace: "controlcenterpanel"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        scope.dismissed()
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

            PanelShell {
                moduleId: "controlcenter"
                barPos: scope.barPos
                panelGap: scope.panelGap
                shown: scope.showControlCenter
                boxWidth: 360
                contentSpacing: 12

                RowLayout {
                    width: parent.width
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: scope.timeText
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(28)
                            font.weight: Font.DemiBold
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }
                        Text {
                            text: scope.dateText
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(12)
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 10

                        HeaderStatusIcon {
                            visible: NetworkService.netActive || NetworkService.wifiEnabled
                            text: NetworkService.icon
                        }
                        HeaderStatusIcon {
                            visible: BluetoothService.btActive
                            text: BluetoothService.icon
                        }
                        RowLayout {
                            visible: scope.batteryVisible
                            spacing: 4
                            HeaderStatusIcon { text: scope.batteryGlyph(scope.batteryPct, scope.batteryCharging) }
                            Text {
                                text: scope.batteryPct + "%"
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fs(12)
                                font.weight: Font.Medium
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                        }
                    }
                }

                RowLayout {
                    width: parent.width
                    visible: scope.editing
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: "Kacheln bearbeiten"
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(13)
                        font.weight: Font.Medium
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    Text {
                        text: "Tippen zum Ausblenden"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(11)
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                }

                GridLayout {
                    width: parent.width
                    columns: 2
                    columnSpacing: 10
                    rowSpacing: 10

                    QuickToggle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 72
                        visible: scope.tileVisible("wifi")
                        editing: scope.editing
                        selected: !scope.tileHidden("wifi")
                        glyph: NetworkService.icon
                        title: "WLAN"
                        status: scope.wifiStatus()
                        active: NetworkService.wifiEnabled
                        onToggled: NetworkService.toggleWifi()
                        onEditToggled: scope.toggleTile("wifi")
                    }
                    QuickToggle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 72
                        visible: scope.tileVisible("bluetooth")
                        editing: scope.editing
                        selected: !scope.tileHidden("bluetooth")
                        glyph: BluetoothService.icon
                        title: "Bluetooth"
                        status: scope.bluetoothStatus()
                        active: BluetoothService.btActive
                        onToggled: BluetoothService.togglePower()
                        onEditToggled: scope.toggleTile("bluetooth")
                    }
                    QuickToggle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 72
                        visible: scope.tileVisible("dnd")
                        editing: scope.editing
                        selected: !scope.tileHidden("dnd")
                        glyph: "󰂛"
                        title: "Nicht stören"
                        status: Theme.dndEnabled ? "An" : "Aus"
                        active: Theme.dndEnabled
                        onToggled: Theme.toggleDnd()
                        onEditToggled: scope.toggleTile("dnd")
                    }
                    QuickToggle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 72
                        visible: scope.tileVisible("flashlight")
                        editing: scope.editing
                        selected: !scope.tileHidden("flashlight")
                        glyph: "󰉄"
                        title: "Taschenlampe"
                        status: scope.flashlightOn ? "An" : "Aus"
                        active: scope.flashlightOn
                        onToggled: scope.flashlightOn = !scope.flashlightOn
                        onEditToggled: scope.toggleTile("flashlight")
                    }
                    QuickToggle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 72
                        visible: scope.tileVisible("flight")
                        editing: scope.editing
                        selected: !scope.tileHidden("flight")
                        glyph: "󰀝"
                        title: "Flugmodus"
                        status: scope.flightModeOn ? "An" : "Aus"
                        active: scope.flightModeOn
                        onToggled: scope.toggleFlightMode()
                        onEditToggled: scope.toggleTile("flight")
                    }
                    QuickToggle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 72
                        visible: scope.tileVisible("gamemode")
                        editing: scope.editing
                        selected: !scope.tileHidden("gamemode")
                        glyph: "󰊗"
                        title: "Gamemode"
                        status: Theme.gamemodeEnabled ? "An" : "Aus"
                        active: Theme.gamemodeEnabled
                        onToggled: Theme.toggleGamemode()
                        onEditToggled: scope.toggleTile("gamemode")
                    }
                }

                CcSlider {
                    width: parent.width
                    glyph: "󰃟"
                    value: Math.max(0, Math.min(1, SettingsService.brightness / 100))
                    onUserMoved: v => SettingsService.applyBrightness(Math.max(5, Math.round(v * 100)))
                }
                CcSlider {
                    width: parent.width
                    glyph: VolumeService.icon
                    muted: VolumeService.isMuted
                    value: Math.max(0, Math.min(1, VolumeService.pct / 100))
                    onUserMoved: v => VolumeService.setVolumeFrac(v)
                }

                MediaPlayerCard {
                    width: parent.width
                }

                RowLayout {
                    width: parent.width
                    spacing: 6

                    FooterButton {
                        glyph: "󰒓"
                        onClicked: scope.settingsRequested()
                    }
                    FooterButton {
                        glyph: scope.editing ? "󰄬" : "󰏫"
                        emphasized: scope.editing
                        onClicked: scope.editing = !scope.editing
                    }
                    Item { Layout.fillWidth: true }
                    FooterButton {
                        glyph: "󰐥"
                        emphasized: true
                        onClicked: scope.powerRequested()
                    }
                }
            }
        }
    }
}
