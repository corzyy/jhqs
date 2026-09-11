pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool btActive: false
    property string btStatus: "Aus"
    property var btDevices: []
    property bool btScanning: false

    readonly property string icon: {
        if (!btActive) return "󰂲"
        try {
            for (let d of btDevices) { if (d && d.connected) return "󰂱" }
        } catch (e) {}
        return "󰂯"
    }
    // NOTE: anyConnected removed — exact duplicate of the loop in `icon`,
    // and zero external readers (panel buckets the list itself).

    Process {
        id: btPollProc
        command: ["bash", "-c", "bluetoothctl --timeout 2 show 2>/dev/null | grep 'Powered:' | awk '{print $2}' | tr -d '\\n'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let on = ((text || "").trim().toLowerCase() === "yes")
                root.btActive = on
                root.btStatus = on ? "Ein" : "Aus"
            }
        }
    }
    Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!btPollProc.running) btPollProc.running = true }
    function refreshPower() { if (!btPollProc.running) btPollProc.running = true }

    Process { id: btOnProc; command: ["bash", "-c", "bluetoothctl --timeout 2 power on 2>/dev/null; echo on"] }
    Process { id: btOffProc; command: ["bash", "-c", "bluetoothctl --timeout 2 power off 2>/dev/null; echo off"] }
    function togglePower() {
        if (btActive) { if (!btOffProc.running) btOffProc.running = true }
        else { if (!btOnProc.running) btOnProc.running = true }
        Qt.callLater(refreshPower)
    }

    Process {
        id: btDevicesProc
        command: ["bash", "-c", "paired=$(bluetoothctl --timeout 2 devices Paired 2>/dev/null | awk '{print $2}'); conn=$(bluetoothctl --timeout 2 devices Connected 2>/dev/null | awk '{print $2}'); bluetoothctl --timeout 2 devices 2>/dev/null | awk '{mac=$2; $1=$2=\"\"; gsub(/^ +/, \"\"); gsub(/\\|/, \" \"); print mac\"|\"$0}' | while IFS='|' read -r mac name; do [ -z \"$mac\" ] && continue; p=no; c=no; case \" $paired \" in *\" $mac \"*) p=yes;; esac; case \" $conn \" in *\" $mac \"*) c=yes;; esac; nm=$(echo \"$name\" | xargs); [ -z \"$nm\" ] && nm=\"$mac\"; echo \"$mac|$nm|$p|$c\"; done | tr -d '\\r'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = (text || "").trim()
                if (out.length === 0) { root.btDevices = []; return }
                let arr = []
                for (let l of out.split("\n")) {
                    let p = l.trim().split("|")
                    if (p.length < 2) continue
                    let mac = (p[0] || "").trim()
                    if (mac.length === 0) continue
                    arr.push({
                        mac: mac,
                        name: (p[1] || "").trim() || mac,
                        paired: (p[2] || "no").trim().toLowerCase() === "yes",
                        connected: (p[3] || "no").trim().toLowerCase() === "yes"
                    })
                }
                root.btDevices = arr
            }
        }
    }
    function refreshDevices() { if (!btDevicesProc.running) btDevicesProc.running = true }

    Process { id: btScanOnProc; command: ["bash", "-c", "bluetoothctl --timeout 15 scan on 2>&1 | head -5; echo on"] }
    Process { id: btScanOffProc; command: ["bash", "-c", "bluetoothctl --timeout 2 scan off 2>&1 | head -5; echo off"] }
    Timer { id: btScanTimeout; interval: 20000; repeat: false; onTriggered: { root.btScanning = false; if (!btScanOffProc.running) btScanOffProc.running = true } }
    function setScanning(on: bool): void {
        if (on) {
            if (!btActive && !btOnProc.running) btOnProc.running = true
            root.btScanning = true
            if (!btScanOnProc.running) btScanOnProc.running = true
            btScanTimeout.restart()
            Qt.callLater(refreshDevices)
        } else {
            root.btScanning = false
            btScanTimeout.stop()
            if (!btScanOffProc.running) btScanOffProc.running = true
        }
    }

    Process { id: btConnectProc; command: ["bash", "-c", "echo"] }
    Process { id: btDisconnectProc; command: ["bash", "-c", "echo"] }
    Process {
        id: btPairProc
        command: ["bash", "-c", "echo"]
        stdout: StdioCollector {
            onStreamFinished: { if (!btDevicesProc.running) btDevicesProc.running = true }
        }
    }
    Process { id: btRemoveProc; command: ["bash", "-c", "echo"] }
    Timer { id: pairRefreshTimer; interval: 4000; repeat: false; onTriggered: if (!btDevicesProc.running) btDevicesProc.running = true }
    function escMac(mac: string): string { return (mac || "").replace(/"/g, "\\\"").trim() }
    function btConnect(mac: string): void {
        let m = escMac(mac)
        if (m.length === 0) return
        btConnectProc.command = ["bash", "-c", "bluetoothctl --timeout 10 connect \"" + m + "\" 2>/dev/null; echo done"]
        if (!btConnectProc.running) btConnectProc.running = true
        Qt.callLater(refreshDevices)
    }
    function btDisconnect(mac: string): void {
        let m = escMac(mac)
        if (m.length === 0) return
        btDisconnectProc.command = ["bash", "-c", "bluetoothctl --timeout 5 disconnect \"" + m + "\" 2>/dev/null; echo done"]
        if (!btDisconnectProc.running) btDisconnectProc.running = true
        Qt.callLater(refreshDevices)
    }
    function btPair(mac: string): void {
        let m = escMac(mac).replace(/\$/g, "\\$").replace(/`/g, "\\`")
        if (m.length === 0) return
        btPairProc.command = ["bash", "-c", "timeout 18 bash -c 'printf \"agent NoInputNoOutput\\ndefault-agent\\npairable on\\npair " + m + "\\ntrust " + m + "\\nconnect " + m + "\\nquit\\n\" | bluetoothctl 2>&1 | head -40; echo done'"]
        if (!btPairProc.running) btPairProc.running = true
        Qt.callLater(refreshDevices)
        pairRefreshTimer.restart()
    }
    function btRemove(mac: string): void {
        let m = escMac(mac)
        if (m.length === 0) return
        btRemoveProc.command = ["bash", "-c", "bluetoothctl --timeout 5 remove \"" + m + "\" 2>/dev/null; echo done"]
        if (!btRemoveProc.running) btRemoveProc.running = true
        Qt.callLater(refreshDevices)
    }
}
