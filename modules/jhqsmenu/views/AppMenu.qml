pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../../themes"
import "../../../Ui"

Item {
    id: root
    required property var scope
    required property var bodyRoot
    anchors.fill: parent
    anchors.margins: 0
    clip: true
    opacity: bodyRoot.scope.showNewAppMenu ? 1 : 0
    visible: opacity > 0.01
    enabled: bodyRoot.scope.showNewAppMenu

    property var contextMenuEntry: null
    property bool contextMenuVisible: false
    property point contextMenuPos: Qt.point(0, 0)
    property int contextMenuSelectedIndex: 0
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
            if (contextMenuEntry.execute) { contextMenuEntry.execute() }
            hideContextMenu(); scope.dismissed()
        } else {
            let act = actions[contextMenuSelectedIndex - 1]
            if (act && act.execute) act.execute()
            hideContextMenu(); scope.dismissed()
        }
    }

    ScrollIndicator { flick: appList }
    ListView {
        id: appList
        anchors.fill: parent
        anchors.topMargin: 0
        anchors.leftMargin: 0; anchors.rightMargin: 0
        clip: true
        // PERF: recycle delegates (was create-all on every filter keystroke).
        reuseItems: true
        cacheBuffer: 200
        boundsBehavior: Flickable.StopAtBounds
        model: bodyRoot.scope.filteredNewApps
        spacing: 3
        currentIndex: bodyRoot.selectedIndex
        delegate: Rectangle {
            id: rowBg
            required property var modelData
            required property int index
            width: appList.width
            height: 50
            radius: 0
            readonly property var entry: modelData
            readonly property bool isSelected: bodyRoot.selectedIndex === index
            color: isSelected ? (Theme.withAlpha(Theme.textPrimary, 0.08)) : rowMouse.containsMouse ? (Theme.withAlpha(Theme.textPrimary, 0.04)) : "transparent"
            Rectangle {
                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                width: 3
                color: Theme.accent
                visible: isSelected
            }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                IconImage { width: 20; height: 20; source: entry && entry.icon ? Quickshell.iconPath(entry.icon || "") : ""; asynchronous: true; visible: entry && entry.icon; implicitSize: Qt.size(36, 36); mipmap: Theme.imageMipmap }
                Text { visible: true; text: entry.name || entry.id || "—"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(16); font.weight: Font.Medium; color: isSelected ? Theme.accent : Theme.textSecondary; Layout.fillWidth: true; elide: Text.ElideRight
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
            }
            MouseArea {
                id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        bodyRoot.selectedIndex = index
                        root.showContextMenu(entry, mouse, rowMouse)
                    } else {
                        bodyRoot.selectedIndex = index
                        if (entry && entry.execute) { entry.execute(); bodyRoot.scope.dismissed() }
                    }
                }
            }
        }
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: 0
        preferredHighlightEnd: height - (53)

        ColumnLayout {
            visible: appList.count === 0
            anchors.centerIn: parent
            spacing: 4
            Text { text: "—"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(16); color: Theme.textMuted; Layout.alignment: Qt.AlignHCenter
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            Text { text: bodyRoot.scope.filterText.length > 0 ? "Keine Treffer" : "Keine Apps"; color: Theme.textMuted; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(11); Layout.alignment: Qt.AlignHCenter
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
        }

        Connections {
            target: bodyRoot
            function onSelectedIndexChanged() { appList.positionViewAtIndex(bodyRoot.selectedIndex, ListView.Contain) }
            function onFilterTextChanged() { appList.contentY = 0; Qt.callLater(() => appList.positionViewAtIndex(bodyRoot.selectedIndex, ListView.Contain)) }
        }
        Connections {
            target: bodyRoot.scope
            function onShowNewAppMenuChanged() {
                if (bodyRoot.scope.showNewAppMenu) {
                    appList.contentY = 0
                    Qt.callLater(() => appList.positionViewAtIndex(bodyRoot.selectedIndex, ListView.Contain))
                } else root.hideContextMenu()
            }
            function onFilteredNewAppsChanged() { appList.contentY = 0 }
        }
    }

    MouseArea { anchors.fill: parent; visible: root.contextMenuVisible; z: 90; onClicked: root.hideContextMenu(); propagateComposedEvents: false }
    Item {
        id: contextMenu
        visible: root.contextMenuVisible && root.contextMenuEntry !== null
        x: Math.min(root.width - width - 8, Math.max(8, root.contextMenuPos.x))
        y: Math.min(root.height - height - 8, Math.max(8, root.contextMenuPos.y))
        width: 220; implicitHeight: menuInner.implicitHeight + 8; height: implicitHeight; z: 100
        opacity: visible ? 1 : 0
        Rectangle {
            antialiasing: Theme.shapesAa
            id: menuInner
            anchors.fill: parent; anchors.margins: 1; radius: 0; color: Theme.bg; border.color: Theme.panelBorderColor; border.width: 1; clip: true
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 4; spacing: 1
                RowLayout {
                    Layout.fillWidth: true; Layout.preferredHeight: 32; spacing: 8
                    IconImage { Layout.preferredWidth: 18; Layout.preferredHeight: 18; source: root.contextMenuEntry && root.contextMenuEntry.icon ? Quickshell.iconPath(root.contextMenuEntry.icon) : ""; asynchronous: true; visible: root.contextMenuEntry && root.contextMenuEntry.icon; implicitSize: Qt.size(36, 36); mipmap: Theme.imageMipmap }
                    Text { text: root.contextMenuEntry ? (root.contextMenuEntry.name || root.contextMenuEntry.id) : ""; color: Theme.textPrimary; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(12); Layout.fillWidth: true; elide: Text.ElideRight
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.divider; opacity: 0.5
                    antialiasing: Theme.shapesAa
                }
                Rectangle {
                    antialiasing: Theme.shapesAa
                    Layout.fillWidth: true; Layout.preferredHeight: 30; radius: 0
                    color: root.contextMenuSelectedIndex === 0 ? (Theme.withAlpha(Theme.textPrimary, 0.08)) : openMouse.containsMouse ? (Theme.withAlpha(Theme.textPrimary, 0.04)) : "transparent"
                    Rectangle {
                        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                        width: 3
                        color: Theme.accent
                        visible: root.contextMenuSelectedIndex === 0
                    }
                    RowLayout { anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 8; Text { text: "↗"; font.pixelSize: Theme.fs(12); color: Theme.textMuted
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        } Text { text: "Öffnen"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(12); color: root.contextMenuSelectedIndex === 0 ? Theme.accent : Theme.textPrimary; Layout.fillWidth: true
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        } }
                    MouseArea { id: openMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: root.contextMenuSelectedIndex = 0; onClicked: { root.contextMenuSelectedIndex = 0; root.activateContextMenuSelected() } }
                }
                Repeater {
                    model: root.contextMenuEntry ? root.contextMenuEntry.actions : []
                    delegate: Rectangle {
                        required property var modelData; required property int index; property var action: modelData
                        Layout.fillWidth: true; Layout.preferredHeight: 30; radius: 0
                        color: root.contextMenuSelectedIndex === index + 1 ? (Theme.withAlpha(Theme.textPrimary, 0.08)) : actMouse.containsMouse ? (Theme.withAlpha(Theme.textPrimary, 0.04)) : "transparent"
                        Rectangle {
                            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                            width: 3
                            color: Theme.accent
                            visible: root.contextMenuSelectedIndex === index + 1
                        }
                        RowLayout { anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 8; IconImage { Layout.preferredWidth: 14; Layout.preferredHeight: 14; source: action && action.icon ? Quickshell.iconPath(action.icon) : ""; visible: action && action.icon; asynchronous: true; implicitSize: Qt.size(28, 28); mipmap: Theme.imageMipmap } Text { text: action ? (action.name || action.id) : ""; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(12); color: root.contextMenuSelectedIndex === index + 1 ? Theme.accent : Theme.textPrimary; Layout.fillWidth: true; elide: Text.ElideRight
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            } }
                        MouseArea { id: actMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: root.contextMenuSelectedIndex = index + 1; onClicked: { root.contextMenuSelectedIndex = index + 1; root.activateContextMenuSelected() } }
                    }
                }
            }
        }
    }
}
