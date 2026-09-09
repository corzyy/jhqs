pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import "../themes"
import "../services"
import "../Ui"
import "./calendar" as CalUI
import "./controlcenter" as CC
import "./controlcenter/pickers" as Pickers
import "./controlcenter/tiles" as Tiles

Scope {
    id: controlCenterScope
    property bool showControlCenter: false
    signal dismissed()
    signal openSettings(string section)
    property bool _winVisible: showControlCenter
    Timer { id: ccHideTimer; interval: Theme.animSlow + 20; repeat: false; onTriggered: if (!controlCenterScope.showControlCenter) controlCenterScope._winVisible = false }
    onShowControlCenterChanged: {
        if (showControlCenter) {
            _winVisible = true
            ccHideTimer.stop()
            ccEditing = false
            wiredStaggeredInit.restart()
            btStaggeredInit.restart()
            sinkStaggeredInit.restart()
            if (!volProbe.running) volProbe.running = true
        } else {
            ccHideTimer.restart()
            collapseAllExpandables()
        }
    }
    Timer { id: wiredStaggeredInit; interval: 170; repeat: false; onTriggered: if (!wiredPollProc.running) wiredPollProc.running = true }
    Timer { id: btStaggeredInit; interval: 220; repeat: false; onTriggered: if (!btPollProc.running) btPollProc.running = true }
    Timer { id: sinkStaggeredInit; interval: 320; repeat: false; onTriggered: refreshSinks() }

    readonly property int barT: Theme.barThickness
    readonly property string barPos: Theme.barPosition
    readonly property int screenGap: 6
    property int panelGap: screenGap - Theme.barThickness
    readonly property bool isMinimal: Theme.minimalTheme

    property color bg: Theme.bg
    property color surface: Theme.panelSurface
    property color surface2: Theme.surface2
    property color bgHover: Theme.bgHover
    property color bgSelected: Theme.bgSelected
    property color bgTileActive: Theme.bgTileActive
    property color bgTileInactive: Theme.bgTileInactive
    property color borderColor: Theme.borderColor
    property color borderOuter: Theme.borderOuter
    property color textPrimary: Theme.textPrimary
    property color textSecondary: Theme.textSecondary
    property color textMuted: Theme.textMuted
    property color accent: Theme.accent
    property color onAccent: Theme.onAccent
    property color iconColorSelected: Theme.iconColorSelected
    property color divider: Theme.divider

    property bool showSinkPicker: false
    property bool showBluetoothMenu: false
    property bool showWiredMenu: false
    function collapseAllExpandables(): void {
        showSinkPicker = false
        showBluetoothMenu = false
        showWiredMenu = false
    }
    function toggleExpandable(name: string): void {
        let isOpen = (name === "sink" && showSinkPicker)
            || (name === "bluetooth" && showBluetoothMenu)
            || (name === "wired" && showWiredMenu)
        collapseAllExpandables()
        if (!isOpen) {
            if (name === "sink") showSinkPicker = true
            else if (name === "bluetooth") showBluetoothMenu = true
            else if (name === "wired") showWiredMenu = true
        }
    }

    property bool wiredActive: false
    property string wiredStatus: "Getrennt"
    property string wiredName: "Wired"
    property string wiredDevice: ""
    Process {
        id: wiredPollProc
        command: ["bash", "-c", "dev=$(nmcli -t -f DEVICE,TYPE dev 2>/dev/null | grep ':ethernet' | cut -d: -f1 | head -1); state=$(nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null | grep ':ethernet:' | head -1 | cut -d: -f3 | tr -d '\\n'); conn=$(nmcli -t -f NAME,TYPE c show --active 2>/dev/null | grep -E ':ethernet|:802-3-ethernet' | cut -d: -f1 | head -1); if [ \"$state\" = \"connected\" ] || echo \"$state\" | grep -qi \"connected\"; then echo \"yes|$conn|$dev\"; else if nmcli -t -f NAME,TYPE c show --active 2>/dev/null | grep -qE ':ethernet|:802-3-ethernet'; then echo \"yes|$conn|$dev\"; else echo \"no|$conn|$dev\"; fi; fi | tr -d '\\n'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = (text || "").trim()
                if (out.length === 0) return
                let parts = out.split("|")
                let active = (parts[0] || "").toLowerCase() === "yes"
                let conn = (parts[1] || "").trim()
                let dev = (parts[2] || "").trim()
                controlCenterScope.wiredActive = active
                controlCenterScope.wiredDevice = dev
                if (active) {
                    if (conn.length > 0) controlCenterScope.wiredName = conn
                    else if (dev.length > 0) controlCenterScope.wiredName = dev
                    else controlCenterScope.wiredName = "Wired"
                    controlCenterScope.wiredStatus = "Verbunden"
                } else {
                    controlCenterScope.wiredName = "Wired"
                    controlCenterScope.wiredStatus = "Getrennt"
                }
            }
        }
    }
    Process { id: wiredToggleProc; command: ["bash", "-c", "echo"] }
    Process { id: networkSettingsProc; command: ["kitty", "--class", "nmtui", "--title", "Netzwerk", "bash", "-c", "nmtui; read -n1 -s"] }
    function toggleWired() {
        let dev = controlCenterScope.wiredDevice
        if (dev && dev.length > 0) {
            if (controlCenterScope.wiredActive) {
                wiredToggleProc.command = ["bash", "-c", "nmcli dev disconnect \"" + dev.replace(/\"/g, "\\\"") + "\" 2>/dev/null || nmcli con down id \"" + controlCenterScope.wiredName.replace(/\"/g, "\\\"") + "\" 2>/dev/null; echo done"]
            } else {
                wiredToggleProc.command = ["bash", "-c", "nmcli dev connect \"" + dev.replace(/\"/g, "\\\"") + "\" 2>/dev/null || nmcli con up id \"" + controlCenterScope.wiredName.replace(/\"/g, "\\\"") + "\" 2>/dev/null; echo done"]
            }
            if (!wiredToggleProc.running) wiredToggleProc.running = true
        } else {
            if (controlCenterScope.wiredActive) {
                wiredToggleProc.command = ["bash", "-c", "nmcli -t -f NAME,TYPE c show --active 2>/dev/null | grep -E ':ethernet|:802-3-ethernet' | cut -d: -f1 | while read n; do nmcli con down id \"$n\" 2>/dev/null; done; echo done"]
                if (!wiredToggleProc.running) wiredToggleProc.running = true
            } else {
                if (!networkSettingsProc.running) networkSettingsProc.running = true
            }
        }
        Qt.callLater(function(){ if (!wiredPollProc.running) wiredPollProc.running = true })
    }
    function openNetworkSettings() { if (!networkSettingsProc.running) networkSettingsProc.running = true }
    Timer {
        id: wiredTimer
        interval: 30000
        running: controlCenterScope.showControlCenter
        repeat: true
        triggeredOnStart: false
        onTriggered: if (!wiredPollProc.running) wiredPollProc.running = true
    }

    property bool bluetoothActive: false
    property string bluetoothStatus: "Aus"
    Process {
        id: btPollProc
        command: ["bash", "-c", "bluetoothctl --timeout 2 show 2>/dev/null | grep 'Powered:' | awk '{print $2}' | tr -d '\\n'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = (text || "").trim().toLowerCase()
                let on = (out === "yes")
                controlCenterScope.bluetoothActive = on
                controlCenterScope.bluetoothStatus = on ? "Ein" : "Aus"
            }
        }
    }
    Process { id: btOnProc; command: ["bash", "-c", "bluetoothctl --timeout 2 power on 2>/dev/null; echo on"] }
    Process { id: btOffProc; command: ["bash", "-c", "bluetoothctl --timeout 2 power off 2>/dev/null; echo off"] }
    Process { id: btSettingsProc; command: ["bash", "-c", "blueman-manager 2>/dev/null || kitty --class bluetooth --title Bluetooth bluetoothctl &"] }
    Timer {
        id: btTimer
        interval: 30000
        running: controlCenterScope.showControlCenter
        repeat: true
        triggeredOnStart: false
        onTriggered: if (!btPollProc.running) btPollProc.running = true
    }
    function toggleBluetooth() {
        if (bluetoothActive) { if (!btOffProc.running) btOffProc.running = true }
        else { if (!btOnProc.running) btOnProc.running = true }
        Qt.callLater(function(){ if (!btPollProc.running) btPollProc.running = true })
    }
    function openBtSettings() { if (!btSettingsProc.running) btSettingsProc.running = true }

    property var btDeviceList: []
    property bool btScanning: false
    readonly property bool btPairing: btPairProc.running
    Process {
        id: btDevicesProc
        command: ["bash", "-c", "bluetoothctl --timeout 2 devices 2>/dev/null | while IFS= read -r line; do mac=$(echo \"$line\" | awk '{print $2}'); devName=$(echo \"$line\" | cut -d' ' -f3- | sed 's/|/ /g' | xargs); if [ -z \"$mac\" ]; then continue; fi; info=$(bluetoothctl --timeout 2 info \"$mac\" 2>/dev/null); paired=$(echo \"$info\" | grep -i 'Paired:' | awk '{print $2}' | tr '[:upper:]' '[:lower:]'); connected=$(echo \"$info\" | grep -i 'Connected:' | awk '{print $2}' | tr '[:upper:]' '[:lower:]'); aliasName=$(echo \"$info\" | grep -m1 'Alias:' | cut -d: -f2- | sed 's/|/ /g' | xargs); realName=$(echo \"$info\" | grep -m1 'Name:' | cut -d: -f2- | sed 's/|/ /g' | xargs); if [ -n \"$aliasName\" ]; then name=\"$aliasName\"; elif [ -n \"$realName\" ]; then name=\"$realName\"; elif [ -n \"$devName\" ]; then name=\"$devName\"; else name=\"$mac\"; fi; if [ -z \"$paired\" ]; then paired=no; fi; if [ -z \"$connected\" ]; then connected=no; fi; echo \"$mac|$name|$paired|$connected\"; done | tr -d '\\r'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = (text || "").trim()
                if (out.length === 0) { controlCenterScope.btDeviceList = []; return }
                let lines = out.split("\n")
                let arr = []
                for (let i=0;i<lines.length;i++) {
                    let l = lines[i].trim()
                    if (l.length === 0) continue
                    let parts = l.split("|")
                    if (parts.length < 2) continue
                    let mac = (parts[0]||"").trim()
                    let name = (parts[1]||"").trim()
                    let paired = (parts[2]||"no").trim().toLowerCase() === "yes"
                    let connected = (parts[3]||"no").trim().toLowerCase() === "yes"
                    if (mac.length === 0) continue
                    arr.push({mac: mac, name: name, paired: paired, connected: connected})
                }
                controlCenterScope.btDeviceList = arr
            }
        }
    }
    Process { id: btScanOnProc; command: ["bash", "-c", "bluetoothctl --timeout 15 scan on 2>&1 | head -5; echo on"] }
    Process { id: btScanOffProc; command: ["bash", "-c", "pkill -f \"bluetoothctl.*scan on\" 2>/dev/null; bluetoothctl --timeout 2 scan off 2>&1 | head -5; echo off"] }
    Process { id: btConnectProc; command: ["bash", "-c", "echo"] }
    Process { id: btDisconnectProc; command: ["bash", "-c", "echo"] }
    Process {
        id: btPairProc
        command: ["bash", "-c", "echo"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!btDevicesProc.running) btDevicesProc.running = true
            }
        }
    }
    Process { id: btRemoveProc; command: ["bash", "-c", "echo"] }
    Timer { id: btScanTimeout; interval: 15000; repeat: false; onTriggered: { controlCenterScope.btScanning = false; if (!btScanOffProc.running) btScanOffProc.running = true } }
    Timer { id: btDevicesTimer; interval: 10000; running: controlCenterScope.showControlCenter && controlCenterScope.showBluetoothMenu; repeat: true; triggeredOnStart: true; onTriggered: if (!btDevicesProc.running) btDevicesProc.running = true }
    function refreshBtDevices() { if (!btDevicesProc.running) btDevicesProc.running = true }
    function toggleBtScanning() {
        if (controlCenterScope.btScanning) {
            controlCenterScope.btScanning = false
            btScanTimeout.stop()
            if (!btScanOffProc.running) btScanOffProc.running = true
        } else {
            if (!controlCenterScope.bluetoothActive && !btOnProc.running) btOnProc.running = true
            controlCenterScope.btScanning = true
            if (!btScanOnProc.running) btScanOnProc.running = true
            btScanTimeout.restart()
            Qt.callLater(function(){ refreshBtDevices() })
        }
    }
    function btConnect(mac) {
        btConnectProc.command = ["bash", "-c", "bluetoothctl --timeout 10 connect \"" + mac.replace(/\"/g, "\\\"") + "\" 2>/dev/null; echo done"]
        if (!btConnectProc.running) btConnectProc.running = true
        Qt.callLater(function(){ if (!btDevicesProc.running) btDevicesProc.running = true })
    }
    function btDisconnect(mac) {
        btDisconnectProc.command = ["bash", "-c", "bluetoothctl --timeout 5 disconnect \"" + mac.replace(/\"/g, "\\\"") + "\" 2>/dev/null; echo done"]
        if (!btDisconnectProc.running) btDisconnectProc.running = true
        Qt.callLater(function(){ if (!btDevicesProc.running) btDevicesProc.running = true })
    }
    function btPair(mac) {
        let esc = mac.replace(/\"/g, "\\\"").replace(/\$/g, "\\$").replace(/`/g, "\\`").trim()
        if (esc.length === 0) return
        btPairProc.command = ["bash", "-c", "timeout 18 bash -c 'printf \"agent NoInputNoOutput\\ndefault-agent\\npairable on\\npair " + esc + "\\ntrust " + esc + "\\nconnect " + esc + "\\nquit\\n\" | bluetoothctl 2>&1 | head -40; echo done'"]
        if (!btPairProc.running) btPairProc.running = true
        Qt.callLater(function(){ if (!btDevicesProc.running) btDevicesProc.running = true })
        pairRefreshTimer.restart()
    }
    Timer { id: pairRefreshTimer; interval: 4000; repeat: false; onTriggered: if (!btDevicesProc.running) btDevicesProc.running = true }
    function btRemove(mac) {
        btRemoveProc.command = ["bash", "-c", "bluetoothctl --timeout 5 remove \"" + mac.replace(/\"/g, "\\\"") + "\" 2>/dev/null; echo done"]
        if (!btRemoveProc.running) btRemoveProc.running = true
        Qt.callLater(function(){ if (!btDevicesProc.running) btDevicesProc.running = true })
    }

    property var wifiNetworks: []
    property var ethernetConns: []
    property bool wifiScanning: false
    Process {
        id: wifiListProc
        command: ["bash", "-c", "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi 2>/dev/null | grep -v '^--' | while IFS=: read -r inuse ssid signal sec; do if [ -z \"$ssid\" ]; then ssid=$(echo \"$inuse\" | xargs); inuse=\"\"; signal=\"\"; sec=\"\"; fi; # handle empty ssid edge\n if [ -z \"$ssid\" ] || [ \"$ssid\" = \"--\" ]; then continue; fi; iu=$(echo \"$inuse\" | tr -d '\\n' | xargs); sig=$(echo \"$signal\" | tr -d '\\n' | xargs); ssec=$(echo \"$sec\" | tr -d '\\n' | xargs); if [ \"$iu\" = \"*\" ]; then active=yes; else active=no; fi; if [ -z \"$sig\" ]; then sig=0; fi; if [ -z \"$ssec\" ]; then ssec=\"--\"; fi; echo \"$active|$ssid|$sig|$ssec\"; done | sort -t'|' -k3 -nr | head -20"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = (text || "").trim()
                if (out.length === 0) { controlCenterScope.wifiNetworks = []; return }
                let lines = out.split("\n")
                let arr = []
                for (let i=0;i<lines.length;i++) {
                    let l = lines[i].trim()
                    if (l.length===0) continue
                    let p = l.split("|")
                    if (p.length < 2) continue
                    let active = (p[0]||"no").trim().toLowerCase() === "yes"
                    let ssid = (p[1]||"").trim()
                    let signal = parseInt((p[2]||"0").trim()); if (isNaN(signal)) signal = 0
                    let sec = (p[3]||"--").trim()
                    if (ssid.length===0) continue
                    arr.push({ssid: ssid, signal: signal, security: sec, active: active})
                }
                controlCenterScope.wifiNetworks = arr
            }
        }
    }
    Process {
        id: ethListProc
        command: ["bash", "-c", "nmcli -t -f NAME,TYPE,STATE,DEVICE con show 2>/dev/null | grep -E ':802-3-ethernet|:ethernet' | while IFS=: read -r name type state dev; do if [ -z \"$name\" ]; then continue; fi; echo \"$name|$type|$state|$dev\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = (text || "").trim()
                if (out.length === 0) { controlCenterScope.ethernetConns = []; return }
                let lines = out.split("\n")
                let arr = []
                for (let i=0;i<lines.length;i++) {
                    let l = lines[i].trim()
                    if (l.length===0) continue
                    let p = l.split("|")
                    if (p.length < 2) continue
                    let name = (p[0]||"").trim()
                    let type = (p[1]||"").trim()
                    let state = (p[2]||"").trim().toLowerCase()
                    let dev = (p[3]||"").trim()
                    let active = (state.indexOf("activated")!==-1 || state.indexOf("verbunden")!==-1)
                    arr.push({name: name, type: type, state: state, device: dev, active: active})
                }
                controlCenterScope.ethernetConns = arr
            }
        }
    }
    Process { id: wifiRescanProc; command: ["bash", "-c", "nmcli dev wifi rescan 2>/dev/null; echo done"] }
    Process { id: wifiConnectProc; command: ["bash", "-c", "echo"] }
    Process { id: ethUpProc; command: ["bash", "-c", "echo"] }
    Process { id: ethDownProc; command: ["bash", "-c", "echo"] }
    Timer { id: wifiScanTimeout; interval: 12000; repeat: false; onTriggered: { controlCenterScope.wifiScanning = false } }
    Timer { id: wiredMenuRefreshTimer; interval: 15000; running: controlCenterScope.showControlCenter && controlCenterScope.showWiredMenu; repeat: true; triggeredOnStart: true; onTriggered: { if (!wifiListProc.running) wifiListProc.running = true; if (!ethListProc.running) ethListProc.running = true } }
    function refreshWiredMenu() { if (!wifiListProc.running) wifiListProc.running = true; if (!ethListProc.running) ethListProc.running = true }
    function toggleWifiScanning() {
        if (controlCenterScope.wifiScanning) {
            controlCenterScope.wifiScanning = false
            wifiScanTimeout.stop()
        } else {
            controlCenterScope.wifiScanning = true
            if (!wifiRescanProc.running) wifiRescanProc.running = true
            wifiScanTimeout.restart()
            Qt.callLater(function(){ refreshWiredMenu() })
            wifiScanRefreshDelay.restart()
        }
    }
    Timer { id: wifiScanRefreshDelay; interval: 2500; repeat: false; onTriggered: refreshWiredMenu() }
    function wifiConnect(ssid) {
        let esc = ssid.replace(/\"/g, "\\\"").replace(/\\/g, "\\\\")
        wifiConnectProc.command = ["bash", "-c", "nmcli dev wifi connect \"" + esc + "\" 2>/dev/null || nmcli con up id \"" + esc + "\" 2>/dev/null; echo done"]
        if (!wifiConnectProc.running) wifiConnectProc.running = true
        Qt.callLater(function(){ refreshWiredMenu() })
    }
    function wifiDisconnect(ssid) {
        let esc = ssid.replace(/\"/g, "\\\"")
        wifiConnectProc.command = ["bash", "-c", "nmcli con down id \"" + esc + "\" 2>/dev/null || nmcli dev disconnect 2>/dev/null; echo done"]
        if (!wifiConnectProc.running) wifiConnectProc.running = true
        Qt.callLater(function(){ refreshWiredMenu() })
    }
    function ethConnect(name) {
        let esc = name.replace(/\"/g, "\\\"")
        ethUpProc.command = ["bash", "-c", "nmcli con up id \"" + esc + "\" 2>/dev/null; echo done"]
        if (!ethUpProc.running) ethUpProc.running = true
        Qt.callLater(function(){ refreshWiredMenu() })
    }
    function ethDisconnect(name) {
        let esc = name.replace(/\"/g, "\\\"")
        ethDownProc.command = ["bash", "-c", "nmcli con down id \"" + esc + "\" 2>/dev/null; echo done"]
        if (!ethDownProc.running) ethDownProc.running = true
        Qt.callLater(function(){ refreshWiredMenu() })
    }

    property string powerMode: Theme.powerMode
    function cyclePowerMode(): void { Theme.cyclePowerMode() }
    function powerModeLabel(): string { return Theme.powerModeLabel() }
    function powerModeIcon(): string { return Theme.powerModeIcon() }

    readonly property bool dndActive: Theme.dndEnabled
    function toggleDnd() { Theme.toggleDnd() }

    FileView {
        id: ccTilesFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/config/cc_tiles.json"
        watchChanges: true; onFileChanged: reload(); blockLoading: true; printErrors: false
        adapter: JsonAdapter {
            property string wired: "large"
            property string bluetooth: "large"
            property string power: "large"
            property string dnd: "large"
            property var hidden: []
            property var tileOrder: ["wired", "bluetooth", "power", "dnd"]
            property var blocks: ["volume", "tiles", "media"]
        }
    }
    function tileSize(id: string): string {
        let v = ""
        try {
            if (id === "wired") v = ccTilesFile.adapter.wired
            else if (id === "bluetooth") v = ccTilesFile.adapter.bluetooth
            else if (id === "power") v = ccTilesFile.adapter.power
            else if (id === "dnd") v = ccTilesFile.adapter.dnd
        } catch (e) { }
        return v === "compact" ? "compact" : "large"
    }
    function setTileSize(id: string, size: string): void {
        let s = size === "compact" ? "compact" : "large"
        try {
            if (id === "wired") { if (ccTilesFile.adapter.wired === s) return; ccTilesFile.adapter.wired = s }
            else if (id === "bluetooth") { if (ccTilesFile.adapter.bluetooth === s) return; ccTilesFile.adapter.bluetooth = s }
            else if (id === "power") { if (ccTilesFile.adapter.power === s) return; ccTilesFile.adapter.power = s }
            else if (id === "dnd") { if (ccTilesFile.adapter.dnd === s) return; ccTilesFile.adapter.dnd = s }
            else return
            ccTilesFile.writeAdapter()
        } catch (e) { }
    }
    function tileHiddenList(): var {
        try { return Theme.toStrArray(ccTilesFile.adapter.hidden) } catch (e) { return [] }
    }
    function isTileHidden(id: string): bool {
        try { return tileHiddenList().indexOf(id) >= 0 } catch (e) { return false }
    }
    function setTileHidden(id: string, hidden: bool): void {
        try {
            let h = tileHiddenList()
            let i = h.indexOf(id)
            if (hidden && i < 0) h.push(id)
            else if (!hidden && i >= 0) h.splice(i, 1)
            else return
            ccTilesFile.adapter.hidden = h
            ccTilesFile.writeAdapter()
        } catch (e) { }
    }
    function toggleTileHidden(id: string): void { setTileHidden(id, !isTileHidden(id)) }
    function tileOrderList(): var {
        let out = []
        try {
            let raw = Theme.toStrArray(ccTilesFile.adapter.tileOrder)
            let known = ["wired", "bluetooth", "power", "dnd"]
            for (let i = 0; i < raw.length; i++)
                if (known.indexOf(raw[i]) >= 0 && out.indexOf(raw[i]) < 0) out.push(raw[i])
            for (let i = 0; i < known.length; i++)
                if (out.indexOf(known[i]) < 0) out.push(known[i])
        } catch (e) { out = ["wired", "bluetooth", "power", "dnd"] }
        return out
    }
    function moveTile(id: string, delta: int): void {
        try {
            let order = tileOrderList()
            let from = order.indexOf(id)
            let to = Math.max(0, Math.min(order.length - 1, from + Math.round(delta)))
            if (from < 0 || from === to) return
            let tmp = order[from]
            order[from] = order[to]
            order[to] = tmp
            ccTilesFile.adapter.tileOrder = order
            ccTilesFile.writeAdapter()
        } catch (e) { }
    }
    function tileCell(id: string): var {
        let fallback = {row: 0, col: 0, span: 2}
        try {
            let order = tileOrderList()
            let vis = []
            for (let i = 0; i < order.length; i++)
                if (!isTileHidden(order[i])) vis.push(order[i])
            let row = 0, col = 0
            for (let k = 0; k < vis.length; k++) {
                let cur = vis[k]
                let span = tileSize(cur) === "compact" ? 1 : 2
                if (col + span > 4) { row++; col = 0 }
                if (cur === id) return {row: row, col: col, span: span}
                col += span
            }
        } catch (e) { }
        return fallback
    }

    function blockOrderList(): var {
        let out = []
        try {
            let raw = Theme.toStrArray(ccTilesFile.adapter.blocks)
            let known = ["volume", "tiles", "media"]
            for (let i = 0; i < raw.length; i++)
                if (known.indexOf(raw[i]) >= 0 && out.indexOf(raw[i]) < 0) out.push(raw[i])
            for (let i = 0; i < known.length; i++)
                if (out.indexOf(known[i]) < 0) out.push(known[i])
        } catch (e) { out = ["volume", "tiles", "media"] }
        return out
    }
    function moveBlockTo(id: string, idx: int): void {
        try {
            let order = blockOrderList()
            let from = order.indexOf(id)
            let to = Math.max(0, Math.min(order.length - 1, Math.round(idx)))
            if (from < 0 || from === to) return
            order.splice(from, 1)
            order.splice(to, 0, id)
            ccTilesFile.adapter.blocks = order
            ccTilesFile.writeAdapter()
            blockOrderRev++
        } catch (e) { }
    }
    property int blockOrderRev: 0

    property bool ccEditing: false
    property string ccEditTab: "edit"
    function enterEdit(): void {
        collapseAllExpandables()
        ccEditTab = "edit"
        ccEditing = true
    }
    function exitEdit(): void { ccEditing = false }

    readonly property bool showMediaPlayer: Theme.isBarModuleHidden("media")

    property PwNode sink: Pipewire.defaultAudioSink
    property bool sinkReady: sink !== null && sink.ready && sink.audio !== null
    property real vol: sinkReady ? sink.audio.volume : 0
    property bool isMuted: sinkReady ? sink.audio.muted : fallbackMuted
    property int volPct: sinkReady ? Math.round(vol * 100) : fallbackPct
    property int fallbackPct: 40
    property bool fallbackMuted: false
    property string fallbackText: "--"
    property bool volumeDragging: false
    property int pendingVol: -1
    property bool liveVolActive: false
    Timer { id: liveVolTimer; interval: 500; repeat: false; onTriggered: controlCenterScope.liveVolActive = false }
    onVolPctChanged: {
        if (!volumeDragging && !liveVolActive && sinkReady) {
            if (fallbackPct !== volPct) fallbackPct = volPct
        }
    }
    onIsMutedChanged: {
        if (!volumeDragging && !liveVolActive && sinkReady) {
            if (fallbackMuted !== isMuted) fallbackMuted = isMuted
        }
    }
    Process {
        id: volProbe
        command: ["bash", "-c", "/home/jakob/.config/quickshell/jhqs/scripts/volume.sh get 2>/dev/null | tr -d '\\n'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = (text || "").trim()
                if (out === "muted") { controlCenterScope.fallbackMuted = true; controlCenterScope.fallbackText = "muted" }
                else if (out.endsWith("%")) { let n = parseInt(out); if (!isNaN(n)) { controlCenterScope.fallbackPct = n; controlCenterScope.fallbackMuted = false; controlCenterScope.fallbackText = n + "%" } }
                else if (out === "--%" || out === "--" || out === "%") { controlCenterScope.fallbackText = "--" }
                else if (out.length > 0) { controlCenterScope.fallbackText = out }
            }
        }
    }
    Timer {
        id: volFallbackTimer
        interval: 6000
        running: !controlCenterScope.sinkReady && controlCenterScope.showControlCenter
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!volProbe.running) volProbe.running = true
    }
    Process {
        id: volSetProc
        command: ["bash", "-c", "echo"]
        onRunningChanged: {
            if (!running && controlCenterScope.pendingVol >= 0 && !volFallbackThrottle.running) {
                volFallbackThrottle.restart()
            }
        }
    }
    Process { id: volMuteProc; command: ["/usr/bin/wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"] }
    Timer {
        id: volFallbackThrottle
        interval: 35
        repeat: false
        onTriggered: {
            if (controlCenterScope.pendingVol < 0) return
            if (volSetProc.running) {
                restart()
                return
            }
            let v = controlCenterScope.pendingVol
            controlCenterScope.pendingVol = -1
            let frac = (v / 100).toFixed(2)
            volSetProc.command = ["bash", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + frac + " 2>/dev/null; wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 2>/dev/null; pactl set-sink-mute @DEFAULT_AUDIO_SINK@ 0 2>/dev/null || true"]
            volSetProc.running = true
        }
    }
    function toggleMute() { if (!volMuteProc.running) volMuteProc.running = true }
    function setVolumePct(v: int) {
        let clamped = Math.max(0, Math.min(100, v))
        controlCenterScope.fallbackPct = clamped
        controlCenterScope.fallbackMuted = false
        controlCenterScope.liveVolActive = true
        liveVolTimer.restart()
        if (controlCenterScope.sinkReady) {
            try {
                if (controlCenterScope.sink.audio.muted) controlCenterScope.sink.audio.muted = false
                controlCenterScope.sink.audio.volume = clamped / 100
            } catch (e) {
                console.log("[ControlCenter] PipeWire setVolume err", e)
            }
            return
        }
        controlCenterScope.pendingVol = clamped
        if (!volSetProc.running && !volFallbackThrottle.running) {
            let cur = controlCenterScope.pendingVol
            controlCenterScope.pendingVol = -1
            let frac = (cur / 100).toFixed(2)
            volSetProc.command = ["bash", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + frac + " 2>/dev/null; wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 2>/dev/null; pactl set-sink-mute @DEFAULT_AUDIO_SINK@ 0 2>/dev/null || true"]
            volSetProc.running = true
        } else if (!volFallbackThrottle.running) {
            volFallbackThrottle.restart()
        }
    }

    property var sinks: []
    property string defaultSinkName: ""
    Process {
        id: defaultSinkProc
        command: ["bash", "-c", "pactl get-default-sink 2>/dev/null | tr -d '\\n'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = (text || "").trim()
                if (out.length > 0) controlCenterScope.defaultSinkName = out
            }
        }
    }
    Process {
        id: sinkListProc
        command: ["bash", "-c", "pactl list sinks 2>/dev/null | awk ' /Name:/{n=$2} /Description:|Beschreibung:/{sub(/^[^:]*: /, \"\"); d=$0; print n\"|\"d}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = (text || "").trim()
                if (out.length === 0) { controlCenterScope.sinks = []; return }
                let lines = out.split("\n")
                let arr = []
                for (let i = 0; i < lines.length; i++) {
                    let l = lines[i].trim()
                    if (l.length === 0) continue
                    let sep = l.indexOf("|")
                    if (sep === -1) continue
                    let name = l.substring(0, sep).trim()
                    let desc = l.substring(sep + 1).trim()
                    if (name.length === 0) continue
                    arr.push({name: name, desc: desc})
                }
                controlCenterScope.sinks = arr
            }
        }
    }
    Process { id: switchSinkProc; command: ["bash", "-c", "echo"] }
    function refreshSinks() {
        if (!defaultSinkProc.running) defaultSinkProc.running = true
        if (!sinkListProc.running) sinkListProc.running = true
        refreshSources()
    }
    Timer {
        id: sinkRefreshTimer
        interval: 15000
        running: controlCenterScope.showControlCenter
        repeat: true
        triggeredOnStart: false
        onTriggered: refreshSinks()
    }
    Timer {
        id: sinkPickerRefreshTimer
        interval: 10000
        running: controlCenterScope.showControlCenter && controlCenterScope.showSinkPicker
        repeat: true
        onTriggered: refreshSinks()
    }
    function switchSink(name: string) {
        if (!name || name.length === 0) return
        switchSinkProc.command = ["bash", "-c", "pactl set-default-sink \"" + name.replace(/\"/g, "\\\"") + "\" 2>/dev/null; for i in $(pactl list short sink-inputs 2>/dev/null | cut -f1); do pactl move-sink-input \"$i\" \"" + name.replace(/\"/g, "\\\"") + "\" 2>/dev/null; done; echo done"]
        if (!switchSinkProc.running) switchSinkProc.running = true
        controlCenterScope.defaultSinkName = name
    }

    property var sources: []
    property string defaultSourceName: ""
    Process {
        id: defaultSourceProc
        command: ["bash", "-c", "pactl get-default-source 2>/dev/null | tr -d '\\n'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = (text || "").trim()
                if (out.length > 0) controlCenterScope.defaultSourceName = out
            }
        }
    }
    Process {
        id: sourceListProc
        command: ["bash", "-c", "pactl list sources 2>/dev/null | awk ' /Name:/{n=$2} /Description:|Beschreibung:/{sub(/^[^:]*: /, \"\"); d=$0; print n\"|\"d}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = (text || "").trim()
                if (out.length === 0) { controlCenterScope.sources = []; return }
                let lines = out.split("\n")
                let arr = []
                for (let i = 0; i < lines.length; i++) {
                    let l = lines[i].trim()
                    if (l.length === 0) continue
                    let sep = l.indexOf("|")
                    if (sep === -1) continue
                    let name = l.substring(0, sep).trim()
                    let desc = l.substring(sep + 1).trim()
                    if (name.length === 0) continue
                    if (name.endsWith(".monitor")) continue
                    arr.push({name: name, desc: desc})
                }
                controlCenterScope.sources = arr
            }
        }
    }
    Process { id: switchSourceProc; command: ["bash", "-c", "echo"] }
    function refreshSources() {
        if (!defaultSourceProc.running) defaultSourceProc.running = true
        if (!sourceListProc.running) sourceListProc.running = true
    }
    function switchSource(name: string) {
        if (!name || name.length === 0) return
        switchSourceProc.command = ["bash", "-c", "pactl set-default-source \"" + name.replace(/\"/g, "\\\"") + "\" 2>/dev/null; for i in $(pactl list short source-outputs 2>/dev/null | cut -f1); do pactl move-source-output \"$i\" \"" + name.replace(/\"/g, "\\\"") + "\" 2>/dev/null; done; echo done"]
        if (!switchSourceProc.running) switchSourceProc.running = true
        controlCenterScope.defaultSourceName = name
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: controlCenterScope._winVisible && modelData.name === "DP-1"
            color: "transparent"
            exclusiveZone: -1
            anchors { top: true; left: true; right: true; bottom: true }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "controlcenter-backdrop"
            Rectangle {
                antialiasing: Theme.shapesAa
                anchors.fill: parent
                color: Theme.scrim
                opacity: controlCenterScope.showControlCenter ? 0.20 : 0.0
                Behavior on opacity { NumberAnimation { duration: controlCenterScope.showControlCenter ? Theme.panelAnimFade : Theme.animSlow; easing.type: controlCenterScope.showControlCenter ? Theme.panelEasingFade : Theme.panelEasingExit } }
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: controlCenterScope.dismissed()
            }
        }
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: controlCenterScope._winVisible && modelData.name === "DP-1"
            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "controlcenter"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            anchors { top: true; left: true; right: true; bottom: true }
            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        if (controlCenterScope.ccEditing) controlCenterScope.ccEditing = false
                        else if (controlCenterScope.showWiredMenu) controlCenterScope.showWiredMenu = false
                        else if (controlCenterScope.showBluetoothMenu) controlCenterScope.showBluetoothMenu = false
                        else if (controlCenterScope.showSinkPicker) controlCenterScope.showSinkPicker = false
                        else controlCenterScope.dismissed()
                        event.accepted = true
                    }
                }
                Component.onCompleted: forceActiveFocus()
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: controlCenterScope.dismissed()
            }
            Rectangle {
                antialiasing: Theme.shapesAa
                id: ccBox
                width: 340
                BarAnchor {
                    id: ccAnchor
                    moduleId: "controlcenter"
                    barPos: controlCenterScope.barPos
                    panelWidth: ccBox.width
                    panelHeight: ccBox.implicitHeight
                    screenWidth: ccBox.parent.width
                    screenHeight: ccBox.parent.height
                    gap: controlCenterScope.panelGap
                    fallbackX: ccBox.parent.width - ccBox.width - controlCenterScope.panelGap
                    fallbackY: ccBox.parent.height - ccBox.implicitHeight - controlCenterScope.panelGap
                }
                x: ccAnchor.panelX
                y: ccAnchor.panelY
                implicitHeight: flick.contentHeight + 24
                color: controlCenterScope.isMinimal ? Theme.bg : Theme.panelBg
                border.color: controlCenterScope.isMinimal ? Theme.accent : Theme.panelBorderColor
                border.width: controlCenterScope.isMinimal ? 2 : 1
                radius: controlCenterScope.isMinimal ? 0 : Theme.cornerRadius
                clip: true
                Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingSmooth } }
                PanelSpring {
                    id: ccSpring
                    slideFade: true
                    shown: controlCenterScope.showControlCenter
                    hiddenX: controlCenterScope.barPos === "left" ? -(ccBox.width + 5) : controlCenterScope.barPos === "right" ? (ccBox.width + 5) : 0
                    hiddenY: controlCenterScope.barPos === "top" ? -(ccBox.implicitHeight + 5) : controlCenterScope.barPos === "bottom" ? (ccBox.implicitHeight + 5) : 0
                }
                visible: ccSpring.boxVisible
                opacity: ccSpring.fade
                scale: ccSpring.zoom
                transformOrigin: ccAnchor.origin
                transform: Translate { x: ccSpring.slideX; y: ccSpring.slideY }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onClicked: mouse => mouse.accepted = true
                    onPressed: mouse => mouse.accepted = true
                    onWheel: wheel => wheel.accepted = true
                }
                Flickable {
                    id: flick
                    anchors.fill: parent
                    anchors.margins: 10
                    contentHeight: mainCol.implicitHeight
                    contentWidth: width
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick
                    ColumnLayout {
                        id: mainCol
                        width: parent.width
                        spacing: 10

                        RowLayout {
                            visible: !controlCenterScope.ccEditing
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            spacing: 8
                            Rectangle {
                                antialiasing: Theme.shapesAa
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                radius: width / 2
                                color: editPencilMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.08) : "transparent"
                                border.width: 0
                                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                                scale: Theme.animationsEnabled && editPencilMouse.pressed ? 0.9 : 1.0
                                Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
                                Text { anchors.centerIn: parent; text: "󰏫"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(15); color: Theme.textPrimary
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                                MouseArea {
                                    id: editPencilMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: controlCenterScope.enterEdit()
                                }
                            }
                            Rectangle {
                                antialiasing: Theme.shapesAa
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                radius: width / 2
                                color: settingsGearMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.08) : "transparent"
                                border.width: 0
                                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                                scale: Theme.animationsEnabled && settingsGearMouse.pressed ? 0.9 : 1.0
                                Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
                                Text { anchors.centerIn: parent; text: "󰒓"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(16); color: Theme.textPrimary
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                                MouseArea {
                                    id: settingsGearMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: controlCenterScope.openSettings("global")
                                }
                            }
                            Item { Layout.fillWidth: true; height: 1 }
                        }

                        RowLayout {
                            visible: controlCenterScope.ccEditing
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            spacing: 10
                            Rectangle {
                                antialiasing: Theme.shapesAa
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
                                radius: width / 2
                                color: editBackMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.08) : "transparent"
                                border.width: 0
                                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                                scale: Theme.animationsEnabled && editBackMouse.pressed ? 0.9 : 1.0
                                Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
                                Text { anchors.centerIn: parent; text: "󰕌"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(18); color: Theme.textPrimary
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                                MouseArea {
                                    id: editBackMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: controlCenterScope.exitEdit()
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                    text: "Tiles bearbeiten"
                                    font.family: Theme.fontFamily; font.pixelSize: Theme.fs(16); font.weight: Font.Bold
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                    text: controlCenterScope.ccEditTab === "layout" ? "Layout per Ziehen anordnen" : "Tiles auswählen zum Anordnen und Ändern"
                                    font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11)
                                    color: Theme.textSecondary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        ColumnLayout {
                            id: normalWrap
                            visible: !controlCenterScope.ccEditing
                            Layout.fillWidth: true
                            spacing: 10
                            function applyOrder(): void {
                                let order = controlCenterScope.blockOrderList()
                                let items = {volume: volumeSection, tiles: tilesSection, media: mediaSection}
                                for (let k = 0; k < order.length; k++) {
                                    let it = items[order[k]]
                                    if (!it) continue
                                    it.parent = null
                                    it.parent = normalWrap
                                }
                            }
                            Component.onCompleted: applyOrder()
                            property var _orderSig: controlCenterScope.blockOrderList()
                            on_OrderSigChanged: applyOrder()
                            Connections {
                                target: controlCenterScope
                                function onBlockOrderRevChanged() { normalWrap.applyOrder() }
                            }
                            ColumnLayout {
                                id: volumeSection
                                Layout.fillWidth: true
                                spacing: 8
                                Tiles.VolumeTile { scope: controlCenterScope }
                                Pickers.SinkPicker {
                                    Layout.fillWidth: true
                                    scope: controlCenterScope
                                }
                            }
                            ColumnLayout {
                                id: tilesSection
                                Layout.fillWidth: true
                                spacing: 8
                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 4
                                    columnSpacing: 10
                                    rowSpacing: 10
                                    Tiles.WiredTile {
                                        scope: controlCenterScope
                                        visible: !controlCenterScope.isTileHidden("wired")
                                        Layout.row: controlCenterScope.tileCell("wired").row
                                        Layout.column: controlCenterScope.tileCell("wired").col
                                        Layout.columnSpan: controlCenterScope.tileCell("wired").span
                                    }
                                    Tiles.BluetoothTile {
                                        scope: controlCenterScope
                                        visible: !controlCenterScope.isTileHidden("bluetooth")
                                        Layout.row: controlCenterScope.tileCell("bluetooth").row
                                        Layout.column: controlCenterScope.tileCell("bluetooth").col
                                        Layout.columnSpan: controlCenterScope.tileCell("bluetooth").span
                                    }
                                    Tiles.PowerTile {
                                        scope: controlCenterScope
                                        visible: !controlCenterScope.isTileHidden("power")
                                        Layout.row: controlCenterScope.tileCell("power").row
                                        Layout.column: controlCenterScope.tileCell("power").col
                                        Layout.columnSpan: controlCenterScope.tileCell("power").span
                                    }
                                    Tiles.DndTile {
                                        scope: controlCenterScope
                                        visible: !controlCenterScope.isTileHidden("dnd")
                                        Layout.row: controlCenterScope.tileCell("dnd").row
                                        Layout.column: controlCenterScope.tileCell("dnd").col
                                        Layout.columnSpan: controlCenterScope.tileCell("dnd").span
                                    }
                                }
                                Pickers.WiredMenu {
                                    Layout.fillWidth: true
                                    scope: controlCenterScope
                                }
                                Pickers.BluetoothMenuView {
                                    Layout.fillWidth: true
                                    scope: controlCenterScope
                                }
                            }
                            CalUI.MusicPlayer {
                                id: mediaSection
                                Layout.fillWidth: true
                                visible: controlCenterScope.showMediaPlayer
                                scope: MediaService
                            }
                        }

                        CC.TileEditor {
                            visible: controlCenterScope.ccEditing
                            Layout.fillWidth: true
                            scope: controlCenterScope
                        }
                    }
                }
            }
        }
    }
}
