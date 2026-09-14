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
    opacity: bodyRoot.scope.showThemes ? 1 : 0
    visible: opacity > 0.01
    enabled: bodyRoot.scope.showThemes
    Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }

    property bool showMonetSettings: false

    property var navItems: {
        let q = bodyRoot.scope.filterText ? bodyRoot.scope.filterText.trim().toLowerCase() : ""
        let isFiltered = q.length > 0
        if (root.showMonetSettings) {
            let arr = []
            arr.push({id: "mode", type: "mode"})
            let types = bodyRoot.scope.matugenTypes
            for (let t of types) arr.push({id: "type-" + t, type: "variant", data: t})
            return arr
        }
        if (isFiltered) {
            let filtered = bodyRoot.scope.filteredThemes
            let arr = []
            for (let i = 0; i < filtered.length; i++) arr.push({id: "preset-" + filtered[i].id, type: "preset", data: filtered[i]})
            return arr
        }
        let arr = []
        let presets = bodyRoot.scope.themeOptions
        for (let p of presets) arr.push({id: "preset-" + p.id, type: "preset", data: p})
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
    function isSelected(id: string): bool { return root.navIndex(id) === root.selectedIndex }
    readonly property bool lightBg: (0.299 * Theme.bg.r + 0.587 * Theme.bg.g + 0.114 * Theme.bg.b) > 0.5
    function themePrimary(id: string): color {
        if (id === "wallpaper") return Theme.primary
        if (id === "everforest") return lightBg ? "#8DA101" : "#A7C080"
        if (id === "tokyonight") return lightBg ? "#2959aa" : "#7aa2f7"
        if (id === "petrichor") return lightBg ? "#7f9459" : "#93a06b"
        if (id === "monochrome") return lightBg ? "#181818" : "#e7e7e7"
        if (id === "catppuccin") return lightBg ? "#8839ef" : "#cba6f7"
        if (id === "gruvbox") return "#7daea3"
        return Theme.textPrimary
    }
    function openMonetSettings() {
        bodyRoot.scope.clearSearch()
        root.showMonetSettings = true
        root.selectedIndex = root.navIndex("mode")
    }
    function selectedItem(): var {
        let it = root.navItems[root.selectedIndex]
        if (!it) return null
        if (root.showMonetSettings) {
            if (it.id === "mode") return modeRow
            if (it.id.startsWith("type-")) {
                let t = it.id.substring(5)
                for (let i = 0; i < monetVariantsBody.children.length; i++) {
                    let ch = monetVariantsBody.children[i]
                    if (ch && ch.typeName === t) return ch
                }
            }
            return null
        }
        if (it.id.startsWith("preset-")) {
            let targetId = it.id.substring(7)
            let q = bodyRoot.scope.filterText ? bodyRoot.scope.filterText.trim().length : 0
            let container = q > 0 ? filteredBody : presetsBody
            for (let i = 0; i < container.children.length; i++) {
                let ch = container.children[i]
                if (ch && ch.presetId === targetId) return ch
            }
            return null
        }
        return null
    }
    function ensureVisible() {
        let item = root.selectedItem()
        if (!item || !item.visible) return
        let flick = root.showMonetSettings ? monetFlick : themesFlick
        if (!flick) return
        let p = item.mapToItem(flick, 0, 0)
        let y = p.y
        let vh = flick.height
        let maxY = Math.max(0, flick.contentHeight - vh)
        if (y < flick.contentY) flick.contentY = Math.max(0, y - 4)
        else if (y + item.height > flick.contentY + vh) flick.contentY = Math.min(maxY, y + item.height - vh + 4)
    }
    function moveSelection(delta: int) {
        if (root.navCount === 0) return
        root.selectedIndex = (root.selectedIndex + delta + root.navCount) % root.navCount
    }
    function activateSelected() {
        let it = root.navItems[root.selectedIndex]
        if (!it) return
        if (it.type === "preset") {
            let pid = it.id.substring(7)
            bodyRoot.scope.setThemeEngine(pid)
        } else if (it.type === "mode") {
            let next = bodyRoot.scope.monetMode === "dark" ? "light" : "dark"
            bodyRoot.scope.applyMonetScheme(bodyRoot.scope.monetType, next)
        } else if (it.type === "variant") {
            let t = it.id.substring(5)
            bodyRoot.scope.applyMonetScheme(t, bodyRoot.scope.monetMode)
        }
    }
    function adjustSelected(delta: int) {
        let it = root.navItems[root.selectedIndex]
        if (!it) return
        if (it.type === "mode") {
            let next = delta > 0 ? (bodyRoot.scope.monetMode === "dark" ? "light" : "dark") : (bodyRoot.scope.monetMode === "light" ? "dark" : "light")
            if (next !== bodyRoot.scope.monetMode) bodyRoot.scope.applyMonetScheme(bodyRoot.scope.monetType, next)
        } else if (it.type === "preset" && it.id === "preset-wallpaper") {
            if (delta > 0) root.openMonetSettings()
        }
    }
    function handleKey(event): bool {
        if (event.key === Qt.Key_Down) { root.moveSelection(1); return true }
        if (event.key === Qt.Key_Up) { root.moveSelection(-1); return true }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.activateSelected(); return true }
        if (event.key === Qt.Key_Right) { root.adjustSelected(1); return true }
        if (event.key === Qt.Key_Left) { root.adjustSelected(-1); return true }
        if (event.key === Qt.Key_Home) { root.selectedIndex = 0; return true }
        if (event.key === Qt.Key_End) { root.selectedIndex = root.navCount - 1; return true }
        if (event.key === Qt.Key_Escape) {
            if (root.showMonetSettings) { root.showMonetSettings = false; root.selectedIndex = root.navIndex("preset-wallpaper"); return true }
            return false
        }
        return false
    }

    Connections {
        target: bodyRoot.scope
        function onShowThemesChanged() {
            if (bodyRoot.scope.showThemes) { root.showMonetSettings = false; root.selectedIndex = 0 }
            else root.showMonetSettings = false
        }
        function onFilterTextChanged() {
            let q = bodyRoot.scope.filterText ? bodyRoot.scope.filterText.trim().length : 0
            if (q > 0) root.showMonetSettings = false
            root.selectedIndex = 0
        }
    }

    ScrollIndicator { flick: themesFlick; show: !root.showMonetSettings }
    Flickable {
        id: themesFlick
        visible: !root.showMonetSettings
        anchors.fill: parent
        clip: true
        contentHeight: themesCol.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: themesCol
            x: 0
            width: parent.width
            spacing: 3

            ColumnLayout {
                id: filteredBody
                visible: bodyRoot.scope.filterText && bodyRoot.scope.filterText.trim().length > 0 && !root.showMonetSettings
                Layout.fillWidth: true
                spacing: 3
                Repeater {
                    model: bodyRoot.scope.filterText && bodyRoot.scope.filterText.trim().length > 0 ? bodyRoot.scope.filteredThemes : []
                    delegate: Item {
                        required property var modelData; required property int index
                        property string presetId: modelData.id
                        property bool isActive: bodyRoot.scope.currentEngine === modelData.id
                        property bool isSelected: root.navIndex("preset-" + modelData.id) === root.selectedIndex
                        Layout.fillWidth: true
                        implicitHeight: 50
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            anchors.fill: parent
                            height: 50; radius: Theme.cornerRadius
                            color: isSelected ? Theme.withAlpha(Theme.textPrimary, 0.08) : filteredMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.04) : "transparent"
                            border.color: "transparent"; border.width: 0
                            Rectangle {
                                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                width: 3
                                color: Theme.accent
                                visible: isSelected
                            }
                            MouseArea { id: filteredMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.selectedIndex = root.navIndex("preset-" + modelData.id); bodyRoot.scope.setThemeEngine(modelData.id) } }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                                Text { text: modelData.icon; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(18); color: root.themePrimary(modelData.id); Layout.preferredWidth: 36; horizontalAlignment: Text.AlignHCenter
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                                Text { text: modelData.title; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(16); font.weight: Font.Medium; color: isSelected ? Theme.accent : Theme.textPrimary; Layout.fillWidth: true; elide: Text.ElideRight
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                                Text { visible: isActive; text: "✓"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14); color: Theme.accent; Layout.preferredWidth: 14; horizontalAlignment: Text.AlignHCenter
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                                Text {
                                    visible: modelData.id === "wallpaper"
                                    text: "›"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(16); color: isSelected ? Theme.accent : Theme.textPrimary; opacity: isSelected ? 1.0 : 0.36
                                    Layout.preferredWidth: 14; horizontalAlignment: Text.AlignHCenter
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                    MouseArea { anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: (mouse) => { mouse.accepted = true; root.openMonetSettings() } }
                                }
                            }
                        }
                    }
                }
                Column { visible: bodyRoot.scope.filteredThemes.length === 0 && bodyRoot.scope.filterText.trim().length > 0 && !root.showMonetSettings; Layout.fillWidth: true; spacing: 8; topPadding: 24
                    Text { text: "󰸉"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(28); color: Theme.textMuted; width: parent.width; horizontalAlignment: Text.AlignHCenter
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    Text { text: "No results"; color: Theme.textMuted; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(13); width: parent.width; horizontalAlignment: Text.AlignHCenter
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                }
            }

            ColumnLayout {
                visible: (!bodyRoot.scope.filterText || bodyRoot.scope.filterText.trim().length === 0) && !root.showMonetSettings
                Layout.fillWidth: true
                spacing: 3
                ColumnLayout {
                    id: presetsBody
                    Layout.fillWidth: true
                    spacing: 3
                    Repeater {
                        model: bodyRoot.scope.themeOptions
                        delegate: Rectangle {
                            required property var modelData; required property int index
                            property string presetId: modelData.id
                            property bool isActive: bodyRoot.scope.currentEngine === modelData.id
                            property bool isSelected: root.navIndex("preset-" + modelData.id) === root.selectedIndex
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            radius: Theme.cornerRadius
                            color: isSelected ? Theme.withAlpha(Theme.textPrimary, 0.08) : presetMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.04) : "transparent"
                            border.color: "transparent"; border.width: 0
                            Rectangle {
                                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                width: 3
                                color: Theme.accent
                                visible: isSelected
                            }
                            MouseArea { id: presetMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.selectedIndex = root.navIndex("preset-" + modelData.id); bodyRoot.scope.setThemeEngine(modelData.id) } }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                                Text { text: modelData.icon; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(18); color: root.themePrimary(modelData.id); Layout.preferredWidth: 36; horizontalAlignment: Text.AlignHCenter
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                                Text { text: modelData.title; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(16); font.weight: Font.Medium; color: isSelected ? Theme.accent : Theme.textPrimary; Layout.fillWidth: true; elide: Text.ElideRight
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                                Text { visible: isActive; text: "✓"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14); color: Theme.accent; Layout.preferredWidth: 14; horizontalAlignment: Text.AlignHCenter
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                                Text {
                                    visible: modelData.id === "wallpaper"
                                    text: "›"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(16); color: isSelected ? Theme.accent : Theme.textPrimary; opacity: isSelected ? 1.0 : 0.36
                                    Layout.preferredWidth: 14; horizontalAlignment: Text.AlignHCenter
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                    MouseArea { anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: (mouse) => { mouse.accepted = true; root.openMonetSettings() } }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    ScrollIndicator { flick: monetFlick; show: root.showMonetSettings }
    Flickable {
        id: monetFlick
        visible: root.showMonetSettings
        anchors.fill: parent
        clip: true
        contentHeight: monetCol.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: monetCol
            x: 0
            width: parent.width
            spacing: 3
            Rectangle {
                antialiasing: Theme.shapesAa
                id: modeRow
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                radius: Theme.cornerRadius
                color: root.isSelected("mode") ? Theme.withAlpha(Theme.textPrimary, 0.08) : modeMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.04) : "transparent"
                border.color: "transparent"
                border.width: 0
                Rectangle {
                    anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                    width: 3
                    color: Theme.accent
                    visible: root.isSelected("mode")
                }
                MouseArea { id: modeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.selectedIndex = root.navIndex("mode"); root.activateSelected() } }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                    Text { text: "󰽢"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(18); color: root.isSelected("mode") ? Theme.accent : Theme.textPrimary; Layout.preferredWidth: 36; horizontalAlignment: Text.AlignHCenter
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    Text { text: "Modus"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(16); font.weight: Font.Medium; color: root.isSelected("mode") ? Theme.accent : Theme.textPrimary; Layout.fillWidth: true; elide: Text.ElideRight
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    Text { text: bodyRoot.scope.monetMode === "dark" ? "Dark" : "Light"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(11); color: Theme.textMuted; Layout.preferredWidth: 52; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    Text { text: "›"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(16); color: root.isSelected("mode") ? Theme.accent : Theme.textPrimary; opacity: root.isSelected("mode") ? 1.0 : 0.36; Layout.preferredWidth: 14; horizontalAlignment: Text.AlignHCenter
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                }
            }
            ColumnLayout {
                id: monetVariantsBody
                Layout.fillWidth: true
                spacing: 3
                Repeater {
                    model: bodyRoot.scope.matugenTypes
                    delegate: Rectangle {
                        required property var modelData; required property int index
                        property string typeName: modelData
                        property bool isSelected: root.navIndex("type-" + typeName) === root.selectedIndex
                        property bool isActive: bodyRoot.scope.monetType === typeName
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        radius: Theme.cornerRadius
                        color: isSelected ? Theme.withAlpha(Theme.textPrimary, 0.08) : variantMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.04) : "transparent"
                        border.color: "transparent"; border.width: 0
                        Rectangle {
                            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                            width: 3
                            color: Theme.accent
                            visible: isSelected
                        }
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                            Text { text: "󰸉"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(18); color: isSelected ? Theme.accent : Theme.textPrimary; Layout.preferredWidth: 36; horizontalAlignment: Text.AlignHCenter
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                            Text { text: bodyRoot.scope.matugenTypeLabels[typeName] || typeName; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(16); font.weight: Font.Medium; color: isSelected ? Theme.accent : Theme.textPrimary; Layout.fillWidth: true; elide: Text.ElideRight
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                            Text { visible: isActive; text: "✓"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14); color: Theme.accent; Layout.preferredWidth: 14; horizontalAlignment: Text.AlignHCenter
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                        }
                        MouseArea { id: variantMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.selectedIndex = root.navIndex("type-" + typeName); bodyRoot.scope.applyMonetScheme(typeName, bodyRoot.scope.monetMode) } }
                    }
                }
            }
        }
    }
}
