pragma Singleton
import QtQuick
import Quickshell

// RAM: history entries are capped and large strings truncated so 100
// notifications cannot pin MBs of markup.
// NOTE: `import Quickshell` is required — it provides the `Singleton` type.
Singleton {
    id: root
    property var history: []
    readonly property int maxHistory: 100
    function add(entry: var): void {
        // Truncate heavy fields at the boundary — body/image/actions can
        // otherwise retain full HTML + base64 icons per notification.
        try {
            if (entry) {
                if (typeof entry.body === "string" && entry.body.length > 500)
                    entry = Object.assign({}, entry, { body: entry.body.slice(0, 500) })
                if (typeof entry.image === "string" && entry.image.length > 256)
                    entry = Object.assign({}, entry, { image: entry.image.slice(0, 256) })
            }
        } catch (e) {}
        let next = [...history, entry]
        if (next.length > maxHistory) next = next.slice(-maxHistory)
        history = next
    }
    function remove(id: int): void { history = history.filter(e => e.id !== id) }
    function clear(): void { history = [] }
    // NOTE: count() removed — dead wrapper, callers use history.length.
}
