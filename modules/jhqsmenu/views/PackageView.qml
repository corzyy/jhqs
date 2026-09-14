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
    opacity: bodyRoot.scope.showPackages && !bodyRoot.scope.packageOpActive ? 1 : 0
    visible: opacity > 0.01
    enabled: bodyRoot.scope.showPackages && !bodyRoot.scope.packageOpActive
    scale: (bodyRoot.scope.showPackages && !bodyRoot.scope.packageOpActive) ? 1 : 0.97
    transformOrigin: Item.Center

    readonly property bool isRemove: bodyRoot.scope.packageMode === "remove"
    readonly property bool isInstall: bodyRoot.scope.packageMode === "install"
    readonly property bool isFlatpak: bodyRoot.scope.packageMode === "flatpak"
    readonly property bool isFlatpakRemove: bodyRoot.scope.packageMode === "flatpakremove"
    readonly property bool isCurated: bodyRoot.scope.packageMode === "gaming" || bodyRoot.scope.packageMode === "browser"
    readonly property bool isBrowser: bodyRoot.scope.packageMode === "browser"
    readonly property int selCount: bodyRoot.scope.packageSelected.length
    readonly property string primaryLabel: ((isRemove || isFlatpakRemove) ? "Remove" : "Install") + (selCount > 0 ? " (" + selCount + ")" : "")

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
            if (bodyRoot.scope.filterText.length > 0) return "No results in " + bodyRoot.scope.curatedTitle()
            return bodyRoot.scope.curatedSize() + (root.isBrowser ? " Browser" : " Gaming Apps") + " – Space: select, Enter: install"
        }
        if (root.isInstall) {
            if (bodyRoot.scope.filterText.length > 0) return "No results in DNF"
            if (bodyRoot.scope.availableLoading) return "Loading packages…"
            return bodyRoot.scope.availableList.length + " packages – type to filter"
        }
        if (root.isFlatpak) {
            if (bodyRoot.scope.filterText.length > 0) return "No results in Flathub"
            return bodyRoot.scope.flatpakLoading ? "Loading Flatpaks from Flathub…" : (bodyRoot.scope.flatpakList.length === 0 ? "No Flatpaks found" : bodyRoot.scope.flatpakList.length + " Flatpaks – type to filter")
        }
        if (root.isFlatpakRemove) {
            if (bodyRoot.scope.filterText.length > 0) return "No results"
            return bodyRoot.scope.flatpakInstalledLoading ? "Loading installed Flatpaks…" : (bodyRoot.scope.flatpakInstalledPackages.length === 0 ? "No Flatpaks installed" : bodyRoot.scope.flatpakInstalledPackages.length + " Flatpaks – type to filter")
        }
        if (bodyRoot.scope.filterText.length > 0) return "No results"
        if (bodyRoot.scope.installedList.length === 0) return "Loading packages…"
        if (root.isRemove) return "No installed packages"
    }

    ScrollIndicator { flick: packageList }
    ListView {
        id: packageList
        anchors.top: parent.top
        anchors.left: parent.left; anchors.right: parent.right
        anchors.bottom: footerBar.top
        anchors.bottomMargin: 0
        anchors.leftMargin: 0; anchors.rightMargin: 0
        clip: true
        // PERF: recycle delegates (10k packages filtered per keystroke).
        reuseItems: true
        cacheBuffer: 240
        boundsBehavior: Flickable.StopAtBounds
        spacing: 3
        model: bodyRoot.scope.filteredPackages
        currentIndex: bodyRoot.selectedIndex
        delegate: Rectangle {
            id: rowBg
            required property var modelData
            required property int index
            width: packageList.width
            height: 58
            radius: Theme.cornerRadius
            readonly property var entry: modelData
            readonly property bool isSelected: bodyRoot.selectedIndex === index
            readonly property bool isChecked: entry && entry.name ? bodyRoot.scope.isPackageSelected(entry.name) : false
            color: (isChecked ? Theme.withAlpha(Theme.accent, 0.16) : isSelected ? Theme.withAlpha(Theme.textPrimary, 0.08) : rowMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.04) : "transparent")
            border.color: "transparent"; border.width: 0
            Rectangle {
                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                width: 3
                color: Theme.accent
                visible: isSelected
            }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                Rectangle {
                    antialiasing: Theme.shapesAa
                    Layout.preferredWidth: 18; Layout.preferredHeight: 18; radius: 0
                    color: rowBg.isChecked ? Theme.accent : "transparent"
                    border.color: rowBg.isChecked ? Theme.accent : (Theme.withAlpha(Theme.textPrimary, 0.4)); border.width: 1
                    Text { anchors.centerIn: parent; visible: rowBg.isChecked; text: "✓"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(11); font.weight: Font.Bold; color: Theme.onAccent
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                }
                Text { text: root.isCurated ? (root.isBrowser ? "󰖟" : "󰊗") : ((root.isFlatpak || root.isFlatpakRemove) ? "󰇚" : "󰣛"); font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(18); color: isSelected ? Theme.accent : (Theme.textPrimary); Layout.preferredWidth: 36; horizontalAlignment: Text.AlignHCenter;
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 3
                    Text { text: root.isCurated ? (entry.displayName || entry.name || "—") : ((entry.displayName && entry.displayName.length > 0) ? entry.displayName : (entry.name || "—")); font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(16); font.weight: Font.Medium; color: isSelected ? Theme.accent : Theme.textPrimary; Layout.fillWidth: true; elide: Text.ElideRight
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    Text { visible: !root.isCurated; text: ((entry.repo || "") !== "" ? entry.repo + " • " : "") + (entry.version || "—"); font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(11); color: Theme.textPrimary; opacity: 0.52; Layout.fillWidth: true; elide: Text.ElideRight
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    Text { visible: root.isCurated; text: ((entry.repo || "") !== "" ? entry.repo + " • " : "") + (entry.name || ""); font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(11); color: Theme.textPrimary; opacity: 0.52; Layout.fillWidth: true; elide: Text.ElideRight
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
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
            Text { text: root.isCurated ? (root.isBrowser ? "󰖟" : "󰊗") : ((root.isFlatpak || root.isFlatpakRemove) ? "󰇚" : "󰣛"); font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(16); color: Theme.textMuted; Layout.alignment: Qt.AlignHCenter
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            Text { text: root.emptyText(); color: Theme.textMuted; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(11); Layout.alignment: Qt.AlignHCenter
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
        height: 52; radius: 0
        color: "transparent"
        border.color: "transparent"; border.width: 0
        Rectangle {
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            height: 1; color: Theme.withAlpha(Theme.textPrimary, 0.12)
        }
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 0; anchors.rightMargin: 0; spacing: 8
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                text: root.selCount > 0 ? root.selCount + " selected" : (root.isCurated ? (bodyRoot.scope.filteredPackages.length + (root.isBrowser ? " Browser – Space: select" : " Gaming Apps – Space: select")) : (root.isInstall ? (bodyRoot.scope.availableLoading ? "Loading packages…" : (bodyRoot.scope.filterText.length === 0 ? bodyRoot.scope.availableList.length + " packages – Space: select" : "Space: select")) : root.isFlatpak ? (bodyRoot.scope.flatpakLoading ? "Loading Flatpaks…" : (bodyRoot.scope.filterText.length === 0 ? bodyRoot.scope.flatpakList.length + " Flatpaks – Space: select" : "Space: select")) : root.isFlatpakRemove ? (bodyRoot.scope.flatpakInstalledLoading ? "Loading installed Flatpaks…" : bodyRoot.scope.flatpakInstalledPackages.length + " installed – Space: select") : (root.isRemove ? bodyRoot.scope.installedPackageCount + " installed – Space: select" : "Space: select")))
                font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(11)
                color: root.selCount > 0 ? Theme.textPrimary : Theme.textMuted
                font.weight: root.selCount > 0 ? Font.Medium : Font.Normal
                Layout.fillWidth: true; elide: Text.ElideRight
            }
            Rectangle {
                antialiasing: Theme.shapesAa
                visible: root.selCount > 0
                Layout.preferredWidth: clearLabel.implicitWidth + 20; Layout.preferredHeight: 30; radius: 0
                color: clearMouse.containsMouse ? (Theme.withAlpha(Theme.textPrimary, 0.08)) : "transparent"
                border.color: Theme.withAlpha(Theme.textPrimary, 0.25); border.width: 1
                Text { id: clearLabel; anchors.centerIn: parent; text: "Reset"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(11); color: Theme.textSecondary
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                MouseArea { id: clearMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bodyRoot.scope.clearPackageSelection() }
            }
            Rectangle {
                antialiasing: Theme.shapesAa
                Layout.preferredWidth: primaryLabel.implicitWidth + 24; Layout.preferredHeight: 32; radius: 0
                color: primaryMouse.containsMouse ? Theme.withAlpha(Theme.accent, 0.92) : Theme.accent
                border.color: Theme.accent; border.width: 1
                opacity: bodyRoot.scope.filteredPackages.length > 0 ? 1 : 0.5
                Text { id: primaryLabel; anchors.centerIn: parent; text: root.primaryLabel; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(11); font.weight: Font.Medium; color: Theme.onAccent
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
