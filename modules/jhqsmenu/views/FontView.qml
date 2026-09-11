pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../../themes"

Item {
    id: root
    required property var scope
    required property var bodyRoot
    anchors.fill: parent
    anchors.margins: 4
    clip: true
    opacity: bodyRoot.scope.showFont ? 1 : 0
    visible: opacity > 0.01
    enabled: bodyRoot.scope.showFont

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
    readonly property int totalVariants: {
        let n = 0
        try {
            let l = bodyRoot.scope.filteredFontGroups
            if (l) for (let i = 0; i < l.length; i++) n += ((l[i] && l[i].variants) ? l[i].variants.length : 0)
        } catch(e) { }
        return n
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
    function expandSelected() {
        let g = root.selectedGroup()
        if (!g || !(g.variants && g.variants.length > 1)) return
        if (bodyRoot.scope.fontExpanded !== g.title) bodyRoot.scope.toggleFontExpanded(g.title)
    }
    function collapseSelected() {
        if (bodyRoot.scope.fontExpanded !== "") bodyRoot.scope.toggleFontExpanded(bodyRoot.scope.fontExpanded)
    }
    function handleKey(event): bool {
        if (event.key === Qt.Key_F5) { bodyRoot.scope.rescanFonts(); return true }
        if (event.key === Qt.Key_R && (event.modifiers & Qt.ControlModifier)) { bodyRoot.scope.rescanFonts(); return true }
        if (event.key === Qt.Key_Down) { root.moveSelection(1); return true }
        if (event.key === Qt.Key_Up) { root.moveSelection(-1); return true }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.activateSelected(); return true }
        if (event.key === Qt.Key_Right) { root.expandSelected(); return true }
        if (event.key === Qt.Key_Left) { root.collapseSelected(); return true }
        if (event.key === Qt.Key_Home) { root.selectedIndex = 0; return true }
        if (event.key === Qt.Key_End) { root.selectedIndex = root.navCount - 1; return true }
        if (event.key === Qt.Key_Escape) {
            if (bodyRoot.scope.fontExpanded !== "") { root.collapseSelected(); return true }
            return false
        }
        return false
    }

    Connections {
        target: bodyRoot.scope
        function onShowFontChanged() {
            if (bodyRoot.scope.showFont) { root.selectedIndex = 0; bodyRoot.scope.fontExpanded = ""; fontList.positionViewAtBeginning() }
        }
        function onFilterTextChanged() { root.selectedIndex = 0; fontList.positionViewAtBeginning() }
    }

    RowLayout {
        id: fontHeader
        anchors.top: parent.top; anchors.topMargin: 6; anchors.left: parent.left; anchors.right: parent.right
        anchors.leftMargin: 6; anchors.rightMargin: 6
        spacing: 8
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            text: root.isLoading ? (bodyRoot.scope.fontRescanning ? "Scanne Fonts…" : "Lade Fonts…") : (root.navCount + (root.navCount === 1 ? " Schrift • " : " Schriften • ") + root.totalVariants + (root.totalVariants === 1 ? " Schnitt" : " Schnitte"))
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11); color: Theme.textMuted
            Layout.fillWidth: true; elide: Text.ElideRight
        }
        Rectangle {
            antialiasing: Theme.shapesAa
            Layout.preferredWidth: 112; Layout.preferredHeight: 28; radius: Theme.cornerRadiusSmall
            color: reloadMouse.containsMouse && !root.isLoading ? Theme.bgHover : Theme.panelSurface
            border.color: Theme.divider; border.width: 1
            opacity: root.isLoading ? 0.5 : 1
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 6
                Text { text: "󰑓"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(13); color: Theme.textSecondary; Layout.preferredWidth: 16; horizontalAlignment: Text.AlignHCenter
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                Text { text: "Neu laden"; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11); font.weight: Font.Medium; color: Theme.textSecondary; Layout.fillWidth: true; elide: Text.ElideRight
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
            }
            MouseArea { id: reloadMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: !root.isLoading; onClicked: bodyRoot.scope.rescanFonts() }
        }
    }

    ListView {
        id: fontList
        anchors.top: fontHeader.bottom; anchors.topMargin: 4; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.leftMargin: 6; anchors.rightMargin: 6
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 160
        spacing: 4
        model: bodyRoot.scope.filteredFontGroups
        delegate: ColumnLayout {
            required property var modelData
            required property int index
            anchors.left: parent.left
            anchors.right: parent.right
            property var groupData: modelData
            property string groupTitle: (groupData && groupData.title) || ""
            property string previewFamily: (groupData && groupData.preview) || groupTitle
            property var variants: (groupData && groupData.variants) || []
            property string activeVariant: bodyRoot.scope.fontGroupActiveVariant(groupData)
            property bool isActive: activeVariant !== ""
            property bool isSelected: index === root.selectedIndex
            property bool isExpanded: variants.length > 1 && bodyRoot.scope.fontExpanded === groupTitle
            property string displayFamily: isActive ? activeVariant : previewFamily
            property string activeLabel: isActive ? bodyRoot.scope.fontVariantLabel(activeVariant, groupTitle) : ""
            spacing: 2
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            Layout.fillWidth: true
                            Layout.preferredHeight: 56
                            radius: Theme.cornerRadiusSmall
                            color: isSelected ? Theme.bgSelected : isActive ? Theme.panelSurface : rowMouse.containsMouse ? Theme.panelSurface : Theme.panelBg
                            border.color: isSelected ? Theme.accent : Theme.divider; border.width: isSelected ? 1.5 : 1
                            MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.selectedIndex = root.navIndex("fontgroup-" + groupTitle); bodyRoot.scope.setSystemFont(previewFamily) } }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                                Rectangle {
                                    antialiasing: Theme.shapesAa
                                    Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: Theme.cornerRadiusSmall
                                    color: isSelected ? Theme.accent : Theme.surface2
                                    border.color: isSelected ? Theme.accent : Theme.divider; border.width: 1
                                    Text { anchors.centerIn: parent; text: "Aa"; font.family: displayFamily; font.pixelSize: Theme.fs(15); color: isSelected ? Theme.onAccent : Theme.textSecondary
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Text { text: groupTitle; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13); font.weight: Font.Medium; color: isSelected || isActive ? Theme.textPrimary : Theme.textSecondary; Layout.fillWidth: true; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                    }
                                    Text { text: variants.length <= 1 ? bodyRoot.scope.fontWeightName(previewFamily) : (variants.length + " Schnitte" + (isActive ? " • " + activeLabel : "")); font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11); color: Theme.textMuted; Layout.fillWidth: true; elide: Text.ElideRight
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                    }
                                    Text { text: "Aa Bb Cc 123"; font.family: displayFamily; font.pixelSize: Theme.fs(12); color: Theme.textMuted; Layout.fillWidth: true; elide: Text.ElideRight
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                    }
                                }
                                Rectangle {
                                    antialiasing: Theme.shapesAa
                                    visible: variants.length > 1
                                    Layout.preferredWidth: 26; Layout.preferredHeight: 28; radius: Theme.cornerRadiusSmall
                                    color: isExpanded ? Theme.bgSelected : expandMouse.containsMouse ? Theme.bgHover : "transparent"
                                    border.color: isExpanded ? Theme.accent : "transparent"; border.width: isExpanded ? 1 : 0
                                    Text { anchors.centerIn: parent; text: "›"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14); color: isSelected || isExpanded ? Theme.textPrimary : Theme.textSecondary; rotation: isExpanded ? 90 : 0
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                    }
                                    MouseArea { id: expandMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: (mouse) => { mouse.accepted = true; root.selectedIndex = root.navIndex("fontgroup-" + groupTitle); bodyRoot.scope.toggleFontExpanded(groupTitle) } }
                                }
                                Rectangle {
                                    antialiasing: Theme.shapesAa
                                    Layout.preferredWidth: 56; Layout.preferredHeight: 20; radius: 10
                                    color: isActive ? Theme.primary : Theme.withAlpha(Theme.surface2, 0.9)
                                    border.color: isActive ? Theme.primary : Theme.divider; border.width: 1
                                    Text { anchors.centerIn: parent; text: isActive ? "Aktiv" : "Wählen"; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(9); font.weight: Font.Medium; color: isActive ? Theme.onAccent : Theme.textSecondary
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                    }
                                }
                            }
                        }
                        ColumnLayout {
                            visible: isExpanded
                            Layout.fillWidth: true
                            spacing: 2
                            Repeater {
                                model: variants
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    property string variantFamily: modelData
                                    property bool isVariantActive: Theme.fontFamily === variantFamily
                                    property string weightLabel: bodyRoot.scope.fontVariantLabel(variantFamily, groupTitle)
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 28
                                    radius: Theme.cornerRadiusSmall
                                    color: isVariantActive ? Theme.bgSelected : variantMouse.containsMouse ? Theme.panelSurface : "transparent"
                                    border.color: isVariantActive ? Theme.accent : "transparent"; border.width: isVariantActive ? 1 : 0
                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: 48; anchors.rightMargin: 12; spacing: 8
                                        Rectangle { Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4; color: isVariantActive ? Theme.accent : Theme.divider
                                            antialiasing: Theme.shapesAa
                                        }
                                        Text { text: weightLabel; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10); font.weight: isVariantActive ? Font.Medium : Font.Normal; color: isVariantActive ? Theme.textPrimary : Theme.textSecondary; Layout.preferredWidth: 130; elide: Text.ElideRight
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                        }
                                        Text { text: "Aa Bb Cc 123"; font.family: variantFamily; font.pixelSize: Theme.fs(12); color: Theme.textPrimary; Layout.fillWidth: true; elide: Text.ElideRight
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                        }
                                        Text { visible: isVariantActive; text: "✓"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(12); color: Theme.accent; Layout.preferredWidth: 16; horizontalAlignment: Text.AlignHCenter
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                        }
                                    }
                                    MouseArea { id: variantMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: (mouse) => { mouse.accepted = true; root.selectedIndex = root.navIndex("fontgroup-" + groupTitle); bodyRoot.scope.setSystemFont(variantFamily) } }
                                }
                            }
                        }
        }
        footer: Item {
            width: fontList.width
            height: fontList.count === 0 ? 120 : 0
            visible: fontList.count === 0
            clip: true
            Column {
                anchors.centerIn: parent
                width: parent.width - 20
                spacing: 6
                Text { text: "󰛖"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(28); color: Theme.textMuted; width: parent.width; horizontalAlignment: Text.AlignHCenter
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                Text { text: root.isLoading ? "Lade Fonts…" : "Keine Treffer"; color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12); width: parent.width; horizontalAlignment: Text.AlignHCenter
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
            }
        }
    }
}
