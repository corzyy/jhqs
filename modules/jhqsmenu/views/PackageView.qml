pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../../themes"

Item {
    id: root
    required property var scope
    required property var bodyRoot
    readonly property bool isMinimal: Theme.shellTheme === "minimal"
    anchors.fill: parent
    anchors.margins: isMinimal ? 0 : 4
    clip: true
    opacity: bodyRoot.scope.showPackages && !bodyRoot.scope.packageOpActive ? 1 : 0
    visible: opacity > 0.01
    enabled: bodyRoot.scope.showPackages && !bodyRoot.scope.packageOpActive
    scale: (bodyRoot.scope.showPackages && !bodyRoot.scope.packageOpActive) ? 1 : 0.97
    transformOrigin: Item.Center
    Behavior on opacity { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingSmooth } }
    Behavior on scale { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingSmooth } }

    readonly property bool isRemove: bodyRoot.scope.packageMode === "remove"
    readonly property bool isAur: bodyRoot.scope.packageMode === "aur"
    readonly property bool isAurRemove: bodyRoot.scope.packageMode === "aurremove"
    readonly property bool isFlatpak: bodyRoot.scope.packageMode === "flatpak"
    readonly property bool isFlatpakRemove: bodyRoot.scope.packageMode === "flatpakremove"
    readonly property bool isCurated: bodyRoot.scope.packageMode === "gaming" || bodyRoot.scope.packageMode === "browser"
    readonly property bool isBrowser: bodyRoot.scope.packageMode === "browser"
    readonly property int selCount: bodyRoot.scope.packageSelected.length
    readonly property string primaryLabel: ((isRemove || isAurRemove || isFlatpakRemove) ? "Entfernen" : "Installieren") + (selCount > 0 ? " (" + selCount + ")" : "")

    function toggleCurrent() {
        let p = bodyRoot.scope.filteredPackages[bodyRoot.selectedIndex]
        if (p && p.name) bodyRoot.scope.togglePackageSelected(p.name)
    }
    function runPrimary() {
        let sel = bodyRoot.scope.packageSelected.length > 0 ? bodyRoot.scope.packageSelected.slice() : []
        if (sel.length === 0) {
            let p = bodyRoot.scope.filteredPackages[bodyRoot.selectedIndex]
            if (p && p.name) sel = [p.name]
        }
        if (sel.length > 0) bodyRoot.scope.startPackageOp(bodyRoot.scope.packageMode, sel)
    }
    function handleKey(event): bool {
        if (event.key === Qt.Key_Space && event.modifiers === Qt.NoModifier && !event.isAutoRepeat) { root.toggleCurrent(); return true }
        return false
    }

    function emptyText(): string {
        if (root.isCurated) {
            if (bodyRoot.scope.filterText.length > 0) return "Keine Treffer bei " + bodyRoot.scope.curatedTitle()
            return bodyRoot.scope.curatedSize() + (root.isBrowser ? " Browser" : " Gaming-Apps") + " – Space: auswählen, Enter: installieren"
        }
        if (root.isAur) {
            if (bodyRoot.scope.filterText.length > 0) return bodyRoot.scope.aurSearching ? "Suche AUR…" : "Keine Treffer im AUR"
            return bodyRoot.scope.aurFeaturedLoading ? "Lade AUR-Programme…" : "Paketnamen tippen – Live-Suche im AUR"
        }
        if (root.isFlatpak) {
            if (bodyRoot.scope.filterText.length > 0) return "Keine Treffer bei Flathub"
            return bodyRoot.scope.flatpakLoading ? "Lade Flatpaks von Flathub…" : (bodyRoot.scope.flatpakList.length === 0 ? "Keine Flatpaks gefunden" : bodyRoot.scope.flatpakList.length + " Flatpaks – tippen zum Filtern")
        }
        if (root.isFlatpakRemove) {
            if (bodyRoot.scope.filterText.length > 0) return "Keine Treffer"
            return bodyRoot.scope.flatpakInstalledLoading ? "Lade installierte Flatpaks…" : (bodyRoot.scope.flatpakInstalledPackages.length === 0 ? "Keine Flatpaks installiert" : bodyRoot.scope.flatpakInstalledPackages.length + " Flatpaks – tippen zum Filtern")
        }
        if (bodyRoot.scope.filterText.length > 0) return "Keine Treffer"
        if (root.isAurRemove) {
            return bodyRoot.scope.aurInstalledPackages.length === 0 ? "Keine AUR-Pakete installiert" : bodyRoot.scope.aurInstalledPackages.length + " AUR-Pakete – tippen zum Filtern"
        }
        if (bodyRoot.scope.packageList.length === 0) return "Lade Pakete..."
        if (root.isRemove) return "Keine installierten Pakete"
        return bodyRoot.scope.packageList.length + " Pakete – tippen zum Filtern"
    }

    ListView {
        id: packageList
        anchors.top: parent.top
        anchors.left: parent.left; anchors.right: parent.right
        anchors.bottom: footerBar.top
        anchors.bottomMargin: isMinimal ? 0 : 6
        anchors.leftMargin: isMinimal ? 0 : 6; anchors.rightMargin: isMinimal ? 0 : 6
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        spacing: isMinimal ? 3 : 4
        model: bodyRoot.scope.filteredPackages
        currentIndex: bodyRoot.selectedIndex
        delegate: Rectangle {
            id: rowBg
            required property var modelData
            required property int index
            width: packageList.width
            height: root.isMinimal ? 58 : 40
            radius: root.isMinimal ? Theme.cornerRadius : Theme.cornerRadiusSmall
            readonly property var entry: modelData
            readonly property bool isSelected: bodyRoot.selectedIndex === index
            readonly property bool isChecked: entry && entry.name ? bodyRoot.scope.isPackageSelected(entry.name) : false
            color: root.isMinimal ? (isChecked ? Theme.withAlpha(Theme.accent, 0.16) : isSelected ? Theme.withAlpha(Theme.textPrimary, 0.08) : rowMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.04) : "transparent") : (isChecked ? Theme.withAlpha(Theme.accent, 0.14) : isSelected ? Theme.bgSelected : rowMouse.containsMouse ? Theme.panelSurface : "transparent")
            border.color: root.isMinimal ? "transparent" : (isChecked ? Theme.accent : isSelected ? Theme.accent : "transparent"); border.width: root.isMinimal ? 0 : ((isChecked || isSelected) ? 1 : 0)
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: root.isMinimal ? 8 : 10; anchors.rightMargin: root.isMinimal ? 8 : 10; spacing: root.isMinimal ? 6 : 10
                Rectangle {
                    antialiasing: Theme.shapesAa
                    Layout.preferredWidth: 18; Layout.preferredHeight: 18; radius: root.isMinimal ? 0 : 5
                    color: rowBg.isChecked ? Theme.accent : "transparent"
                    border.color: rowBg.isChecked ? Theme.accent : (root.isMinimal ? Theme.withAlpha(Theme.textPrimary, 0.4) : Theme.divider); border.width: 1
                    Text { anchors.centerIn: parent; visible: rowBg.isChecked; text: "✓"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(11); font.weight: Font.Bold; color: Theme.onAccent
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                }
                Text { text: root.isCurated ? (root.isBrowser ? "󰖟" : "󰊗") : ((root.isFlatpak || root.isFlatpakRemove) ? "󰇚" : "󰣇"); font.family: Theme.iconFontFamily; font.pixelSize: root.isMinimal ? Theme.fs(18) : Theme.fs(14); color: isSelected ? Theme.accent : (root.isMinimal ? Theme.textPrimary : Theme.textMuted); Layout.preferredWidth: root.isMinimal ? 36 : 18; horizontalAlignment: Text.AlignHCenter;
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                ColumnLayout {
                    visible: root.isMinimal
                    Layout.fillWidth: true; spacing: 3
                    Text { text: root.isCurated ? (entry.displayName || entry.name || "—") : ((entry.displayName && entry.displayName.length > 0) ? entry.displayName : (entry.name || "—")); font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(16); font.weight: Font.Medium; color: isSelected ? Theme.accent : Theme.textPrimary; Layout.fillWidth: true; elide: Text.ElideRight
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    Text { visible: !root.isCurated; text: ((entry.repo || "") !== "" ? entry.repo + " • " : "") + (entry.version || "—"); font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(11); color: Theme.textPrimary; opacity: 0.52; Layout.fillWidth: true; elide: Text.ElideRight
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    Text { visible: root.isCurated; text: entry.name || ""; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(11); color: Theme.textPrimary; opacity: 0.52; Layout.fillWidth: true; elide: Text.ElideRight
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                }
                Text { visible: !root.isMinimal; text: root.isCurated ? (entry.displayName || entry.name || "—") : ((entry.displayName && entry.displayName.length > 0) ? entry.displayName + " (" + (entry.name || "—") + ")" : (entry.name || "—")); font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13); font.weight: isSelected ? Font.Medium : Font.Normal; color: isSelected ? Theme.textPrimary : Theme.textSecondary; Layout.fillWidth: true; elide: Text.ElideRight
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                Text { visible: !root.isMinimal && !root.isCurated; text: entry.repo || ""; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10); color: Theme.textMuted; Layout.preferredWidth: 72; elide: Text.ElideRight; horizontalAlignment: Text.AlignRight
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                Text { visible: !root.isMinimal && !root.isCurated; text: entry.version || ""; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10); color: Theme.textMuted; Layout.preferredWidth: 96; elide: Text.ElideRight; horizontalAlignment: Text.AlignRight
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                Text { text: "✓"; visible: entry.installed === true; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(12); color: Theme.accent; Layout.preferredWidth: 16; horizontalAlignment: Text.AlignHCenter
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
            }
            MouseArea {
                id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { bodyRoot.selectedIndex = index; root.toggleCurrent() }
            }
        }
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: 0
        preferredHighlightEnd: height - 44

        ColumnLayout {
            visible: packageList.count === 0
            anchors.centerIn: parent
            spacing: 4
            Text { text: root.isCurated ? (root.isBrowser ? "󰖟" : "󰊗") : ((root.isFlatpak || root.isFlatpakRemove) ? "󰇚" : "󰣇"); font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(16); color: Theme.textMuted; Layout.alignment: Qt.AlignHCenter
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            Text { text: root.emptyText(); color: Theme.textMuted; font.family: root.isMinimal ? Theme.iconFontFamily : Theme.fontFamily; font.pixelSize: Theme.fs(11); Layout.alignment: Qt.AlignHCenter
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
        }

        Connections {
            target: bodyRoot
            function onSelectedIndexChanged() { packageList.positionViewAtIndex(bodyRoot.selectedIndex, ListView.Contain) }
            function onFilterTextChanged() { packageList.contentY = 0; Qt.callLater(() => packageList.positionViewAtIndex(bodyRoot.selectedIndex, ListView.Contain)) }
        }
        Connections {
            target: bodyRoot.scope
            function onShowPackagesChanged() { if (bodyRoot.scope.showPackages) { packageList.contentY = 0; Qt.callLater(() => packageList.positionViewAtIndex(bodyRoot.selectedIndex, ListView.Contain)) } }
            function onFilteredPackagesChanged() { packageList.contentY = 0 }
        }
    }

    Rectangle {
        antialiasing: Theme.shapesAa
        id: footerBar
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 52; radius: root.isMinimal ? 0 : Theme.cornerRadiusSmall
        color: root.isMinimal ? "transparent" : Theme.panelSurface
        border.color: root.isMinimal ? "transparent" : Theme.divider; border.width: root.isMinimal ? 0 : 1
        Rectangle {
            visible: root.isMinimal
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            height: 1; color: Theme.withAlpha(Theme.textPrimary, 0.12)
        }
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: root.isMinimal ? 0 : 12; anchors.rightMargin: root.isMinimal ? 0 : 10; spacing: 8
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                text: root.selCount > 0 ? root.selCount + " ausgewählt" : (root.isCurated ? (bodyRoot.scope.filteredPackages.length + (root.isBrowser ? " Browser – Space: auswählen" : " Gaming-Apps – Space: auswählen")) : (root.isAur && bodyRoot.scope.aurSearching ? "Suche AUR…" : (root.isAur && bodyRoot.scope.filterText.length === 0 ? (bodyRoot.scope.aurFeaturedLoading ? "Lade AUR-Programme…" : bodyRoot.scope.aurFeaturedPackages.length + " Programme – Space: auswählen") : root.isFlatpak ? (bodyRoot.scope.flatpakLoading ? "Lade Flatpaks…" : (bodyRoot.scope.filterText.length === 0 ? bodyRoot.scope.flatpakList.length + " Flatpaks – Space: auswählen" : "Space: auswählen")) : root.isFlatpakRemove ? (bodyRoot.scope.flatpakInstalledLoading ? "Lade installierte Flatpaks…" : bodyRoot.scope.flatpakInstalledPackages.length + " installiert – Space: auswählen") : (root.isAurRemove ? bodyRoot.scope.aurInstalledPackages.length + " installiert – Space: auswählen" : (root.isRemove ? bodyRoot.scope.installedPackageCount + " installiert – Space: auswählen" : "Space: auswählen")))))
                font.family: root.isMinimal ? Theme.iconFontFamily : Theme.fontFamily; font.pixelSize: Theme.fs(11)
                color: root.selCount > 0 ? Theme.textPrimary : Theme.textMuted
                font.weight: root.selCount > 0 ? Font.Medium : Font.Normal
                Layout.fillWidth: true; elide: Text.ElideRight
            }
            Rectangle {
                antialiasing: Theme.shapesAa
                visible: root.selCount > 0
                Layout.preferredWidth: clearLabel.implicitWidth + 20; Layout.preferredHeight: 30; radius: root.isMinimal ? 0 : Theme.cornerRadiusSmall
                color: clearMouse.containsMouse ? (root.isMinimal ? Theme.withAlpha(Theme.textPrimary, 0.08) : Theme.bgHover) : "transparent"
                border.color: root.isMinimal ? Theme.withAlpha(Theme.textPrimary, 0.25) : Theme.divider; border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingSmooth } }
                Text { id: clearLabel; anchors.centerIn: parent; text: "Zurücksetzen"; font.family: root.isMinimal ? Theme.iconFontFamily : Theme.fontFamily; font.pixelSize: Theme.fs(11); color: Theme.textSecondary
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                MouseArea { id: clearMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bodyRoot.scope.clearPackageSelection() }
            }
            Rectangle {
                antialiasing: Theme.shapesAa
                Layout.preferredWidth: primaryLabel.implicitWidth + 24; Layout.preferredHeight: 32; radius: root.isMinimal ? 0 : Theme.cornerRadiusSmall
                color: primaryMouse.containsMouse ? Theme.withAlpha(Theme.accent, 0.92) : Theme.accent
                border.color: Theme.accent; border.width: 1
                opacity: bodyRoot.scope.filteredPackages.length > 0 ? 1 : 0.5
                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingSmooth } }
                Text { id: primaryLabel; anchors.centerIn: parent; text: root.primaryLabel; font.family: root.isMinimal ? Theme.iconFontFamily : Theme.fontFamily; font.pixelSize: Theme.fs(11); font.weight: Font.Medium; color: Theme.onAccent
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                MouseArea {
                    id: primaryMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { if (bodyRoot.scope.filteredPackages.length > 0) root.runPrimary() }
                }
            }
        }
    }
}
