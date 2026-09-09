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

    Flickable {
        id: themesFlick
        visible: !root.showMonetSettings
        anchors.top: parent.top; anchors.topMargin: 10; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        clip: true
        contentHeight: themesCol.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: themesCol
            x: 6
            width: parent.width - 12
            spacing: 4

            ColumnLayout {
                id: filteredBody
                visible: bodyRoot.scope.filterText && bodyRoot.scope.filterText.trim().length > 0 && !root.showMonetSettings
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: bodyRoot.scope.filterText && bodyRoot.scope.filterText.trim().length > 0 ? bodyRoot.scope.filteredThemes : []
                    delegate: Item {
                        required property var modelData; required property int index
                        property string presetId: modelData.id
                        property bool isActive: bodyRoot.scope.currentEngine === modelData.id
                        property bool isSelected: root.navIndex("preset-" + modelData.id) === root.selectedIndex
                        Layout.fillWidth: true
                        implicitHeight: filteredRow.implicitHeight
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            id: filteredRow
                            anchors.left: parent.left; anchors.right: parent.right
                            implicitHeight: 56; radius: Theme.cornerRadiusSmall
                            color: isSelected ? Theme.bgSelected : isActive ? Theme.panelSurface : filteredMouse.containsMouse ? Theme.panelSurface : Theme.panelBg
                            border.color: isSelected ? Theme.accent : isActive ? Theme.divider : Theme.divider; border.width: isSelected ? 1.5 : isActive ? 1 : 1
                            MouseArea { id: filteredMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.selectedIndex = root.navIndex("preset-" + modelData.id); bodyRoot.scope.setThemeEngine(modelData.id) } }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                                Rectangle { Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: Theme.cornerRadiusSmall; color: isSelected ? Theme.accent : isActive ? Theme.surface2 : Theme.surface2; border.color: isSelected ? Theme.accent : Theme.divider; border.width: 1
                                    antialiasing: Theme.shapesAa
                                    Text { anchors.centerIn: parent; text: modelData.icon; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(16); color: isSelected ? Theme.onAccent : isActive ? Theme.textMuted : Theme.textSecondary
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                    }
                                }
                                Text { text: modelData.title; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13); font.weight: Font.Medium; color: isSelected ? Theme.textPrimary : isActive ? Theme.textSecondary : Theme.textSecondary; Layout.fillWidth: true; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                                Row { spacing: 4
                                    Rectangle { width: 10; height: 10; radius: 5; color: modelData.id === "everforest" ? "#A7C080" : modelData.id === "tokyonight" ? "#7aa2f7" : modelData.id === "petrichor" ? "#93a06b" : modelData.id === "monochrome" ? "#e7e7e7" : modelData.id === "catppuccin" ? "#cba6f7" : Theme.primary; border.color: Theme.divider; border.width: 1
                                        antialiasing: Theme.shapesAa
                                    }
                                    Rectangle { width: 10; height: 10; radius: 5; color: modelData.id === "everforest" ? "#DBBC7F" : modelData.id === "tokyonight" ? "#bb9af7" : modelData.id === "petrichor" ? "#c9a35c" : modelData.id === "monochrome" ? "#ababab" : modelData.id === "catppuccin" ? "#89b4fa" : Theme.secondary; border.color: Theme.divider; border.width: 1
                                        antialiasing: Theme.shapesAa
                                    }
                                    Rectangle { width: 10; height: 10; radius: 5; color: modelData.id === "everforest" ? "#7FBBB3" : modelData.id === "tokyonight" ? "#7dcfff" : modelData.id === "petrichor" ? "#84a89e" : modelData.id === "monochrome" ? "#717171" : modelData.id === "catppuccin" ? "#94e2d5" : Theme.tertiary; border.color: Theme.divider; border.width: 1
                                        antialiasing: Theme.shapesAa
                                    }
                                }
                                Rectangle {
                                    antialiasing: Theme.shapesAa
                                    visible: modelData.id === "wallpaper"
                                    Layout.preferredWidth: 30; Layout.preferredHeight: 28; radius: Theme.cornerRadiusSmall
                                    color: filteredCogMouse.containsMouse ? Theme.bgHover : Theme.surface2
                                    border.color: Theme.divider; border.width: 1
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                    Text { anchors.centerIn: parent; text: "󰒓"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(13); color: Theme.textSecondary
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                    }
                                    MouseArea { id: filteredCogMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: (mouse) => { mouse.accepted = true; bodyRoot.scope.clearSearch(); root.showMonetSettings = true; root.selectedIndex = root.navIndex("mode") } }
                                }
                                Rectangle { Layout.preferredWidth: 56; Layout.preferredHeight: 20; radius: 10; color: isActive ? Theme.primary : Theme.withAlpha(Theme.surface2, 0.9); border.color: isActive ? Theme.primary : Theme.divider; border.width: 1
                                    antialiasing: Theme.shapesAa
                                    Text { anchors.centerIn: parent; text: isActive ? "Aktiv" : "Wählen"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(9); font.weight: Font.Medium; color: isActive ? Theme.onAccent : Theme.textSecondary
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                    }
                                }
                            }
                        }
                    }
                }
                Column { visible: bodyRoot.scope.filteredThemes.length === 0 && bodyRoot.scope.filterText.trim().length > 0 && !root.showMonetSettings; Layout.fillWidth: true; spacing: 6; topPadding: 16
                    Text { text: "󰸉"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(28); color: Theme.textMuted; width: parent.width; horizontalAlignment: Text.AlignHCenter
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    Text { text: "Keine Treffer"; color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12); width: parent.width; horizontalAlignment: Text.AlignHCenter
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                }
            }

            ColumnLayout {
                visible: (!bodyRoot.scope.filterText || bodyRoot.scope.filterText.trim().length === 0) && !root.showMonetSettings
                Layout.fillWidth: true
                spacing: 4
                ColumnLayout {
                    id: presetsBody
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: bodyRoot.scope.themeOptions
                        delegate: Rectangle {
                            required property var modelData; required property int index
                            property string presetId: modelData.id
                            property bool isActive: bodyRoot.scope.currentEngine === modelData.id
                            property bool isSelected: root.navIndex("preset-" + modelData.id) === root.selectedIndex
                            Layout.fillWidth: true
                            Layout.preferredHeight: 56
                            radius: Theme.cornerRadiusSmall
                            color: isSelected ? Theme.bgSelected : isActive ? Theme.panelSurface : presetMouse.containsMouse ? Theme.panelSurface : Theme.panelBg
                            border.color: isSelected ? Theme.accent : isActive ? Theme.divider : Theme.divider; border.width: isSelected ? 1.5 : isActive ? 1 : 1
                            MouseArea { id: presetMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.selectedIndex = root.navIndex("preset-" + modelData.id); bodyRoot.scope.setThemeEngine(modelData.id) } }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                                Rectangle { Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: Theme.cornerRadiusSmall; color: isSelected ? Theme.accent : isActive ? Theme.surface2 : Theme.surface2; border.color: isSelected ? Theme.accent : Theme.divider; border.width: 1
                                    antialiasing: Theme.shapesAa
                                    Text { anchors.centerIn: parent; text: modelData.icon; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(16); color: isSelected ? Theme.onAccent : isActive ? Theme.textMuted : Theme.textSecondary
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                    }
                                }
                                Text { text: modelData.title; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13); font.weight: Font.Medium; color: isSelected ? Theme.textPrimary : isActive ? Theme.textSecondary : Theme.textSecondary; Layout.fillWidth: true; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                                Row { spacing: 4
                                    Rectangle { width: 10; height: 10; radius: 5; color: modelData.id === "everforest" ? "#A7C080" : modelData.id === "tokyonight" ? "#7aa2f7" : modelData.id === "petrichor" ? "#93a06b" : modelData.id === "monochrome" ? "#e7e7e7" : modelData.id === "catppuccin" ? "#cba6f7" : Theme.primary; border.color: Theme.divider; border.width: 1
                                        antialiasing: Theme.shapesAa
                                    }
                                    Rectangle { width: 10; height: 10; radius: 5; color: modelData.id === "everforest" ? "#DBBC7F" : modelData.id === "tokyonight" ? "#bb9af7" : modelData.id === "petrichor" ? "#c9a35c" : modelData.id === "monochrome" ? "#ababab" : modelData.id === "catppuccin" ? "#89b4fa" : Theme.secondary; border.color: Theme.divider; border.width: 1
                                        antialiasing: Theme.shapesAa
                                    }
                                    Rectangle { width: 10; height: 10; radius: 5; color: modelData.id === "everforest" ? "#7FBBB3" : modelData.id === "tokyonight" ? "#7dcfff" : modelData.id === "petrichor" ? "#84a89e" : modelData.id === "monochrome" ? "#717171" : modelData.id === "catppuccin" ? "#94e2d5" : Theme.tertiary; border.color: Theme.divider; border.width: 1
                                        antialiasing: Theme.shapesAa
                                    }
                                }
                                Rectangle {
                                    antialiasing: Theme.shapesAa
                                    visible: modelData.id === "wallpaper"
                                    Layout.preferredWidth: 30; Layout.preferredHeight: 28; radius: Theme.cornerRadiusSmall
                                    color: monetCogMouse.containsMouse ? Theme.bgHover : Theme.surface2
                                    border.color: Theme.divider; border.width: 1
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                    Text { anchors.centerIn: parent; text: "󰒓"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(13); color: Theme.textSecondary
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                    }
                                    MouseArea {
                                        id: monetCogMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: (mouse) => { mouse.accepted = true; root.showMonetSettings = true; root.selectedIndex = root.navIndex("mode") }
                                    }
                                }
                                Rectangle { Layout.preferredWidth: 56; Layout.preferredHeight: 20; radius: 10; color: isActive ? Theme.primary : Theme.withAlpha(Theme.surface2, 0.9); border.color: isActive ? Theme.primary : Theme.divider; border.width: 1
                                    antialiasing: Theme.shapesAa
                                    Text { anchors.centerIn: parent; text: isActive ? "Aktiv" : "Wählen"; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(9); font.weight: Font.Medium; color: isActive ? Theme.onAccent : Theme.textSecondary
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Flickable {
        id: monetFlick
        visible: root.showMonetSettings
        anchors.top: parent.top; anchors.topMargin: 10; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        clip: true
        contentHeight: monetCol.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: monetCol
            x: 6
            width: parent.width - 12
            spacing: 4
            Rectangle {
                antialiasing: Theme.shapesAa
                id: modeRow
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: Theme.cornerRadiusSmall
                color: root.isSelected("mode") ? Theme.bgSelected : modeMouse.containsMouse ? Theme.panelSurface : "transparent"
                border.color: root.isSelected("mode") ? Theme.accent : "transparent"
                border.width: root.isSelected("mode") ? 1 : 0
                MouseArea { id: modeMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.selectedIndex = root.navIndex("mode") }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                    Text { text: "󰽢"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14); color: root.isSelected("mode") ? Theme.accent : Theme.textMuted; Behavior on color { ColorAnimation { duration: Theme.animFast } } Layout.preferredWidth: 18; horizontalAlignment: Text.AlignHCenter
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    Text { text: "Modus"; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13); font.weight: root.isSelected("mode") ? Font.Medium : Font.Normal; color: root.isSelected("mode") ? Theme.textPrimary : Theme.textSecondary; Layout.fillWidth: true; elide: Text.ElideRight
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    Row { spacing: 6; Layout.alignment: Qt.AlignVCenter
                        Rectangle { width: 76; height: 30; radius: Theme.cornerRadiusSmall; color: bodyRoot.scope.monetMode === "dark" ? Theme.accent : Theme.surface2; border.color: bodyRoot.scope.monetMode === "dark" ? Theme.accent : Theme.divider; border.width: 1
                            antialiasing: Theme.shapesAa
                            Text { anchors.centerIn: parent; text: "Dunkel"; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10); color: bodyRoot.scope.monetMode === "dark" ? Theme.onAccent : Theme.textSecondary
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: bodyRoot.scope.applyMonetScheme(bodyRoot.scope.monetType, "dark") }
                        }
                        Rectangle { width: 76; height: 30; radius: Theme.cornerRadiusSmall; color: bodyRoot.scope.monetMode === "light" ? Theme.accent : Theme.surface2; border.color: bodyRoot.scope.monetMode === "light" ? Theme.accent : Theme.divider; border.width: 1
                            antialiasing: Theme.shapesAa
                            Text { anchors.centerIn: parent; text: "Hell"; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10); color: bodyRoot.scope.monetMode === "light" ? Theme.onAccent : Theme.textSecondary
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: bodyRoot.scope.applyMonetScheme(bodyRoot.scope.monetType, "light") }
                        }
                    }
                }
            }
            ColumnLayout {
                id: monetVariantsBody
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: bodyRoot.scope.matugenTypes
                    delegate: Rectangle {
                        required property var modelData; required property int index
                        property string typeName: modelData
                        property bool isSelected: root.navIndex("type-" + typeName) === root.selectedIndex
                        property bool isActive: bodyRoot.scope.monetType === typeName
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: Theme.cornerRadiusSmall
                        color: isActive ? Theme.bgSelected : isSelected ? Theme.bgSelected : variantMouse.containsMouse ? Theme.panelSurface : "transparent"
                        border.color: isActive ? Theme.primary : isSelected ? Theme.divider : "transparent"; border.width: isActive || isSelected ? 1 : 0
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 8
                            Rectangle { Layout.preferredWidth: 12; Layout.preferredHeight: 12; radius: 6; color: isActive ? Theme.accent : Theme.panelSurface; border.color: isActive ? Theme.accent : Theme.divider; border.width: 1
                                antialiasing: Theme.shapesAa
                            }
                            Text { text: bodyRoot.scope.matugenTypeLabels[typeName] || typeName; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(11); color: isActive || isSelected ? Theme.textPrimary : Theme.textSecondary; Layout.fillWidth: true; elide: Text.ElideRight
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                            Text { visible: isActive; text: "󰄬"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(12); color: Theme.accent
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
