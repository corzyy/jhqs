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
    opacity: bodyRoot.scope.showKeybinds ? 1 : 0
    visible: opacity > 0.01
    enabled: bodyRoot.scope.showKeybinds
    Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }

    readonly property bool isLoading: bodyRoot.scope.keybindLoading
    readonly property int navCount: bodyRoot.scope.filteredKeybinds.length
    readonly property string updatedAt: bodyRoot.scope.keybindUpdated
    readonly property string countLabel: {
        if (root.isLoading && root.navCount === 0) return "Lade Keybinds…"
        let n = root.navCount
        let base = n === 0 ? "Keybinds" : n + (n === 1 ? " Shortcut" : " Shortcuts")
        if (root.updatedAt !== "") base += " • " + root.updatedAt
        return base
    }

    function handleKey(event): bool {
        if (event.key === Qt.Key_F5) { bodyRoot.scope.refreshKeybindsForce(); return true }
        if (event.key === Qt.Key_R && (event.modifiers & Qt.ControlModifier)) { bodyRoot.scope.refreshKeybindsForce(); return true }
        return false
    }

    Connections {
        target: bodyRoot.scope
        function onShowKeybindsChanged() {
            if (bodyRoot.scope.showKeybinds) { keybindList.contentY = 0; Qt.callLater(() => keybindList.positionViewAtIndex(Math.max(0, bodyRoot.selectedIndex), ListView.Contain)) }
        }
        function onFilteredKeybindsChanged() { keybindList.contentY = 0 }
        function onKeybindListChanged() { if (bodyRoot.scope.showKeybinds) Qt.callLater(() => keybindList.positionViewAtIndex(Math.max(0, Math.min(bodyRoot.selectedIndex, Math.max(0, keybindList.count - 1))), ListView.Contain)) }
    }

    Column {
        id: keybindHeader
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
                text: root.isLoading ? "…" : "󰑓 Neu laden"
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
                    onClicked: bodyRoot.scope.refreshKeybindsForce()
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

    ScrollIndicator { flick: keybindList }
    ListView {
        id: keybindList
        anchors.top: keybindHeader.bottom
        anchors.topMargin: 3
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 300
        reuseItems: true
        spacing: 3
        model: bodyRoot.scope.filteredKeybinds
        currentIndex: bodyRoot.selectedIndex
        section.property: "kindLabel"
        section.delegate: Item {
            required property string section
            width: keybindList.width
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
        delegate: Rectangle {
            required property var modelData
            required property int index
            property var kb: modelData
            property bool isSelected: index === bodyRoot.selectedIndex
            property var chipParts: (kb && kb.parts) || []
            width: keybindList.width
            height: 50
            radius: Theme.cornerRadius
            color: isSelected ? Theme.withAlpha(Theme.textPrimary, 0.08) : rowMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.04) : "transparent"
            border.color: "transparent"
            border.width: 0
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 3
                color: Theme.accent
                visible: isSelected
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10
                Text {
                    text: (kb && kb.label) || "—"
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fs(14)
                    font.weight: Font.Medium
                    color: isSelected ? Theme.accent : Theme.textPrimary
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                Row {
                    id: chipRow
                    spacing: 4
                    Layout.alignment: Qt.AlignVCenter
                    Repeater {
                        model: chipParts
                        delegate: Row {
                            required property var modelData
                            required property int index
                            spacing: 4
                            Rectangle {
                                antialiasing: Theme.shapesAa
                                width: chipText.implicitWidth + 14
                                height: 26
                                radius: 6
                                color: isSelected ? Theme.withAlpha(Theme.accent, 0.14) : Theme.withAlpha(Theme.textPrimary, 0.06)
                                border.color: isSelected ? Theme.withAlpha(Theme.accent, 0.45) : Theme.withAlpha(Theme.textPrimary, 0.18)
                                border.width: 1
                                Text {
                                    id: chipText
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: Theme.fs(12)
                                    font.weight: Font.Medium
                                    color: isSelected ? Theme.accent : Theme.textPrimary
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                            }
                            Text {
                                visible: index < chipParts.length - 1
                                anchors.verticalCenter: parent.verticalCenter
                                text: "+"
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fs(12)
                                color: Theme.textMuted
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                        }
                    }
                }
            }
            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { bodyRoot.selectedIndex = index }
            }
        }
        footer: Item {
            width: keybindList.width
            height: keybindList.count === 0 ? 120 : 0
            visible: keybindList.count === 0
            clip: true
            Column {
                anchors.top: parent.top
                anchors.topMargin: 24
                width: parent.width
                spacing: 8
                Text {
                    text: "󰌌"
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fs(28)
                    color: Theme.textMuted
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                Text {
                    text: root.isLoading ? "Lade Keybinds…" : "Keine Treffer"
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
                    text: "Versuche einen anderen Suchbegriff"
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
        Connections {
            target: bodyRoot
            function onSelectedIndexChanged() { keybindList.positionViewAtIndex(bodyRoot.selectedIndex, ListView.Contain) }
            function onFilterTextChanged() { keybindList.contentY = 0; Qt.callLater(() => keybindList.positionViewAtIndex(bodyRoot.selectedIndex, ListView.Contain)) }
        }
    }
}
