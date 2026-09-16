pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../../themes"
import "../../../Ui"

Item {
    id: root
    required property var scope
    required property var bodyRoot
    anchors.fill: parent
    anchors.margins: 0
    clip: true
    opacity: bodyRoot.scope.showModules ? 1 : 0
    visible: opacity > 0.01
    enabled: bodyRoot.scope.showModules
    scale: bodyRoot.scope.showModules ? 1 : 0.97
    transformOrigin: Item.Center
    Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durDefaultEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultEffects } }
    Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durFastSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial } }

    property string subview: "root"
    property int selectedIndex: 0
    property string status: ""
    property var meta: Theme.barModuleMetaList
    property var layoutRev: [Theme.barLayoutLeft, Theme.barLayoutTwoFifths, Theme.barLayoutCenter, Theme.barLayoutFourFifths, Theme.barLayoutRight, Theme.barHiddenIds()]
    property var addList: {
        layoutRev
        let out = []
        for (let i = 0; i < meta.length; i++) if (Theme.isBarModuleHidden(meta[i].id)) out.push(meta[i])
        return out
    }
    property var removeList: {
        layoutRev
        let vis = Theme.barVisibleIds()
        let out = []
        for (let i = 0; i < vis.length; i++) {
            for (let j = 0; j < meta.length; j++) if (meta[j].id === vis[i]) { out.push(meta[j]); break }
        }
        return out
    }
    property string query: {
        try { return ("" + bodyRoot.scope.filterText).toLowerCase().trim() } catch (e) { return "" }
    }
    function matchesModule(e, q) {
        if (q === "") return true
        let words = q.split(/\s+/).filter(w => w.length > 0)
        if (words.length === 0) return true
        let hay = ((("" + (e.title || "")) + " " + ("" + (e.id || "")))).toLowerCase()
        for (let i = 0; i < words.length; i++) if (hay.indexOf(words[i]) === -1) return false
        return true
    }
    property var filteredAddList: {
        let q = query
        if (q === "") return addList
        return addList.filter(e => matchesModule(e, q))
    }
    property var filteredRemoveList: {
        let q = query
        if (q === "") return removeList
        return removeList.filter(e => matchesModule(e, q))
    }
    function detailFor(e, withSection) {
        let mid = "" + (e.id || "")
        if (!withSection) return mid
        let s = sectionLabel(e.id)
        return s !== "" ? mid + " • " + s : mid
    }
    property var rootModel: {
        let a = addList.length, r = removeList.length
        return [
            {id: "add", title: "Module enable", icon: "󰐕", sub: a === 0 ? "all active" : a + " available"},
            {id: "remove", title: "Module remove", icon: "󰐖", sub: r === 0 ? "none active" : r + " active"}
        ]
    }
    function matchesRoot(e, q) {
        if (q === "") return true
        let words = q.split(/\s+/).filter(w => w.length > 0)
        if (words.length === 0) return true
        // Word-based AND match (any order), like the top-level menu search.
        let eid = ("" + (e.id || "")).toLowerCase()
        let hay = ((("" + (e.title || "")) + " " + eid)).toLowerCase()
        // Aliases so both views stay discoverable (module/modules).
        hay += eid === "remove" ? " delete remove uninstall disable" : " add enable install"
        hay += " module modules"
        for (let i = 0; i < words.length; i++) if (hay.indexOf(words[i]) === -1) return false
        return true
    }
    property var filteredRootModel: {
        let q = query
        if (q === "") return rootModel
        return rootModel.filter(e => matchesRoot(e, q))
    }
    property int navCount: subview === "add" ? filteredAddList.length : subview === "remove" ? filteredRemoveList.length : filteredRootModel.length
    onNavCountChanged: { if (selectedIndex >= navCount) selectedIndex = Math.max(0, navCount - 1) }
    function sectionLabel(id: string): string {
        let s = Theme.barSectionOf(id)
        if (s === "left") return "Left"
        if (s === "twofifths") return "2/5"
        if (s === "center") return "Center"
        if (s === "fourfifths") return "4/5"
        if (s === "right") return "Right"
        return ""
    }
    function openSubview(v: string) { subview = v; selectedIndex = 0; status = ""; Qt.callLater(() => listFlick.ensureVisible(0)) }
    function goBack() {
        if (subview !== "root") openSubview("root")
        else { bodyRoot.scope.modulesSubview = "root"; bodyRoot.scope.showModules = false; bodyRoot.scope.showStyle = true; bodyRoot.scope.clearSearch() }
    }
    function moveSelection(delta: int) {
        if (navCount <= 0) return
        selectedIndex = (selectedIndex + delta + navCount) % navCount
        listFlick.ensureVisible(selectedIndex)
    }
    function activateSelected() {
        if (subview === "root") {
            let e = filteredRootModel[selectedIndex]
            if (e) openSubview(e.id === "remove" ? "remove" : "add")
            return
        }
        if (subview === "add") {
            let e = filteredAddList[selectedIndex]
            if (e) status = Theme.showBarModule(e.id)
            return
        }
        if (subview === "remove") {
            let e = filteredRemoveList[selectedIndex]
            if (e) status = Theme.hideBarModule(e.id)
            return
        }
    }
    function handleKey(event): bool {
        if (event.key === Qt.Key_Down) { moveSelection(1); return true }
        if (event.key === Qt.Key_Up) { moveSelection(-1); return true }
        if (event.key === Qt.Key_Home) { selectedIndex = 0; listFlick.ensureVisible(0); return true }
        if (event.key === Qt.Key_End) { selectedIndex = Math.max(0, navCount - 1); listFlick.ensureVisible(selectedIndex); return true }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { activateSelected(); return true }
        if (event.key === Qt.Key_Escape) {
            if (subview !== "root") { goBack(); return true }
            return false
        }
        return false
    }
    Connections {
        target: bodyRoot.scope
        function onShowModulesChanged() {
            if (bodyRoot.scope.showModules) {
                let req = bodyRoot.scope.modulesSubview
                root.subview = (req === "add" || req === "remove") ? req : "root"
                root.selectedIndex = 0
                root.status = ""
            }
        }
        function onFilterTextChanged() {
            root.selectedIndex = 0
            if (listFlick) { listFlick.contentY = 0; Qt.callLater(() => listFlick.ensureVisible(0)) }
        }
    }

    ScrollIndicator { flick: listFlick }
    Flickable {
        id: listFlick
        anchors.fill: parent
        clip: true
        contentHeight: resultsCol.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        interactive: true
        function rowH(): int { return 61 }
        function ensureVisible(idx) {
            if (!root.visible || root.navCount === 0) return
            if (idx < 0 || idx >= root.navCount) return
            let y = idx * rowH()
            let vh = listFlick.height
            let maxY = Math.max(0, listFlick.contentHeight - vh)
            if (maxY <= 0) { listFlick.contentY = 0; return }
            let cy = listFlick.contentY
            if (y < cy) listFlick.contentY = Math.max(0, y - 4)
            else if (y + rowH() > cy + vh) listFlick.contentY = Math.min(maxY, y + rowH() - vh + 4)
        }

        ColumnLayout {
            id: resultsCol
            x: 0
            width: parent.width
            spacing: 3
            Repeater {
                id: rootRepeater
                model: root.subview === "root" ? root.filteredRootModel : []
                delegate: MenuRow {
                    selected: root.selectedIndex === index
                    glyph: "›"
                    sub: modelData.sub
                    onActivated: idx => { root.selectedIndex = idx; listFlick.ensureVisible(idx); root.activateSelected() }
                }
            }
            ColumnLayout {
                visible: root.subview === "root" && root.filteredRootModel.length === 0
                Layout.fillWidth: true
                spacing: 8
                Layout.topMargin: 24
                Text {
                    text: "󰐱"
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fs(28)
                    color: Theme.textMuted
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    text: root.query !== "" ? "No results for “" + bodyRoot.scope.filterText.trim() + "”" : "No modules"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(13)
                    color: Theme.textMuted
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }
            ColumnLayout {
                visible: root.subview === "add" && root.filteredAddList.length === 0
                Layout.fillWidth: true
                spacing: 8
                Layout.topMargin: 24
                Text {
                    text: "󰐱"
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fs(28)
                    color: Theme.textMuted
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    text: root.query !== "" ? "No results for “" + bodyRoot.scope.filterText.trim() + "”" : "All modules active"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(13)
                    color: Theme.textMuted
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }
            Repeater {
                id: addRepeater
                model: root.subview === "add" ? root.filteredAddList : []
                delegate: MenuRow {
                    selected: root.selectedIndex === index
                    glyph: ""
                    sub: root.detailFor(modelData, false)
                    onActivated: idx => { root.selectedIndex = idx; root.activateSelected() }
                }
            }
            ColumnLayout {
                visible: root.subview === "remove" && root.filteredRemoveList.length === 0
                Layout.fillWidth: true
                spacing: 8
                Layout.topMargin: 24
                Text {
                    text: "󰐱"
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fs(28)
                    color: Theme.textMuted
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    text: root.query !== "" ? "No results for “" + bodyRoot.scope.filterText.trim() + "”" : "No modules active"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(13)
                    color: Theme.textMuted
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }
            Repeater {
                id: removeRepeater
                model: root.subview === "remove" ? root.filteredRemoveList : []
                delegate: MenuRow {
                    selected: root.selectedIndex === index
                    glyph: ""
                    sub: root.detailFor(modelData, true)
                    onActivated: idx => { root.selectedIndex = idx; root.activateSelected() }
                }
            }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                visible: root.status.length > 0
                text: root.status
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(11)
                color: Theme.textMuted
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }
    }
}
