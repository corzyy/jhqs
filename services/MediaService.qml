pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root
    property var selectedPlayer: null
    property var _playStamps: ({})

    function playerKey(p: var): string {
        try {
            let d = p.dbusName || ""
            if (d !== "") return d
            return p.identity || ""
        } catch (e) { return "" }
    }
    function rawPlayers(): var {
        try {
            let v = Mpris.players.values
            let vals = typeof v === "function" ? v() : v
            return vals ? vals.slice() : []
        } catch (e) { return [] }
    }
    Timer {
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            let vals = root.rawPlayers()
            if (vals.length === 0) {
                let empty = true
                for (let k in root._playStamps) { empty = false; break }
                if (empty) return
            }
            let now = Date.now()
            let seen = {}
            let changed = false
            let next = {}
            for (let k in root._playStamps) next[k] = root._playStamps[k]
            for (let i = 0; i < vals.length; i++) {
                let k = root.playerKey(vals[i])
                if (k === "") continue
                seen[k] = true
                try {
                    if (vals[i] && vals[i].isPlaying && next[k] !== now) { next[k] = now; changed = true }
                } catch (e) {}
            }
            for (let k2 in next) {
                if (!seen[k2]) { delete next[k2]; changed = true }
            }
            if (changed) root._playStamps = next
        }
    }

    readonly property var allPlayers: {
        let vals = rawPlayers()
        let stamps = root._playStamps
        vals.sort(function (a, b) {
            let ta = stamps[root.playerKey(a)] || 0
            let tb = stamps[root.playerKey(b)] || 0
            return tb - ta
        })
        return vals
    }

    readonly property var currentPlayer: {
        let vals = allPlayers
        if (!vals || vals.length === 0) return null
        if (selectedPlayer && vals.includes(selectedPlayer)) return selectedPlayer
        for (let p of vals) if (p && p.isPlaying) return p
        return vals[0]
    }

    onAllPlayersChanged: {
        if (selectedPlayer && !allPlayers.includes(selectedPlayer)) selectedPlayer = null
    }

    readonly property bool hasPlayer: allPlayers.length > 0
    readonly property bool isPlaying: currentPlayer ? !!currentPlayer.isPlaying : false

    readonly property string trackLabel: {
        let p = currentPlayer
        if (!p) return ""
        let t = p.trackTitle || "", a = p.trackArtist || ""
        if (t && a) return t + " — " + a
        return t || a || (p.identity || "")
    }
    readonly property string widgetIcon: hasPlayer ? (isPlaying ? "󰐊" : "󰏤") : "󰎆"

    function togglePlay(): void { try { if (currentPlayer) currentPlayer.togglePlaying() } catch(e) {} }
    function playNext(): void { try { if (currentPlayer) currentPlayer.next() } catch(e) {} }
    function playPrev(): void { try { if (currentPlayer) currentPlayer.previous() } catch(e) {} }
}
