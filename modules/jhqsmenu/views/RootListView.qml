pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../../themes"
import "../../../Commons"
import "../../../Ui"
import "./" as Views

Item {
    id: root
    required property var scope
    required property var bodyRoot
    required property bool isListView
    anchors.fill: parent
    anchors.margins: 0
    clip: true
    opacity: root.isListView ? 1 : 0
    visible: opacity > 0.01
    enabled: root.isListView
    scale: root.isListView ? 1 : 0.98
    transformOrigin: Item.Center
    readonly property bool searching: bodyRoot.filterText.trim().length > 0
    // Shared empty model: keeps repeater model identity stable while hidden
    // (a fresh [] literal would still reset the delegates every keystroke).
    readonly property var noRows: []
    // Category in/out: crossfade both ways on the expressive curves
    // (Caelestia ContentList: opacity DefaultEffects, scale FastSpatial).
    Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durDefaultEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultEffects } }
    Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durFastSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial } }

    ScrollIndicator { flick: listFlick; show: listFlick.visible }
    Flickable {
        id: listFlick
        anchors.fill: parent
        clip: true
        visible: !root.searching
        contentHeight: resultsCol.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        interactive: true
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                let dy = event.angleDelta.y
                if (dy === 0 && event.pixelDelta.y === 0) return
                let delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : (dy > 0 ? 40 : -40)
                listFlick.contentY = Math.max(0, Math.min(listFlick.contentHeight - listFlick.height, listFlick.contentY - delta))
                event.accepted = true
            }
        }

        function ensureVisible(idx) {
            if (!root.visible || bodyRoot.totalCount === 0) return
            if (idx < 0 || idx >= bodyRoot.totalCount) return
            let rowH = 53
            let headerH = 24
            let y = idx * rowH
            let appsLen = bodyRoot.filteredApps.length
            let menuLen = bodyRoot.filteredMenu.length
            if (appsLen > 0) y += headerH
            if (bodyRoot.categoryOptionsCount > 0 && idx >= appsLen + menuLen) {
                let headers = Math.min(bodyRoot.filteredCategorySections.length, Math.max(0, idx - appsLen - menuLen))
                y += headers * headerH
            }
            let vh = listFlick.height
            let maxY = Math.max(0, listFlick.contentHeight - vh)
            if (maxY <= 0) { listFlick.contentY = 0; return }
            let cy = listFlick.contentY
            if (y < cy) listFlick.contentY = Math.max(0, y - 4)
            else if (y + rowH > cy + vh) listFlick.contentY = Math.min(maxY, y + rowH - vh + 4)
        }
        Connections {
            target: bodyRoot
            function onSelectedIndexChanged() { if (!root.searching) listFlick.ensureVisible(bodyRoot.selectedIndex) }
            function onFilterTextChanged() { listFlick.contentY = 0; if (!root.searching) Qt.callLater(() => listFlick.ensureVisible(bodyRoot.selectedIndex)) }
        }

        Column {
            id: resultsCol
            x: 0
            width: parent.width; spacing: 3
            opacity: 1
            scale: 1

            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                visible: bodyRoot.filteredApps.length > 0
                text: "Anwendungen"
                color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10); font.weight: Font.DemiBold
                width: resultsCol.width; leftPadding: 12; topPadding: 6
                font.letterSpacing: 0.8
            }
            Rectangle {
                antialiasing: Theme.shapesAa
                visible: bodyRoot.filteredApps.length > 0
                width: resultsCol.width - 14; x: 7; height: 1; color: Theme.divider; opacity: 0.5
            }
            Repeater {
                id: appRepeater
                model: root.searching ? root.noRows : bodyRoot.filteredApps
                delegate: Rectangle {
                    id: appRow
                    required property var modelData
                    required property int index
                    width: resultsCol.width
                    height: 50
                    radius: Theme.cornerRadius
                    property var entry: modelData
                    readonly property int globalIndex: index
                    readonly property bool isSelected: bodyRoot.selectedIndex === globalIndex
                    color: isSelected ? (Theme.withAlpha(Theme.textPrimary, 0.08)) : appMouse.containsMouse ? (Theme.withAlpha(Theme.textPrimary, 0.04)) : "transparent"
                    border.color: "transparent"; border.width: 0
                    Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: Theme.durSlowEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSlowEffects } }
                    // Same entrance cascade as MenuRow (browse app rows are
                    // plain Rectangles, not MenuRows).
                    opacity: 0
                    transform: Translate { id: appEnterShift; y: 6 }
                    Component.onCompleted: appEnterAnim.start()
                    SequentialAnimation {
                        id: appEnterAnim
                        PauseAnimation { duration: Math.min(Math.max(0, appRow.globalIndex), 14) * Theme.animStagger }
                        ParallelAnimation {
                            NumberAnimation { target: appRow; property: "opacity"; to: 1; duration: Theme.durDefaultEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultEffects }
                            NumberAnimation { target: appEnterShift; property: "y"; to: 0; duration: Theme.durFastSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial }
                        }
                    }
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                        Item {
                            Layout.preferredWidth: 36; Layout.preferredHeight: 18
                            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                            IconImage { anchors.centerIn: parent; width: 18; height: 18; source: Util.iconSource(entry.icon, ""); asynchronous: true; implicitSize: Qt.size(36, 36); mipmap: Theme.imageMipmap }
                        }
                        Text { text: entry.name || entry.id || "—"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(16); font.weight: Font.Medium; color: isSelected ? (Theme.accent) : (Theme.textPrimary); Layout.fillWidth: true; elide: Text.ElideRight
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }
                    }
                    MouseArea {
                        id: appMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            bodyRoot.selectedIndex = globalIndex
                            if (entry && entry.execute) {
                                entry.execute()
                                bodyRoot.scope.dismissed()
                            }
                        }
                    }
                }
            }

            Repeater {
                id: menuRepeater
                model: root.searching ? root.noRows : bodyRoot.filteredMenu
                delegate: Views.MenuRow {
                    width: resultsCol.width
                    readonly property int globalIndex: bodyRoot.filteredApps.length + index
                    isSelected: bodyRoot.selectedIndex === globalIndex
                    icon: modelData.icon || ""
                    title: modelData.title || ""
                    showArrow: true
                    arrow: (modelData.arrow && modelData.arrow.length > 0) ? modelData.arrow : ((modelData.submenu && modelData.submenu.length > 0) ? "›" : "")
                    onClicked: {
                        bodyRoot.selectedIndex = globalIndex
                        let m = modelData
                        let s = bodyRoot.scope
                        if (s.showInstall || s.showRemove || s.showStyle || s.showSession || s.showSetup || s.showLearn) s.activateCurrent()
                        else s.activateRootMenuRow(m)
                    }
                }
            }

            Repeater {
                id: catRepeater
                model: root.searching ? root.noRows : bodyRoot.filteredCategorySections
                delegate: Column {
                    id: catSection
                    required property var modelData
                    required property int index
                    width: resultsCol.width; spacing: 2
                    property int sectionOffset: { let off = bodyRoot.filteredApps.length + bodyRoot.filteredMenu.length; for (let i = 0; i < index; i++) off += bodyRoot.filteredCategorySections[i].options.length; return off }
                    Text { text: modelData.category; color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10); font.weight: Font.DemiBold; width: catSection.width; leftPadding: 12; topPadding: 12; font.letterSpacing: 0.8
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    Rectangle { width: catSection.width - 14; x: 7; height: 1; color: Theme.divider; opacity: 0.5
                        antialiasing: Theme.shapesAa
                    }
                    Repeater {
                        model: modelData.options
                        delegate: Views.MenuRow {
                            width: catSection.width
                            readonly property int globalIndex: catSection.sectionOffset + index
                            isSelected: bodyRoot.selectedIndex === globalIndex
                            icon: modelData.icon || "›"
                            title: modelData.title || ""
                            onClicked: {
                                bodyRoot.selectedIndex = globalIndex
                                let flat = bodyRoot.flattenedCategoryOptions[globalIndex - bodyRoot.filteredApps.length - bodyRoot.filteredMenu.length]
                                if (flat) bodyRoot.scope.executeCategoryOption(flat.category, flat.entry)
                            }
                        }
                    }
                }
            }

        }
    }

    // Search results are synced into a ListModel by stable `key` instead of
    // re-assigning a fresh JS array per keystroke. A JS array model resets on
    // every assignment, which destroyed/recycled every delegate — expensive,
    // and the ListView add/remove/move transitions never ran. Incremental
    // edits keep delegates alive, let those transitions animate for real and
    // cut the per-keystroke cost to a few property updates.
    ListModel { id: searchModel }

    function searchRowToEntry(r): var {
        let e = r ? r.entry : null
        let title = ""
        let sub = ""
        let icon = ""
        let iconSource = ""
        let glyph = ""
        let arrow = ""
        let showArrow = false
        if (r.row === "app") {
            title = (e && (e.name || e.id)) || "—"
            iconSource = Util.iconSource(e && e.icon, "")
        } else if (r.row === "menu") {
            title = (e && e.title) || ""
            icon = (e && e.icon) || ""
            showArrow = true
            arrow = (e && e.arrow && e.arrow.length > 0) ? e.arrow : ((e && e.submenu && e.submenu.length > 0) ? "›" : "")
        } else if (r.row === "cat") {
            title = (e && e.title) || ""
            icon = (e && e.icon) || "›"
            glyph = "›"
        } else if (r.row === "emoji") {
            title = (e && e.name) || ""
            sub = (e && e.keys) || ""
            icon = (e && e.glyph) || ""
        } else if (r.row === "math" || r.row === "units" || r.row === "gen") {
            title = r.valueText || ""
            sub = r.expr || ""
            icon = r.row === "math" ? "=" : r.row === "units" ? "↔" : "*"
        }
        return { key: r.key || "", row: r.row || "", section: r.section || "", category: r.category || "", title: title, sub: sub, icon: icon, iconSource: iconSource, glyph: glyph, arrow: arrow, showArrow: showArrow }
    }

    function updateSearchModelRow(i, w): void {
        const roles = ["title", "sub", "icon", "iconSource", "glyph", "arrow", "showArrow", "section", "row", "category"]
        const cur = searchModel.get(i)
        for (let k = 0; k < roles.length; k++) if (cur[roles[k]] !== w[roles[k]]) searchModel.setProperty(i, roles[k], w[roles[k]])
    }

    // Diff `searchRows` into the model: drop vanished keys, insert new ones,
    // move survivors to their new position and update changed fields.
    // While the browse view is showing (empty query) the model is kept empty:
    // otherwise the first keystroke would insert app rows on top of the stale
    // menu rows and the kept rows would glide across the fresh ones.
    function syncSearchModel(): void {
        if (!root.searching) {
            if (searchModel.count > 0) searchModel.clear()
            return
        }
        let rows = []
        try { rows = bodyRoot.scope.searchRows || [] } catch (e) { rows = [] }
        let want = []
        for (let i = 0; i < rows.length; i++) want.push(searchRowToEntry(rows[i]))
        for (let i = searchModel.count - 1; i >= 0; i--) {
            let k = searchModel.get(i).key
            let found = false
            for (let j = 0; j < want.length; j++) if (want[j].key === k) { found = true; break }
            if (!found) searchModel.remove(i)
        }
        for (let i = 0; i < want.length; i++) {
            let w = want[i]
            let idx = -1
            if (i < searchModel.count) {
                if (searchModel.get(i).key === w.key) { updateSearchModelRow(i, w); continue }
                for (let j = i + 1; j < searchModel.count; j++) if (searchModel.get(j).key === w.key) { idx = j; break }
            }
            if (idx === -1) searchModel.insert(i, w)
            else { searchModel.move(idx, i, 1); updateSearchModelRow(i, w) }
        }
    }
    Component.onCompleted: syncSearchModel()
    Connections {
        target: bodyRoot.scope
        function onSearchRowsChanged() { root.syncSearchModel() }
    }

    ScrollIndicator { flick: searchList; show: searchList.visible }
    ListView {
        id: searchList
        anchors.fill: parent
        visible: root.searching
        clip: true
        // No delegate reuse: pooled delegates kept animating (entrance
        // ScriptAction) after removal and lingered on screen. The model sync
        // preserves delegates across keystrokes anyway, so reuse adds little.
        reuseItems: false
        cacheBuffer: 160
        boundsBehavior: Flickable.StopAtBounds
        model: searchModel
        spacing: 3
        currentIndex: bodyRoot.selectedIndex
        // Incremental model edits now let these run for real: removed rows
        // fade out, shifting rows glide; the delegate itself plays the
        // staggered entrance whenever its content key changes.
        remove: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durDefaultEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultEffects }
        }
        move: Transition {
            NumberAnimation { property: "y"; duration: Theme.durDefaultSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultSpatial }
            NumberAnimation { property: "opacity"; to: 1; duration: Theme.durDefaultEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultEffects }
        }
        displaced: Transition {
            NumberAnimation { property: "y"; duration: Theme.durDefaultSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultSpatial }
            NumberAnimation { property: "opacity"; to: 1; duration: Theme.durDefaultEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultEffects }
        }
        section.property: "section"
        section.delegate: Item {
            required property string section
            width: searchList.width
            height: section === "" ? 0 : 24
            visible: section !== ""
            Column {
                anchors.fill: parent; spacing: 2
                Text {
                    text: section; color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10); font.weight: Font.DemiBold
                    width: parent.width; leftPadding: 12; topPadding: 6; font.letterSpacing: 0.8
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                Rectangle { width: parent.width - 14; x: 7; height: 1; color: Theme.divider; opacity: 0.5 }
            }
        }
        delegate: Item {
            id: searchRowDelegate
            required property int index
            required property string key
            required property string row
            required property string section
            required property string category
            required property string title
            required property string sub
            required property string icon
            required property string iconSource
            required property string glyph
            required property string arrow
            required property bool showArrow
            width: searchList.width
            height: rowItem.height
            // Result entrance: a row rises + fades in when it is created or
            // its content key changes. Rows that keep their key only move
            // (ListView move/displaced), so typing never replays the list.
            opacity: 1
            transform: Translate { id: searchEnterShift; y: 0 }
            function playEnter(): void {
                if (!Theme.animationsEnabled) { searchEnterShift.y = 0; searchRowDelegate.opacity = 1; return }
                searchEnterAnim.restart()
            }
            onKeyChanged: playEnter()
            Component.onCompleted: playEnter()
            SequentialAnimation {
                id: searchEnterAnim
                ScriptAction { script: { searchRowDelegate.opacity = 0; searchEnterShift.y = 6 } }
                PauseAnimation { duration: Math.min(Math.max(0, searchRowDelegate.index), 6) * Theme.animStagger }
                ParallelAnimation {
                    NumberAnimation { target: searchRowDelegate; property: "opacity"; to: 1; duration: Theme.durDefaultEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultEffects }
                    NumberAnimation { target: searchEnterShift; property: "y"; to: 0; duration: Theme.durFastSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial }
                }
            }
            Views.MenuRow {
                id: rowItem
                x: 0
                width: searchRowDelegate.width
                // Required props must be set explicitly here: unlike the
                // browse repeaters (where MenuRow IS the delegate and gets
                // them implicitly), this nested instance gets nothing unless
                // assigned — otherwise it fails to instantiate (blank rows).
                modelData: null
                index: searchRowDelegate.index
                iconSource: searchRowDelegate.iconSource
                icon: searchRowDelegate.icon
                title: searchRowDelegate.title
                sub: searchRowDelegate.sub
                glyph: searchRowDelegate.glyph
                arrow: searchRowDelegate.arrow
                showArrow: searchRowDelegate.showArrow
                isSelected: bodyRoot.selectedIndex === searchRowDelegate.index
                enterOnCreate: false
                onClicked: {
                    bodyRoot.selectedIndex = searchRowDelegate.index
                    let r = bodyRoot.scope.searchRowForKey(searchRowDelegate.key)
                    if (!r) return
                    let sc = bodyRoot.scope
                    if (r.row === "app") { sc.launchAppEntry(r.entry); return }
                    if (r.row === "menu") {
                        // Inside a submenu (e.g. System with a filter typed)
                        // rows must go through activateCurrent() like the
                        // browse list does — activateRootMenuRow() only knows
                        // the root titles (Apps/Style/System/...).
                        if (sc.showStyle || sc.showInstall || sc.showRemove || sc.showSession || sc.showSetup || sc.showLearn) { sc.activateCurrent(); return }
                        sc.activateRootMenuRow(r.entry); return
                    }
                    if (r.row === "cat") { sc.executeCategoryOption(r.category, r.entry); return }
                    if (r.row === "math") { sc.copyMathResult(); return }
                    if (r.row === "units" || r.row === "gen") { if (r.valueText) sc.copyToClipboard(r.valueText); return }
                    if (r.row === "emoji") { if (r.entry && r.entry.glyph) sc.copyToClipboard(r.entry.glyph); return }
                }
            }
        }
        Connections {
            target: bodyRoot
            function onSelectedIndexChanged() { if (searchList.visible && searchList.count > 0) searchList.positionViewAtIndex(Math.max(0, Math.min(bodyRoot.selectedIndex, searchList.count - 1)), ListView.Contain) }
            function onFilterTextChanged() { searchList.contentY = 0 }
        }
    }

    Column {
        visible: root.searching && bodyRoot.scope.searchRows.length === 0
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        anchors.topMargin: 24
        spacing: 8
        Text { text: "󰍉"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(28); color: Theme.textMuted; width: parent.width; horizontalAlignment: Text.AlignHCenter
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
        }
        Text { text: "No results"; color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13); width: parent.width; horizontalAlignment: Text.AlignHCenter
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
        }
        Text { text: "Try a different search term"; color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11); width: parent.width; horizontalAlignment: Text.AlignHCenter; opacity: 0.7
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
        }
    }
}
