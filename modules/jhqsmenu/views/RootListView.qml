pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../../themes"
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

    Flickable {
        id: listFlick
        anchors.fill: parent
        clip: true
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
            function onSelectedIndexChanged() { listFlick.ensureVisible(bodyRoot.selectedIndex) }
            function onFilterTextChanged() { listFlick.contentY = 0; Qt.callLater(() => listFlick.ensureVisible(bodyRoot.selectedIndex)) }
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
                model: bodyRoot.filteredApps
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
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                        Item {
                            Layout.preferredWidth: 36; Layout.preferredHeight: 18
                            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                            IconImage { anchors.centerIn: parent; width: 18; height: 18; source: Quickshell.iconPath(entry.icon); asynchronous: true; implicitSize: Qt.size(36, 36); mipmap: Theme.imageMipmap }
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
                                try { Theme.triggerLaunchOsd(entry.name || "", entry.icon || "") } catch (e) { }
                                entry.execute()
                                bodyRoot.scope.dismissed()
                            }
                        }
                    }
                }
            }

            Repeater {
                id: menuRepeater
                model: bodyRoot.filteredMenu
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
                        if (s.showInstall || s.showRemove || s.showStyle || s.showSession || s.showSetup) s.activateCurrent()
                        else if (m.title === "Apps") { s.showNewAppMenu = true; s.clearSearch() }
                        else if (m.title === "About") { s.openAbout(); s.dismissed() }
                        else if (m.title === "System") { s.showSession = true; s.directSystemOpen = false; s.clearSearch() }
                        else if (m.title === "Install") { s.showInstall = true; s.clearSearch() }
                        else if (m.title === "Remove") { s.showRemove = true; s.clearSearch() }
                        else if (m.title === "Style") { s.showStyle = true; s.clearSearch(); s.refreshWallpapers() }
                        else if (m.title === "Setup") { s.showSetup = true; s.clearSearch() }
                    }
                }
            }

            Column {
                visible: bodyRoot.filteredMenu.length === 0 && bodyRoot.filterText.length > 0 && bodyRoot.filteredCategorySections.length === 0 && bodyRoot.filteredApps.length === 0
                width: parent.width; spacing: 8; topPadding: 24
                Text { text: "󰍉"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(28); color: Theme.textMuted; width: parent.width; horizontalAlignment: Text.AlignHCenter
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                Text { text: "Keine Treffer"; color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13); width: parent.width; horizontalAlignment: Text.AlignHCenter
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                Text { text: "Versuche einen anderen Suchbegriff"; color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11); width: parent.width; horizontalAlignment: Text.AlignHCenter; opacity: 0.7
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
            }

            Repeater {
                id: catRepeater
                model: bodyRoot.filteredCategorySections
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
}
