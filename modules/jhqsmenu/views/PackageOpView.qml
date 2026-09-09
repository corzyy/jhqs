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
    opacity: bodyRoot.scope.showPackages && bodyRoot.scope.packageOpActive ? 1 : 0
    visible: opacity > 0.01
    enabled: bodyRoot.scope.showPackages && bodyRoot.scope.packageOpActive
    scale: (bodyRoot.scope.showPackages && bodyRoot.scope.packageOpActive) ? 1 : 0.97
    transformOrigin: Item.Center
    Behavior on opacity { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingSmooth } }
    Behavior on scale { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingSmooth } }
    function handleKey(event): bool { return false }

    readonly property bool isRemove: bodyRoot.scope.packageOpMode === "remove" || bodyRoot.scope.packageOpMode === "flatpakremove"
    readonly property bool isFlatpak: bodyRoot.scope.packageOpMode === "flatpak" || bodyRoot.scope.packageOpMode === "flatpakremove"
    readonly property string opTitle: (root.isRemove ? "Entferne " : "Installiere ") + bodyRoot.scope.packageOpPkgs.length + (bodyRoot.scope.packageOpPkgs.length === 1 ? (root.isFlatpak ? " Flatpak" : " Paket") : (root.isFlatpak ? " Flatpaks" : " Pakete"))
    readonly property bool running: bodyRoot.scope.packageOpRunning
    readonly property bool success: bodyRoot.scope.packageOpSuccess

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true; Layout.leftMargin: root.isMinimal ? 0 : 6; Layout.rightMargin: root.isMinimal ? 0 : 6; spacing: root.isMinimal ? 14 : 8
            Rectangle {
                antialiasing: Theme.shapesAa
                Layout.preferredWidth: 26; Layout.preferredHeight: 26; Layout.alignment: Qt.AlignVCenter
                radius: root.isMinimal ? 0 : Theme.cornerRadiusSmall
                color: root.isMinimal ? "transparent" : (opBackMouse.containsMouse ? Theme.bgSelected : Theme.iconBg)
                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingSmooth } }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                    width: 26; height: 20
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    text: "‹"
                    font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(16)
                    color: opBackMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                }
                MouseArea { id: opBackMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bodyRoot.scope.leavePackageOp() }
            }
            Rectangle {
                antialiasing: Theme.shapesAa
                Layout.preferredWidth: 42; Layout.preferredHeight: 42; radius: root.isMinimal ? 0 : Theme.cornerRadiusSmall
                color: !root.running && !root.success ? Theme.withAlpha(Theme.error, 0.14) : (root.isMinimal ? Theme.withAlpha(Theme.textPrimary, 0.04) : Theme.panelSurface)
                border.color: !root.running && !root.success ? Theme.withAlpha(Theme.errorColor, 0.3) : (root.isMinimal ? Theme.withAlpha(Theme.textPrimary, 0.25) : Theme.divider); border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingSmooth } }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    anchors.centerIn: parent
                    text: root.running ? "󰑐" : root.success ? "✓" : "✗"
                    font.family: Theme.iconFontFamily; font.pixelSize: root.isMinimal ? Theme.fs(24) : Theme.fs(18)
                    color: root.running ? Theme.accent : root.success ? Theme.accent : Theme.errorColor
                    RotationAnimation on rotation {
                        running: root.running && Theme.animationsEnabled; loops: Animation.Infinite; duration: 1200
                        from: 0; to: 360; direction: RotationAnimation.Clockwise
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    Layout.fillWidth: true
                    text: root.opTitle
                    color: Theme.textPrimary; font.family: Theme.iconFontFamily; font.pixelSize: root.isMinimal ? Theme.fs(16) : Theme.fs(13); font.weight: Font.Bold
                    elide: Text.ElideRight
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    Layout.fillWidth: true
                    text: (root.running ? "Läuft im Hintergrund – Esc für Liste" : (root.success ? "✓ Erfolgreich abgeschlossen" : "✗ Fehlgeschlagen (Code " + bodyRoot.scope.packageOpExit + ")") + " – Enter zum Schließen").toUpperCase()
                    color: root.running ? Theme.textSecondary : root.success ? Theme.accent : Theme.errorColor
                    font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(10); font.weight: root.isMinimal ? Font.Bold : Font.Normal
                    font.letterSpacing: root.isMinimal ? 1.2 : 0
                    elide: Text.ElideRight
                }
            }
        }

        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            Layout.fillWidth: true; Layout.leftMargin: root.isMinimal ? 0 : 6; Layout.rightMargin: root.isMinimal ? 0 : 6
            text: bodyRoot.scope.packageOpPkgs.join(", ")
            color: Theme.textMuted; font.family: root.isMinimal ? Theme.iconFontFamily : Theme.fontFamily; font.pixelSize: Theme.fs(10)
            elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.WordWrap
        }

        Rectangle {
            visible: root.isMinimal
            Layout.fillWidth: true; height: 1
            color: Theme.withAlpha(Theme.textPrimary, 0.12)
        }

        Rectangle {
            antialiasing: Theme.shapesAa
            Layout.fillWidth: true; Layout.fillHeight: true
            radius: root.isMinimal ? 0 : Theme.cornerRadiusSmall; color: root.isMinimal ? Theme.withAlpha(Theme.textPrimary, 0.04) : Theme.panelSurface
            border.color: root.isMinimal ? Theme.withAlpha(Theme.textPrimary, 0.25) : Theme.divider; border.width: 1; clip: true
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
                    text: bodyRoot.scope.packageOpLog.length > 0 ? bodyRoot.scope.packageOpLog : "Starte…"
                    color: Theme.textSecondary; font.family: root.isMinimal ? Theme.iconFontFamily : Theme.fontFamily; font.pixelSize: Theme.fs(11)
                    wrapMode: Text.WordWrap; textFormat: Text.PlainText; lineHeight: 1.3
                }
            }
            Connections {
                target: bodyRoot.scope
                function onPackageOpLogChanged() { Qt.callLater(() => { logFlick.contentY = Math.max(0, logFlick.contentHeight - logFlick.height) }) }
                function onPackageOpActiveChanged() { if (bodyRoot.scope.packageOpActive) Qt.callLater(() => { logFlick.contentY = Math.max(0, logFlick.contentHeight - logFlick.height) }) }
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
            Layout.fillWidth: true; Layout.preferredHeight: 36; radius: root.isMinimal ? 0 : Theme.cornerRadiusSmall
            color: backMouse.containsMouse ? (root.isMinimal ? Theme.withAlpha(Theme.textPrimary, 0.08) : Theme.bgHover) : "transparent"
            border.color: root.isMinimal ? Theme.withAlpha(Theme.textPrimary, 0.25) : Theme.divider; border.width: 1
            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingSmooth } }
            Text { anchors.centerIn: parent; text: root.running ? "Zur Liste (läuft weiter)" : "Zurück zur Liste"; font.family: root.isMinimal ? Theme.iconFontFamily : Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: Font.Medium; color: Theme.textPrimary
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bodyRoot.scope.leavePackageOp() }
        }
    }
}
