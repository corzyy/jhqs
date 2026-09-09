pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root
    property var history: []
    readonly property int maxHistory: 100
    function add(entry: var): void {
        let next = [...history, entry]
        if (next.length > maxHistory) next = next.slice(-maxHistory)
        history = next
    }
    function remove(id: int): void { history = history.filter(e => e.id !== id) }
    function clear(): void { history = [] }
    function count(): int { return history.length }
}
