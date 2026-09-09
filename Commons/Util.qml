pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: root

    function clamp(value: var, min: real, max: real): real {
        var n = Number(value)
        if (!isFinite(n)) return min
        return Math.max(min, Math.min(max, n))
    }

    function clampAlpha(value: var): real {
        return clamp(value, 0, 1)
    }

    function alpha(c: var, opacity: real): color {
        var a = clampAlpha(opacity)
        if (!c) return Qt.rgba(0, 0, 0, a)
        if (typeof c === "string") c = Qt.color(c)
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    function fileUrl(path: string): string {
        if (!path) return ""
        return "file://" + String(path).split("/").map(encodeURIComponent).join("/")
    }

    function isVideoPath(path: string): bool {
        return /\.(mp4|m4v|mov|webm|mkv|avi)$/i.test(String(path || ""))
    }

    function shellQuote(value: string): string {
        return "'" + String(value || "").replace(/'/g, "'\\''") + "'"
    }

    function shellEscapeDq(value: string): string {
        return String(value || "").replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\$/g, "\\$").replace(/`/g, "\\`")
    }

    function execDetached(command: string): void {
        Quickshell.execDetached(["bash", "-lc", command])
    }

    function execArgv(argv: var): void {
        Quickshell.execDetached(["bash", "-lc", 'exec "$@"', "bash"].concat(argv))
    }

    function isPlainObject(value: var): bool {
        return value !== null && typeof value === "object" && !Array.isArray(value)
    }

    function canonicalWidgetId(id: string): string {
        return String(id || "")
    }

    function decodeBase64(value: string): string {
        var s = String(value || "")
        if (!s) return ""
        try { return Qt.atob(s) } catch (e) { return "" }
    }

    function cloneJson(value: var): var {
        return JSON.parse(JSON.stringify(value === undefined ? null : value))
    }

    function wheelSteps(accumulator: real, delta: real): var {
        delta = Math.max(-120, Math.min(120, delta))
        if (accumulator * delta < 0) accumulator = 0
        var total = accumulator + delta
        var steps = total < 0 ? Math.ceil(total / 120) : Math.floor(total / 120)
        return { steps: steps, remainder: total - steps * 120 }
    }

    function normalizeLayoutEntry(entry: var): var {
        if (typeof entry === "string") return { id: canonicalWidgetId(entry) }
        if (isPlainObject(entry) && entry.id) {
            var copy = cloneJson(entry)
            copy.id = canonicalWidgetId(copy.id)
            return copy
        }
        return null
    }

    function normalizeLayoutSection(list: var): var {
        if (!Array.isArray(list)) return []
        var out = []
        for (var i = 0; i < list.length; i++) {
            var e = normalizeLayoutEntry(list[i])
            if (e) out.push(e)
        }
        return out
    }

    function normalizeLayout(layout: var): var {
        var src = isPlainObject(layout) ? layout : {}
        return {
            left: normalizeLayoutSection(src.left),
            center: normalizeLayoutSection(src.center),
            right: normalizeLayoutSection(src.right)
        }
    }
}
