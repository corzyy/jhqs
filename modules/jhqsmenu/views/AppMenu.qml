pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../../themes"
import "../../../Commons"
import "../../../Ui"

// App launcher (JhqsMenu > Apps). Rewritten on the jhqsmenu motion language:
//  - view root: category fade + settle scale (DefaultEffects / FastSpatial)
//  - content stage: menu-open fade/rise/scale driven by the menu spring
//    (`menuFade`), so opening straight into Apps never desyncs the shell
//  - rows: app-list cascade (staggered rise + fade) plus ListView
//    add/remove/move/displaced transitions for filter changes
//  - context menu (right-click): Open + .desktop actions on StateLayer rows,
//    fading/scaling in on the expressive curves; Up/Down/Enter/Esc handled
//    through handleKey() while it is open
Item {
    id: root
    required property var scope
    required property var bodyRoot
    // Menu-open driver (bound to the menu spring grow by JhqsMenu).
    // Defaults to open so the view still renders outside the menu.
    property real menuFade: 1

    anchors.fill: parent
    anchors.margins: 0
    clip: true
    opacity: bodyRoot.scope.showNewAppMenu ? 1 : 0
    visible: opacity > 0.01
    enabled: bodyRoot.scope.showNewAppMenu
    scale: bodyRoot.scope.showNewAppMenu ? 1 : 0.97
    transformOrigin: Item.Center
    Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durDefaultEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultEffects } }
    Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durFastSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial } }

    readonly property int appCount: bodyRoot.scope.filteredNewApps.length
    readonly property string countLabel: {
        if (bodyRoot.scope.filterText.length > 0) {
            let n = root.appCount
            return n === 0 ? "No results" : n + (n === 1 ? " App" : " Apps")
        }
        return "Anwendungen"
    }

    // ---- context menu state (right-click on a row) ----------------------
    property var contextMenuEntry: null
    property bool contextMenuVisible: false
    property point contextMenuPos: Qt.point(0, 0)
    property int contextMenuSelectedIndex: 0
    readonly property int contextMenuCount: 1 + ((root.contextMenuEntry && root.contextMenuEntry.actions) ? root.contextMenuEntry.actions.length : 0)

    function showContextMenu(entry, mouse, item) {
        let p = item.mapToItem(root, mouse.x, mouse.y)
        contextMenuPos = Qt.point(p.x + 8, p.y + 8)
        contextMenuEntry = entry
        contextMenuSelectedIndex = 0
        contextMenuVisible = true
    }
    function hideContextMenu() { contextMenuVisible = false; contextMenuEntry = null; contextMenuSelectedIndex = 0 }
    function activateContextMenuSelected() {
        if (!contextMenuEntry) return
        let actions = contextMenuEntry.actions || []
        if (contextMenuSelectedIndex === 0) {
            if (contextMenuEntry.execute) contextMenuEntry.execute()
        } else {
            let act = actions[contextMenuSelectedIndex - 1]
            if (act && act.execute) act.execute()
        }
        hideContextMenu()
        scope.dismissed()
    }
    // The open context menu owns Up/Down/Enter/Esc; every other key (and all
    // keys while it is closed) falls through to the shell list handling.
    function handleKey(event): bool {
        if (!root.contextMenuVisible) return false
        let n = root.contextMenuCount
        if (event.key === Qt.Key_Down) { root.contextMenuSelectedIndex = (root.contextMenuSelectedIndex + 1) % n; return true }
        if (event.key === Qt.Key_Up) { root.contextMenuSelectedIndex = (root.contextMenuSelectedIndex - 1 + n) % n; return true }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.activateContextMenuSelected(); return true }
        if (event.key === Qt.Key_Escape) { root.hideContextMenu(); return true }
        return false
    }

    // Content stage: same menu-open motion as the menu shell inner stage
    // (and PanelShell): partial fade + rise + settle scale, driven directly
    // by the menu spring so open/close and content motion never desync.
    // Multiplies the category-switch fade on the root instead of replacing
    // it, so switching categories mid-open stays smooth.
    Item {
        id: contentStage
        anchors.fill: parent
        opacity: 0.35 + 0.65 * root.menuFade
        scale: 0.97 + 0.03 * root.menuFade
        transformOrigin: Item.Top
        transform: Translate { y: (1 - root.menuFade) * 10 }

        // Section header — same language as RootListView/FontView:
        // 10px DemiBold muted + hairline divider.
        Column {
            id: appHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 2
            RowLayout {
                width: parent.width
                height: 24
                spacing: 6
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    text: root.countLabel
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(10)
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                    Layout.fillWidth: true
                    leftPadding: 12
                    topPadding: 6
                    elide: Text.ElideRight
                }
            }
            Rectangle {
                width: parent.width - 14
                x: 7
                height: 1
                color: Theme.divider
                opacity: 0.5
                antialiasing: Theme.shapesAa
            }
        }

        ScrollIndicator { flick: appList }
        ListView {
            id: appList
            anchors.top: appHeader.bottom
            anchors.topMargin: 3
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true
            // PERF: recycle delegates (was create-all on every filter keystroke).
            reuseItems: true
            cacheBuffer: 200
            boundsBehavior: Flickable.StopAtBounds
            model: bodyRoot.scope.filteredNewApps
            spacing: 3
            currentIndex: bodyRoot.selectedIndex
            // Caelestia AppList item motion: fade on add/remove, glide on move.
            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durDefaultEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultEffects }
            }
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
            delegate: Rectangle {
                id: appRow
                required property var modelData
                required property int index
                width: appList.width
                height: 50
                radius: Theme.cornerRadius
                readonly property var entry: modelData
                readonly property bool isSelected: bodyRoot.selectedIndex === index
                color: isSelected ? (Theme.withAlpha(Theme.textPrimary, 0.08)) : rowMouse.containsMouse ? (Theme.withAlpha(Theme.textPrimary, 0.04)) : "transparent"
                border.color: "transparent"; border.width: 0
                Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: Theme.durSlowEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSlowEffects } }
                // Entrance cascade: rows rise + fade in with a per-index
                // stagger when the launcher opens (same as MenuRow/RootListView).
                opacity: 0
                transform: Translate { id: enterShift; y: 6 }
                Component.onCompleted: enterAnim.start()
                SequentialAnimation {
                    id: enterAnim
                    PauseAnimation { duration: Math.min(Math.max(0, appRow.index), 14) * Theme.animStagger }
                    ParallelAnimation {
                        NumberAnimation { target: appRow; property: "opacity"; to: 1; duration: Theme.durDefaultEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultEffects }
                        NumberAnimation { target: enterShift; property: "y"; to: 0; duration: Theme.durFastSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial }
                    }
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                    Item {
                        Layout.preferredWidth: 36; Layout.preferredHeight: 18
                        Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                        IconImage { anchors.centerIn: parent; width: 18; height: 18; source: Util.iconSource(entry && entry.icon, ""); asynchronous: true; implicitSize: Qt.size(36, 36); mipmap: Theme.imageMipmap }
                    }
                    Text {
                        text: (entry && (entry.name || entry.id)) || "—"
                        font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(16); font.weight: Font.Medium
                        color: isSelected ? Theme.accent : Theme.textPrimary
                        Layout.fillWidth: true; elide: Text.ElideRight
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            bodyRoot.selectedIndex = appRow.index
                            root.showContextMenu(appRow.entry, mouse, rowMouse)
                        } else {
                            bodyRoot.selectedIndex = appRow.index
                            if (appRow.entry && appRow.entry.execute) { appRow.entry.execute(); bodyRoot.scope.dismissed() }
                        }
                    }
                }
            }
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: 0
            preferredHighlightEnd: height - (53)

            Connections {
                target: bodyRoot
                function onSelectedIndexChanged() { appList.positionViewAtIndex(bodyRoot.selectedIndex, ListView.Contain) }
                function onFilterTextChanged() { appList.contentY = 0; root.hideContextMenu(); Qt.callLater(() => appList.positionViewAtIndex(bodyRoot.selectedIndex, ListView.Contain)) }
            }
            Connections {
                target: bodyRoot.scope
                function onShowNewAppMenuChanged() {
                    if (bodyRoot.scope.showNewAppMenu) {
                        appList.contentY = 0
                        Qt.callLater(() => appList.positionViewAtIndex(bodyRoot.selectedIndex, ListView.Contain))
                    } else root.hideContextMenu()
                }
                function onFilteredNewAppsChanged() { appList.contentY = 0; root.hideContextMenu() }
            }
        }

        // Empty state — same shape as FontView/RootListView empty columns.
        Column {
            visible: appList.count === 0
            anchors.top: appHeader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 24
            spacing: 8
            Text {
                text: "󰀻"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(28); color: Theme.textMuted
                width: parent.width; horizontalAlignment: Text.AlignHCenter
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            Text {
                text: bodyRoot.scope.filterText.length > 0 ? "No results" : "No apps"
                color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13)
                width: parent.width; horizontalAlignment: Text.AlignHCenter
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            Text {
                visible: bodyRoot.scope.filterText.length > 0
                text: "Try a different search term"
                color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11)
                width: parent.width; horizontalAlignment: Text.AlignHCenter; opacity: 0.7
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
        }
    }

    // Click catcher: any press outside the context menu dismisses it.
    MouseArea { anchors.fill: parent; visible: root.contextMenuVisible; z: 90; onClicked: root.hideContextMenu() }

    // Context menu card: fades/scales out from the row on the expressive
    // curves; rows are StateLayer surfaces with keyboard selection.
    component ContextRow: Rectangle {
        id: contextRow
        required property string label
        property string glyph: ""
        property bool isSelected: false
        property var action: null
        signal hovered()
        signal triggered()
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        radius: Theme.cornerRadiusSmall
        color: isSelected ? Theme.withAlpha(Theme.textPrimary, 0.08) : "transparent"
        border.color: "transparent"; border.width: 0
        antialiasing: Theme.shapesAa
        Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: Theme.durSlowEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSlowEffects } }
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 8
            Text {
                visible: contextRow.glyph !== ""
                text: contextRow.glyph
                font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(12); color: Theme.textMuted
                Layout.preferredWidth: visible ? 14 : 0; horizontalAlignment: Text.AlignHCenter
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            IconImage {
                visible: contextRow.action && contextRow.action.icon !== ""
                Layout.preferredWidth: 14; Layout.preferredHeight: 14
                source: contextRow.action ? Util.iconSource(contextRow.action.icon, "") : ""
                asynchronous: true; implicitSize: Qt.size(28, 28); mipmap: Theme.imageMipmap
            }
            Text {
                text: contextRow.label
                font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(12); color: contextRow.isSelected ? Theme.accent : Theme.textPrimary
                Layout.fillWidth: true; elide: Text.ElideRight
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
        }
        StateLayer {
            color: contextRow.isSelected ? Theme.accent : Theme.textPrimary
            radius: contextRow.radius
            onContainsMouseChanged: if (containsMouse) contextRow.hovered()
            onClicked: contextRow.triggered()
        }
    }
    Item {
        id: contextMenu
        visible: root.contextMenuVisible && root.contextMenuEntry !== null
        x: Math.min(root.width - width - 8, Math.max(8, root.contextMenuPos.x))
        y: Math.min(root.height - height - 8, Math.max(8, root.contextMenuPos.y))
        width: 220
        implicitHeight: contextMenuLayout.implicitHeight + 12
        height: implicitHeight
        z: 100
        opacity: visible ? 1 : 0
        scale: visible ? 1 : 0.96
        transformOrigin: Item.TopLeft
        Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durDefaultEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultEffects } }
        Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durFastSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial } }
        Rectangle {
            id: contextMenuCard
            anchors.fill: parent
            radius: Theme.cornerRadius
            color: Theme.bg
            border.color: Theme.panelBorderColor; border.width: 1
            clip: true
            antialiasing: Theme.shapesAa
            ColumnLayout {
                id: contextMenuLayout
                anchors.fill: parent; anchors.margins: 6; spacing: 2
                RowLayout {
                    Layout.fillWidth: true; Layout.preferredHeight: 32; spacing: 8
                    IconImage { Layout.preferredWidth: 18; Layout.preferredHeight: 18; source: Util.iconSource(root.contextMenuEntry && root.contextMenuEntry.icon, ""); asynchronous: true; implicitSize: Qt.size(36, 36); mipmap: Theme.imageMipmap }
                    Text {
                        text: root.contextMenuEntry ? (root.contextMenuEntry.name || root.contextMenuEntry.id) : ""
                        color: Theme.textPrimary; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(12)
                        Layout.fillWidth: true; elide: Text.ElideRight
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; height: 1; color: Theme.divider; opacity: 0.5
                    antialiasing: Theme.shapesAa
                }
                ContextRow {
                    label: "Open"; glyph: "↗"
                    isSelected: root.contextMenuSelectedIndex === 0
                    onHovered: root.contextMenuSelectedIndex = 0
                    onTriggered: { root.contextMenuSelectedIndex = 0; root.activateContextMenuSelected() }
                }
                Repeater {
                    model: root.contextMenuEntry ? (root.contextMenuEntry.actions || []) : []
                    delegate: ContextRow {
                        required property var modelData
                        required property int index
                        label: modelData ? (modelData.name || modelData.id || "") : ""
                        action: modelData
                        isSelected: root.contextMenuSelectedIndex === index + 1
                        onHovered: root.contextMenuSelectedIndex = index + 1
                        onTriggered: { root.contextMenuSelectedIndex = index + 1; root.activateContextMenuSelected() }
                    }
                }
            }
        }
    }
}
