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
    Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }

    property var navItems: {
        let list = bodyRoot.scope.filteredFonts
        let arr = []
        if (!list) return arr
        for (let i = 0; i < list.length; i++) arr.push({id: "font-" + list[i], type: "font", data: list[i]})
        return arr
    }
    property int navCount: navItems.length
    property int selectedIndex: 0
    onNavCountChanged: { if (root.selectedIndex > root.navCount - 1) root.selectedIndex = Math.max(0, root.navCount - 1); root.ensureVisible() }
    onSelectedIndexChanged: root.ensureVisible()

    function navIndex(id: string): int {
        let items = root.navItems
        for (let i = 0; i < items.length; i++) if (items[i].id === id) return i
        return -1
    }
    function isSelected(family: string): bool { return root.navIndex("font-" + family) === root.selectedIndex }
    function selectedFamily(): string {
        let it = root.navItems[root.selectedIndex]
        return it ? it.data : ""
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
        let fam = root.selectedFamily()
        if (fam !== "") bodyRoot.scope.setSystemFont(fam)
    }
    function expandSelected() {
        let fam = root.selectedFamily()
        if (fam !== "" && bodyRoot.scope.fontExpanded !== fam) bodyRoot.scope.toggleFontExpanded(fam)
    }
    function collapseSelected() {
        if (bodyRoot.scope.fontExpanded !== "") bodyRoot.scope.toggleFontExpanded(bodyRoot.scope.fontExpanded)
    }
    function handleKey(event): bool {
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

    ListView {
        id: fontList
        anchors.top: parent.top; anchors.topMargin: 10; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.leftMargin: 6; anchors.rightMargin: 6
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 160
        spacing: 4
        model: bodyRoot.scope.filteredFonts
        delegate: ColumnLayout {
            required property var modelData
            required property int index
            anchors.left: parent.left
            anchors.right: parent.right
            property string familyName: modelData
            property bool isActive: Theme.fontFamily === familyName
            property bool isSelected: index === root.selectedIndex
            property bool isExpanded: bodyRoot.scope.fontExpanded === familyName
            property var cachedStyles: bodyRoot.scope.fontStylesCache[familyName]
            spacing: 2
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            Layout.fillWidth: true
                            Layout.preferredHeight: 56
                            radius: Theme.cornerRadiusSmall
                            color: isSelected ? Theme.bgSelected : isActive ? Theme.panelSurface : rowMouse.containsMouse ? Theme.panelSurface : Theme.panelBg
                            border.color: isSelected ? Theme.accent : Theme.divider; border.width: isSelected ? 1.5 : 1
                            MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.selectedIndex = root.navIndex("font-" + familyName); bodyRoot.scope.setSystemFont(familyName) } }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                                Rectangle {
                                    antialiasing: Theme.shapesAa
                                    Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: Theme.cornerRadiusSmall
                                    color: isSelected ? Theme.accent : Theme.surface2
                                    border.color: isSelected ? Theme.accent : Theme.divider; border.width: 1
                                    Text { anchors.centerIn: parent; text: "Aa"; font.family: familyName; font.pixelSize: Theme.fs(15); color: isSelected ? Theme.onAccent : Theme.textSecondary
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Text { text: familyName; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13); font.weight: Font.Medium; color: isSelected || isActive ? Theme.textPrimary : Theme.textSecondary; Layout.fillWidth: true; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                    }
                                    Text { text: "Aa Bb Cc 123"; font.family: familyName; font.pixelSize: Theme.fs(12); color: Theme.textMuted; Layout.fillWidth: true; elide: Text.ElideRight
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                    }
                                }
                                Rectangle {
                                    antialiasing: Theme.shapesAa
                                    Layout.preferredWidth: 26; Layout.preferredHeight: 28; radius: Theme.cornerRadiusSmall
                                    color: isExpanded ? Theme.bgSelected : expandMouse.containsMouse ? Theme.bgHover : "transparent"
                                    border.color: isExpanded ? Theme.accent : "transparent"; border.width: isExpanded ? 1 : 0
                                    Text { anchors.centerIn: parent; text: "›"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14); color: isSelected || isExpanded ? Theme.textPrimary : Theme.textSecondary; rotation: isExpanded ? 90 : 0; Behavior on rotation { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                    }
                                    MouseArea { id: expandMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: (mouse) => { mouse.accepted = true; root.selectedIndex = root.navIndex("font-" + familyName); bodyRoot.scope.toggleFontExpanded(familyName) } }
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
                            Text {
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                visible: bodyRoot.scope.fontStylesLoading === familyName
                                text: "Lade Stile…"; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10); color: Theme.textMuted
                                Layout.fillWidth: true; Layout.leftMargin: 48
                            }
                            Repeater {
                                model: cachedStyles !== undefined ? cachedStyles : []
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    property string styleName: modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 28
                                    radius: Theme.cornerRadiusSmall
                                    color: styleMouse.containsMouse ? Theme.panelSurface : "transparent"
                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: 48; anchors.rightMargin: 12; spacing: 8
                                        Rectangle { Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4; color: Theme.divider
                                            antialiasing: Theme.shapesAa
                                        }
                                        Text { text: styleName; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10); color: Theme.textSecondary; Layout.preferredWidth: 130; elide: Text.ElideRight
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                        }
                                        Text { text: "Aa Bb Cc 123"; font.family: familyName; font.styleName: styleName; font.pixelSize: Theme.fs(12); color: Theme.textPrimary; Layout.fillWidth: true; elide: Text.ElideRight
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                        }
                                    }
                                    MouseArea { id: styleMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: (mouse) => { mouse.accepted = true; bodyRoot.scope.setSystemFont(familyName) } }
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
                Text { text: "Keine Treffer"; color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12); width: parent.width; horizontalAlignment: Text.AlignHCenter
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
            }
        }
    }
}
