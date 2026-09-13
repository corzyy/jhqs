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
    opacity: bodyRoot.scope.showWebApp ? 1 : 0
    visible: opacity > 0.01
    enabled: bodyRoot.scope.showWebApp
    scale: bodyRoot.scope.showWebApp ? 1 : 0.97
    transformOrigin: Item.Center

    readonly property bool isInstall: bodyRoot.scope.webAppMode !== "remove"
    readonly property bool busy: bodyRoot.scope.webAppBusy
    readonly property bool success: bodyRoot.scope.webAppSuccess

    property int fieldIdx: 0
    property int selIdx: 0

    function focusField() {
        if (!bodyRoot.scope.showWebApp || !root.isInstall) return
        if (root.fieldIdx === 0 && nameInput) nameInput.forceActiveFocus()
        else if (root.fieldIdx === 1 && urlInput) urlInput.forceActiveFocus()
        else if (root.fieldIdx === 2 && iconInput) iconInput.forceActiveFocus()
    }
    function doInstall() {
        if (root.busy) return
        bodyRoot.scope.installWebApp(
            nameInput ? nameInput.text : "",
            urlInput ? urlInput.text : "",
            iconInput ? iconInput.text : "")
    }
    function doRemove(name) {
        if (root.busy) return
        let n = name
        if (n === undefined || n === null || ("" + n).trim().length === 0) {
            let cur = bodyRoot.scope.filteredWebApps[root.selIdx]
            n = cur ? cur.name : ""
        }
        if (n && ("" + n).trim().length > 0) bodyRoot.scope.removeWebApp(n)
    }
    function ensureVisible() {
        if (!removeList.visible) return
        removeList.positionViewAtIndex(root.selIdx, ListView.Contain)
    }
    function handleKey(event): bool {
        if (!bodyRoot.scope.showWebApp) return false
        if (root.isInstall) {
            if (event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
                root.fieldIdx = (root.fieldIdx + 1) % 4
                root.focusField()
                return true
            }
            if (event.key === Qt.Key_Up || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                root.fieldIdx = (root.fieldIdx + 3) % 4
                root.focusField()
                return true
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.doInstall(); return true }
            if (event.key === Qt.Key_Escape) return false
            return false
        }
        let n = bodyRoot.scope.filteredWebApps.length
        if (event.key === Qt.Key_Down) { if (n > 0) { root.selIdx = (root.selIdx + 1) % n; root.ensureVisible() } return true }
        if (event.key === Qt.Key_Up) { if (n > 0) { root.selIdx = (root.selIdx - 1 + n) % n; root.ensureVisible() } return true }
        if (event.key === Qt.Key_PageDown) { if (n > 0) { root.selIdx = Math.min(root.selIdx + 5, n - 1); root.ensureVisible() } return true }
        if (event.key === Qt.Key_PageUp) { if (n > 0) { root.selIdx = Math.max(root.selIdx - 5, 0); root.ensureVisible() } return true }
        if (event.key === Qt.Key_Home) { if (n > 0) { root.selIdx = 0; root.ensureVisible() } return true }
        if (event.key === Qt.Key_End) { if (n > 0) { root.selIdx = n - 1; root.ensureVisible() } return true }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { if (n > 0) root.doRemove(); return true }
        if (event.key === Qt.Key_Escape) return false
        return false
    }

    Connections {
        target: bodyRoot.scope
        function onShowWebAppChanged() {
            if (bodyRoot.scope.showWebApp) {
                root.fieldIdx = 0
                root.selIdx = 0
                removeList.contentY = 0
                if (root.isInstall) Qt.callLater(() => root.focusField())
                else Qt.callLater(() => root.ensureVisible())
            }
        }
        function onWebAppModeChanged() {
            root.fieldIdx = 0
            root.selIdx = 0
            if (bodyRoot.scope.showWebApp && root.isInstall) Qt.callLater(() => root.focusField())
        }
        function onFilteredWebAppsChanged() {
            let n = bodyRoot.scope.filteredWebApps.length
            if (root.selIdx > Math.max(0, n - 1)) root.selIdx = Math.max(0, n - 1)
            removeList.contentY = 0
        }
    }
    Connections {
        target: bodyRoot
        function onFilterTextChanged() {
            if (bodyRoot.scope.showWebApp && !root.isInstall) {
                root.selIdx = 0
                removeList.contentY = 0
                Qt.callLater(() => root.ensureVisible())
            }
        }
        function onSelectedIndexChanged() {
            if (bodyRoot.scope.showWebApp && !root.isInstall) root.ensureVisible()
        }
    }

    ScrollIndicator { flick: removeList; show: removeList.visible }
    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 0; Layout.rightMargin: 0
            spacing: 14
            Text {
                Layout.alignment: Qt.AlignVCenter
                text: "󰖟"
                font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(24)
                color: root.busy ? Theme.accent : Theme.textPrimary
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    Layout.fillWidth: true
                    text: root.isInstall ? "Web App installieren" : "Web App entfernen"
                    color: Theme.textPrimary; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(16); font.weight: Font.Bold
                    elide: Text.ElideRight
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    Layout.fillWidth: true
                    text: (root.isInstall ? "Chromium --app Launcher (.desktop) erstellen" : (bodyRoot.scope.webAppLoading ? "Lade Web Apps…" : bodyRoot.scope.webAppList.length + (bodyRoot.scope.webAppList.length === 1 ? " Web App" : " Web Apps") + " — tippen zum Filtern")).toUpperCase()
                    color: Theme.textSecondary; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(10); font.weight: Font.Bold
                    font.letterSpacing: 1.2
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true; height: 1
            color: Theme.withAlpha(Theme.textPrimary, 0.12)
        }

        ColumnLayout {
            visible: root.isInstall
            Layout.fillWidth: true
            spacing: 4

            Text { text: "Name"; color: Theme.textSecondary; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(10); font.weight: Font.Bold; Layout.leftMargin: 0; font.letterSpacing: 1.2
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            Rectangle {
                antialiasing: Theme.shapesAa
                Layout.fillWidth: true; Layout.preferredHeight: 36
                radius: 0
                color: Theme.withAlpha(Theme.textPrimary, 0.04)
                border.color: nameInput.activeFocus || root.fieldIdx === 0 ? Theme.accent : (Theme.withAlpha(Theme.textPrimary, 0.25))
                border.width: (nameInput.activeFocus || root.fieldIdx === 0) ? 2 : 1
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                    Text { text: "󰷖"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(12); color: Theme.textMuted
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    TextInput {
                        id: nameInput
                        Layout.fillWidth: true
                        color: Theme.textPrimary
                        font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(13)
                        clip: true; selectByMouse: true
                        selectionColor: Theme.accent
                        maximumLength: 64
                    }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: { root.fieldIdx = 0; nameInput.forceActiveFocus() } }
            }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                visible: nameInput.text.length === 0 && !nameInput.activeFocus
                text: "z. B. YouTube Music"
                color: Theme.textMuted; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(11); opacity: 0.7
                Layout.leftMargin: 42; Layout.topMargin: -32; Layout.bottomMargin: 12
            }

            Text { text: "URL"; color: Theme.textSecondary; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(10); font.weight: Font.Bold; Layout.leftMargin: 0; font.letterSpacing: 1.2
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            Rectangle {
                antialiasing: Theme.shapesAa
                Layout.fillWidth: true; Layout.preferredHeight: 36
                radius: 0
                color: Theme.withAlpha(Theme.textPrimary, 0.04)
                border.color: urlInput.activeFocus || root.fieldIdx === 1 ? Theme.accent : (Theme.withAlpha(Theme.textPrimary, 0.25))
                border.width: (urlInput.activeFocus || root.fieldIdx === 1) ? 2 : 1
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                    Text { text: "󰖟"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(12); color: Theme.textMuted
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    TextInput {
                        id: urlInput
                        Layout.fillWidth: true
                        color: Theme.textPrimary
                        font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(13)
                        clip: true; selectByMouse: true
                        selectionColor: Theme.accent
                        inputMethodHints: Qt.ImhUrlCharactersOnly
                        onAccepted: root.doInstall()
                    }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: { root.fieldIdx = 1; urlInput.forceActiveFocus() } }
            }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                visible: urlInput.text.length === 0 && !urlInput.activeFocus
                text: "https://… (https:// wird ergänzt)"
                color: Theme.textMuted; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(11); opacity: 0.7
                Layout.leftMargin: 42; Layout.topMargin: -32; Layout.bottomMargin: 12
            }

            Text { text: "Icon (optional)"; color: Theme.textSecondary; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(10); font.weight: Font.Bold; Layout.leftMargin: 0; font.letterSpacing: 1.2
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            Rectangle {
                antialiasing: Theme.shapesAa
                Layout.fillWidth: true; Layout.preferredHeight: 36
                radius: 0
                color: Theme.withAlpha(Theme.textPrimary, 0.04)
                border.color: iconInput.activeFocus || root.fieldIdx === 2 ? Theme.accent : (Theme.withAlpha(Theme.textPrimary, 0.25))
                border.width: (iconInput.activeFocus || root.fieldIdx === 2) ? 2 : 1
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                    Text { text: "󰣛"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(12); color: Theme.textMuted
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    TextInput {
                        id: iconInput
                        Layout.fillWidth: true
                        color: Theme.textPrimary
                        font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(13)
                        clip: true; selectByMouse: true
                        selectionColor: Theme.accent
                        onAccepted: root.doInstall()
                    }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: { root.fieldIdx = 2; iconInput.forceActiveFocus() } }
            }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                visible: iconInput.text.length === 0 && !iconInput.activeFocus
                text: "Leer = Icon automatisch holen · sonst PNG-URL, Datei oder Icon-Name"
                color: Theme.textMuted; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(11); opacity: 0.7
                Layout.leftMargin: 42; Layout.topMargin: -32; Layout.bottomMargin: 12
            }
        }

        ListView {
            id: removeList
            visible: !root.isInstall
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.leftMargin: 0; Layout.rightMargin: 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            // PERF: recycle delegates.
            reuseItems: true
            cacheBuffer: 160
            spacing: 3
            model: bodyRoot.scope.filteredWebApps
            currentIndex: root.selIdx
            delegate: Rectangle {
                id: rowBg
                required property var modelData
                required property int index
                width: removeList.width
                height: 58
                radius: 0
                readonly property var entry: modelData
                readonly property bool isSelected: root.selIdx === index
                color: (isSelected ? Theme.withAlpha(Theme.textPrimary, 0.08) : rowMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.04) : "transparent")
                border.color: "transparent"; border.width: 0
                Rectangle {
                    anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                    width: 3
                    color: Theme.accent
                    visible: isSelected
                }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.selIdx = index; root.ensureVisible() }
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                    IconImage {
                        Layout.preferredWidth: 20; Layout.preferredHeight: 20
                        source: entry && entry.icon ? Quickshell.iconPath(entry.icon) : ""
                        implicitSize: Qt.size(36, 36)
                        asynchronous: true
                        visible: entry && entry.icon && ("" + entry.icon).length > 0
                    }
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        visible: !(entry && entry.icon && ("" + entry.icon).length > 0)
                        text: "󰖟"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(18)
                        color: isSelected ? Theme.accent : (Theme.textPrimary)
                        Layout.preferredWidth: 36; horizontalAlignment: Text.AlignHCenter
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 3
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            Layout.fillWidth: true
                            text: (entry.displayName && entry.displayName.length > 0) ? entry.displayName : (entry.name || "—")
                            font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(16); font.weight: Font.Medium
                            color: isSelected ? (Theme.accent) : (Theme.textPrimary)
                            elide: Text.ElideRight
                        }
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            visible: entry.url && entry.url.length > 0
                            Layout.fillWidth: true
                            text: entry.url || ""
                            font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(11)
                            color: Theme.textPrimary; opacity: 0.52
                            elide: Text.ElideRight
                        }
                    }
                    Rectangle {
                        antialiasing: Theme.shapesAa
                        Layout.preferredWidth: 64; Layout.preferredHeight: 28
                        radius: 0
                        color: delMouse.containsMouse ? Theme.error : "transparent"
                        border.color: delMouse.containsMouse ? Theme.error : (Theme.withAlpha(Theme.textPrimary, 0.25)); border.width: 1
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            anchors.centerIn: parent
                            text: "Entfernen"
                            font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(10)
                            color: delMouse.containsMouse ? Theme.onAccent : Theme.textSecondary
                        }
                        MouseArea {
                            id: delMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.selIdx = index; root.doRemove(entry.name) }
                        }
                    }
                }
            }
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: 0
            preferredHighlightEnd: height - 44

            ColumnLayout {
                visible: removeList.count === 0
                anchors.centerIn: parent
                spacing: 4
                Text { text: "󰖟"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(16); color: Theme.textMuted; Layout.alignment: Qt.AlignHCenter
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    text: bodyRoot.scope.webAppLoading ? "Lade Web Apps…" : (bodyRoot.scope.filterText.length > 0 ? "Keine Treffer" : "Keine Web Apps installiert")
                    color: Theme.textMuted; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(11); Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            visible: (bodyRoot.scope.webAppStatus && bodyRoot.scope.webAppStatus.length > 0) || root.busy
            Layout.fillWidth: true; Layout.leftMargin: 0; Layout.rightMargin: 0
            text: root.busy ? ("◌ " + (bodyRoot.scope.webAppStatus.length > 0 ? bodyRoot.scope.webAppStatus : "Arbeite…")) : bodyRoot.scope.webAppStatus
            color: root.busy ? Theme.textMuted : (root.success ? Theme.accent : (bodyRoot.scope.webAppStatus.startsWith("✗") ? Theme.errorColor : Theme.textSecondary))
            font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(11); font.weight: root.success ? Font.Medium : Font.Normal
            elide: Text.ElideRight
        }
        Rectangle {
            antialiasing: Theme.shapesAa
            visible: bodyRoot.scope.webAppLog.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: root.isInstall ? 88 : 72
            radius: 0; color: Theme.withAlpha(Theme.textPrimary, 0.04)
            border.color: Theme.withAlpha(Theme.textPrimary, 0.25); border.width: 1; clip: true
            ScrollIndicator { flick: logFlick }
            Flickable {
                id: logFlick
                anchors.fill: parent; anchors.margins: 10
                clip: true; boundsBehavior: Flickable.StopAtBounds
                contentWidth: width; contentHeight: logText.implicitHeight
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    id: logText
                    width: parent.width
                    text: bodyRoot.scope.webAppLog
                    color: Theme.textSecondary; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(11)
                    wrapMode: Text.WordWrap; textFormat: Text.PlainText; lineHeight: 1.3
                }
            }
            Connections {
                target: bodyRoot.scope
                function onWebAppLogChanged() { Qt.callLater(() => { logFlick.contentY = Math.max(0, logFlick.contentHeight - logFlick.height) }) }
            }
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    let dy = event.angleDelta.y
                    if (dy === 0 && event.pixelDelta.y === 0) return
                    let delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : (dy > 0 ? 40 : -40)
                    logFlick.contentY = Math.max(0, Math.min(logFlick.contentHeight - logFlick.height, logFlick.contentY - delta))
                    event.accepted = true
                }
            }
        }

        Rectangle {
            antialiasing: Theme.shapesAa
            Layout.fillWidth: true; Layout.preferredHeight: 52
            radius: 0
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
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.isInstall ? (root.busy ? "Installiere…" : "Enter: installieren · Tab: Feld wechseln") : (bodyRoot.scope.filteredWebApps.length + " Web Apps · Enter: entfernen")
                    font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(11)
                    color: Theme.textMuted
                }
                Rectangle {
                    antialiasing: Theme.shapesAa
                    visible: root.isInstall && (nameInput.text.length > 0 || urlInput.text.length > 0 || iconInput.text.length > 0)
                    Layout.preferredWidth: clearLabel.implicitWidth + 20; Layout.preferredHeight: 30; radius: 0
                    color: clearMouse.containsMouse ? (Theme.withAlpha(Theme.textPrimary, 0.08)) : "transparent"
                    border.color: Theme.withAlpha(Theme.textPrimary, 0.25); border.width: 1
                    Text { id: clearLabel; anchors.centerIn: parent; text: "Leeren"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(11); color: Theme.textSecondary
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    MouseArea {
                        id: clearMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { nameInput.text = ""; urlInput.text = ""; iconInput.text = ""; bodyRoot.scope.clearWebAppStatus(); root.fieldIdx = 0; nameInput.forceActiveFocus() }
                    }
                }
                Rectangle {
                    antialiasing: Theme.shapesAa
                    Layout.preferredWidth: primaryLabel.implicitWidth + 24; Layout.preferredHeight: 32; radius: 0
                    color: primaryMouse.containsMouse ? (root.isInstall ? Theme.withAlpha(Theme.accent, 0.92) : Theme.withAlpha(Theme.error, 0.92)) : (root.isInstall ? Theme.accent : Theme.error)
                    border.color: root.isInstall ? Theme.accent : Theme.error; border.width: 1
                    opacity: (root.busy || (root.isInstall ? (nameInput.text.trim().length === 0 || urlInput.text.trim().length === 0) : bodyRoot.scope.filteredWebApps.length === 0)) ? 0.5 : 1
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        id: primaryLabel; anchors.centerIn: parent
                        text: root.busy ? "Arbeite…" : (root.isInstall ? "Installieren" : "Entfernen")
                        font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(11); font.weight: Font.Medium; color: Theme.onAccent
                    }
                    MouseArea {
                        id: primaryMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.busy) return
                            if (root.isInstall) {
                                if (nameInput.text.trim().length === 0 || urlInput.text.trim().length === 0) return
                                root.fieldIdx = 3
                                root.doInstall()
                            } else {
                                if (bodyRoot.scope.filteredWebApps.length === 0) return
                                root.doRemove()
                            }
                        }
                    }
                }
            }
        }
    }
}
