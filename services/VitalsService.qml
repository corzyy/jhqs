pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    FileView {
        id: vitalsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/config/vitals.json"
        watchChanges: true; blockLoading: true; printErrors: false
        onFileChanged: {
            try { reload() } catch (e) { }
        }
        adapter: JsonAdapter {
            property bool showCpu: true
            property bool showRam: true
            property bool showGpu: true
            property bool showLabels: true
            property int refreshSeconds: 2
            property int warnThreshold: 75
            property int critThreshold: 90
        }
    }

    readonly property bool showCpu: vitalsFile.adapter.showCpu !== false
    readonly property bool showRam: vitalsFile.adapter.showRam !== false
    readonly property bool showGpu: vitalsFile.adapter.showGpu !== false
    readonly property bool showLabels: vitalsFile.adapter.showLabels !== false
    readonly property int refreshSeconds: Math.max(1, Math.min(10, parseInt(vitalsFile.adapter.refreshSeconds) || 2))
    readonly property int warnThreshold: Math.max(10, Math.min(95, parseInt(vitalsFile.adapter.warnThreshold) || 75))
    readonly property int critThreshold: Math.max(20, Math.min(99, parseInt(vitalsFile.adapter.critThreshold) || 90))
    readonly property bool hasVisibleMetric: showCpu || showRam || showGpu

    function setShowCpu(v: bool): void { let nv = !!v; if (!!vitalsFile.adapter.showCpu === nv) return; vitalsFile.adapter.showCpu = nv; vitalsFile.writeAdapter() }
    function setShowRam(v: bool): void { let nv = !!v; if (!!vitalsFile.adapter.showRam === nv) return; vitalsFile.adapter.showRam = nv; vitalsFile.writeAdapter() }
    function setShowGpu(v: bool): void { let nv = !!v; if (!!vitalsFile.adapter.showGpu === nv) return; vitalsFile.adapter.showGpu = nv; vitalsFile.writeAdapter() }
    function setShowLabels(v: bool): void { let nv = !!v; if ((vitalsFile.adapter.showLabels !== false) === nv) return; vitalsFile.adapter.showLabels = nv; vitalsFile.writeAdapter() }
    function setRefreshSeconds(n: int): void {
        let c = Math.max(1, Math.min(10, Math.round(n)))
        if (isNaN(c)) return
        if ((parseInt(vitalsFile.adapter.refreshSeconds) || 2) === c) return
        vitalsFile.adapter.refreshSeconds = c
        vitalsFile.writeAdapter()
    }
    function setWarnThreshold(n: int): void {
        let c = Math.max(10, Math.min(95, Math.round(n)))
        if (isNaN(c)) return
        if ((parseInt(vitalsFile.adapter.warnThreshold) || 75) === c) return
        vitalsFile.adapter.warnThreshold = c
        if (critThreshold <= c) vitalsFile.adapter.critThreshold = Math.min(99, c + 10)
        vitalsFile.writeAdapter()
    }
    function setCritThreshold(n: int): void {
        let c = Math.max(20, Math.min(99, Math.round(n)))
        if (isNaN(c)) return
        if ((parseInt(vitalsFile.adapter.critThreshold) || 90) === c) return
        vitalsFile.adapter.critThreshold = c
        if (warnThreshold >= c) vitalsFile.adapter.warnThreshold = Math.max(10, c - 10)
        vitalsFile.writeAdapter()
    }

    property real cpuPct: 0
    property real ramPct: 0
    property real ramUsedGb: 0
    property real ramTotalGb: 0
    property real gpuPct: 0
    property string gpuName: ""
    property bool gpuAvailable: false
    property string loadAvg: ""
    property var topProcs: []

    property double _prevIdle: -1
    property double _prevTotal: -1

    function severity(pct: real): int {
        if (pct >= critThreshold) return 2
        if (pct >= warnThreshold) return 1
        return 0
    }
    readonly property int worstSeverity: {
        let w = 0
        if (showCpu) w = Math.max(w, severity(cpuPct))
        if (showRam) w = Math.max(w, severity(ramPct))
        if (showGpu && gpuAvailable) w = Math.max(w, severity(gpuPct))
        return w
    }

    function status(): string {
        return "cpu=" + Math.round(cpuPct) + "% ram=" + Math.round(ramPct) + "%"
            + " gpu=" + (gpuAvailable ? Math.round(gpuPct) + "%" : "n/a")
    }
    function refresh(): void { if (!vitalsProc.running) vitalsProc.running = true }

    Process {
        id: vitalsProc
        command: ["bash", "-c", "idle=$(awk '/^cpu /{print $5}' /proc/stat 2>/dev/null); total=$(awk '/^cpu /{s=0;for(i=2;i<=NF;i++)s+=$i;print s}' /proc/stat 2>/dev/null); echo \"STAT ${idle:-0} ${total:-0}\"; awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{if(t>0) print \"MEM \"t\" \"a}' /proc/meminfo 2>/dev/null; if command -v nvidia-smi >/dev/null 2>&1; then g=$(nvidia-smi --query-gpu=utilization.gpu,name --format=csv,noheader,nounits 2>/dev/null | head -1); if [ -n \"$g\" ]; then echo \"GPU_NVIDIA $g\"; else echo \"GPU_NONE\"; fi; elif [ -r /sys/class/drm/card0/device/gpu_busy_percent ]; then echo \"GPU_AMD $(cat /sys/class/drm/card0/device/gpu_busy_percent 2>/dev/null | tr -d '\\n') Generic-AMDGPU\"; elif [ -r /sys/class/drm/card1/device/gpu_busy_percent ]; then echo \"GPU_AMD $(cat /sys/class/drm/card1/device/gpu_busy_percent 2>/dev/null | tr -d '\\n') Generic-AMDGPU\"; else echo \"GPU_NONE\"; fi; awk '{print \"LOAD \"$1}' /proc/loadavg 2>/dev/null; ps -eo pcpu,comm --sort=-pcpu 2>/dev/null | head -6 | tail -5 | awk '{printf \"TOP %.1f|%s\\n\", $1, $2}'"]
        stdout: StdioCollector {
            onStreamFinished: root.parseProbe(text || "")
        }
    }

    function parseProbe(out: string): void {
        try {
            let lines = (out || "").trim().split("\n")
            let tops = []
            for (let i = 0; i < lines.length; i++) {
                let l = (lines[i] || "").trim()
                if (l.length === 0) continue
                if (l.indexOf("STAT ") === 0) {
                    let p = l.substring(5).trim().split(/\s+/)
                    let idle = parseFloat(p[0]), total = parseFloat(p[1])
                    if (!isNaN(idle) && !isNaN(total) && total > 0) {
                        if (_prevIdle >= 0 && _prevTotal >= 0 && total > _prevTotal) {
                            let dIdle = idle - _prevIdle, dTotal = total - _prevTotal
                            if (dTotal > 0) {
                                let pct = (1 - dIdle / dTotal) * 100
                                if (!isNaN(pct)) cpuPct = Math.max(0, Math.min(100, pct))
                            }
                        }
                        _prevIdle = idle
                        _prevTotal = total
                    }
                } else if (l.indexOf("MEM ") === 0) {
                    let p = l.substring(4).trim().split(/\s+/)
                    let t = parseFloat(p[0]), a = parseFloat(p[1])
                    if (!isNaN(t) && t > 0 && !isNaN(a)) {
                        let used = t - a
                        ramTotalGb = t / 1048576
                        ramUsedGb = Math.max(0, used) / 1048576
                        ramPct = Math.max(0, Math.min(100, used / t * 100))
                    }
                } else if (l.indexOf("GPU_NVIDIA ") === 0) {
                    let rest = l.substring(11).trim()
                    let c = rest.indexOf(",")
                    let pct = parseFloat(c >= 0 ? rest.substring(0, c).trim() : rest)
                    let name = c >= 0 ? rest.substring(c + 1).trim() : ""
                    if (!isNaN(pct)) {
                        gpuPct = Math.max(0, Math.min(100, pct))
                        gpuAvailable = true
                        if (name.length > 0) gpuName = name
                    }
                } else if (l.indexOf("GPU_AMD ") === 0) {
                    let rest = l.substring(8).trim().split(/\s+/)
                    let pct = parseFloat(rest[0])
                    if (!isNaN(pct)) {
                        gpuPct = Math.max(0, Math.min(100, pct))
                        gpuAvailable = true
                        if (gpuName.length === 0) gpuName = "AMDGPU"
                    }
                } else if (l === "GPU_NONE") {
                    gpuAvailable = false
                } else if (l.indexOf("LOAD ") === 0) {
                    loadAvg = l.substring(5).trim()
                } else if (l.indexOf("TOP ") === 0) {
                    let rest = l.substring(4)
                    let s = rest.indexOf("|")
                    if (s > 0) {
                        let cpu = parseFloat(rest.substring(0, s))
                        let name = rest.substring(s + 1).trim()
                        if (!isNaN(cpu) && name.length > 0) tops.push({ cpu: cpu, name: name })
                    }
                }
            }
            if (tops.length > 0) topProcs = tops.slice(0, 5)
        } catch (e) { }
    }

    Timer {
        id: pollTimer
        interval: Math.max(1000, Math.min(10000, root.refreshSeconds * 1000))
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: { if (!vitalsProc.running) vitalsProc.running = true }
    }
}
