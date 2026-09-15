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
    opacity: bodyRoot.scope.showFont ? 1 : 0
    visible: opacity > 0.01
    enabled: bodyRoot.scope.showFont
    Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }

    property var navItems: {
        let list = bodyRoot.scope.filteredFontGroups
        let arr = []
        if (!list) return arr
        for (let i = 0; i < list.length; i++) arr.push({id: "fontgroup-" + list[i].title, type: "fontgroup", data: list[i]})
        return arr
    }
    property int navCount: navItems.length
    property int selectedIndex: 0
    readonly property bool isLoading: bodyRoot.scope.fontLoading || bodyRoot.scope.fontRescanning
    readonly property string countLabel: {
        if (root.isLoading) return bodyRoot.scope.fontRescanning ? "Scanning fonts…" : "Loading fonts…"
        let n = root.navCount
        if (n === 0) return "Fonts"
        return n + (n === 1 ? " Font" : " Fonts")
    }
    onNavCountChanged: { if (root.selectedIndex > root.navCount - 1) root.selectedIndex = Math.max(0, root.navCount - 1); root.ensureVisible() }
    onSelectedIndexChanged: root.ensureVisible()

    function navIndex(id: string): int {
        let items = root.navItems
        for (let i = 0; i < items.length; i++) if (items[i].id === id) return i
        return -1
    }
    function isSelected(groupTitle: string): bool { return root.navIndex("fontgroup-" + groupTitle) === root.selectedIndex }
    function selectedGroup() {
        let it = root.navItems[root.selectedIndex]
        return it ? it.data : null
    }
    function ensureVisible() {
        if (root.selectedIndex < 0 || root.selectedIndex >= root.navCount) return
        fontList.positionViewAtIndex(root.selectedIndex, ListView.Visible)
    }
    function moveSelection(delta: int) {
        if (root.navCount === 0) return
        root.selectedIndex = (root.selectedIndex + delta + root.navCount) % root.navCount
    }
    function activateSelected() {
        let g = root.selectedGroup()
        if (g) bodyRoot.scope.setSystemFont(g.preview || g.title)
    }
    function handleKey(event): bool {
        if (event.key === Qt.Key_F5) { bodyRoot.scope.rescanFonts(); return true }
        if (event.key === Qt.Key_R && (event.modifiers & Qt.ControlModifier)) { bodyRoot.scope.rescanFonts(); return true }
        if (event.key === Qt.Key_Down) { root.moveSelection(1); return true }
        if (event.key === Qt.Key_Up) { root.moveSelection(-1); return true }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.activateSelected(); return true }
        if (event.key === Qt.Key_Home) { root.selectedIndex = 0; return true }
        if (event.key === Qt.Key_End) { root.selectedIndex = root.navCount - 1; return true }
        return false
    }

    Connections {
        target: bodyRoot.scope
        function onShowFontChanged() {
            if (bodyRoot.scope.showFont) { root.selectedIndex = 0; fontList.positionViewAtBeginning() }
        }
        function onFilterTextChanged() { root.selectedIndex = 0; fontList.positionViewAtBeginning() }
    }

    // Section header — same language as RootListView ("Anwendungen"):
    // 10px DemiBold muted + hairline divider, reload as subtle text action.
    Column {
        id: fontHeader
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
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                text: root.isLoading ? "…" : "󰑓 Reload"
                color: reloadMouse.containsMouse && !root.isLoading ? Theme.textPrimary : Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(10)
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
                rightPadding: 12
                topPadding: 6
                opacity: root.isLoading ? 0.5 : 1
                MouseArea {
                    id: reloadMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !root.isLoading
                    onClicked: bodyRoot.scope.rescanFonts()
                }
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

    ScrollIndicator { flick: fontList }
    ListView {
        id: fontList
        anchors.top: fontHeader.bottom
        anchors.topMargin: 3
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 300
        // PERF: recycle delegates (each row rasters a distinct font family).
        reuseItems: true
        spacing: 3
        model: bodyRoot.scope.filteredFontGroups
        delegate: Rectangle {
            required property var modelData
            required property int index
            property var groupData: modelData
            property string groupTitle: (groupData && groupData.title) || ""
            property string previewFamily: (groupData && groupData.preview) || groupTitle
            property string activeVariant: bodyRoot.scope.fontGroupActiveVariant(groupData)
            property bool isActive: activeVariant !== ""
            property bool isSelected: index === root.selectedIndex
            property string displayFamily: isActive ? activeVariant : previewFamily
            width: fontList.width
            height: 58
            radius: Theme.cornerRadius
            color: isSelected ? Theme.withAlpha(Theme.textPrimary, 0.08) : rowMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.04) : "transparent"
            border.color: "transparent"
            border.width: 0
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 3
                radius: Theme.cornerRadius
                antialiasing: Theme.shapesAa
                color: Theme.accent
                visible: isSelected
            }
            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.selectedIndex = root.navIndex("fontgroup-" + groupTitle); bodyRoot.scope.setSystemFont(previewFamily) }
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 6
                Text {
                    text: "Aa"
                    font.family: displayFamily
                    font.pixelSize: Theme.fs(18)
                    color: isSelected ? Theme.accent : Theme.textPrimary
                    Layout.preferredWidth: 36
                    horizontalAlignment: Text.AlignHCenter
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    Text {
                        text: groupTitle
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.fs(16)
                        font.weight: Font.Medium
                        color: isSelected ? Theme.accent : Theme.textPrimary
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    Text {
                        text: "Aa Bb Cc 123"
                        font.family: displayFamily
                        font.pixelSize: Theme.fs(11)
                        color: Theme.textPrimary
                        opacity: 0.52
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                }
                Text {
                    visible: isActive
                    text: "✓"
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fs(14)
                    color: Theme.accent
                    Layout.preferredWidth: 14
                    horizontalAlignment: Text.AlignHCenter
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
            }
        }
        footer: Item {
            width: fontList.width
            height: fontList.count === 0 ? 120 : 0
            visible: fontList.count === 0
            clip: true
            Column {
                anchors.top: parent.top
                anchors.topMargin: 24
                width: parent.width
                spacing: 8
                Text {
                    text: "󰛖"
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fs(28)
                    color: Theme.textMuted
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                Text {
                    text: root.isLoading ? "Loading fonts…" : "No results"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(13)
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                Text {
                    visible: !root.isLoading
                    text: "Try a different search term"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(11)
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    opacity: 0.7
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
            }
        }
    }
}
