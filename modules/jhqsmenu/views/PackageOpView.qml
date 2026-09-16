pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../../themes"

Item {
    id: root
    required property var scope
    required property var bodyRoot
    anchors.fill: parent
    anchors.margins: 0
    clip: true
    opacity: bodyRoot.scope.showPackages && bodyRoot.scope.packageOpActive ? 1 : 0
    visible: opacity > 0.01
    enabled: bodyRoot.scope.showPackages && bodyRoot.scope.packageOpActive
    scale: (bodyRoot.scope.showPackages && bodyRoot.scope.packageOpActive) ? 1 : 0.97
    transformOrigin: Item.Center
    Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durDefaultEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultEffects } }
    Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durFastSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial } }
    function handleKey(event): bool { return false }

    readonly property bool isRemove: bodyRoot.scope.packageOpMode === "remove" || bodyRoot.scope.packageOpMode === "flatpakremove"
    readonly property bool isFlatpak: bodyRoot.scope.packageOpMode === "flatpak" || bodyRoot.scope.packageOpMode === "flatpakremove"
    readonly property string opTitle: (root.isRemove ? "Removing " : "Installing ") + bodyRoot.scope.packageOpPkgs.length + (bodyRoot.scope.packageOpPkgs.length === 1 ? (root.isFlatpak ? " Flatpak" : " Package") : (root.isFlatpak ? " Flatpaks" : " Packages"))
    readonly property bool running: bodyRoot.scope.packageOpRunning
    readonly property bool success: bodyRoot.scope.packageOpSuccess

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true; Layout.leftMargin: 0; Layout.rightMargin: 0; spacing: 14
            Rectangle {
                antialiasing: Theme.shapesAa
                Layout.preferredWidth: 26; Layout.preferredHeight: 26; Layout.alignment: Qt.AlignVCenter
                radius: 0
                color: "transparent"
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
                Layout.preferredWidth: 42; Layout.preferredHeight: 42; radius: 0
                color: !root.running && !root.success ? Theme.withAlpha(Theme.error, 0.14) : (Theme.withAlpha(Theme.textPrimary, 0.04))
                border.color: !root.running && !root.success ? Theme.withAlpha(Theme.errorColor, 0.3) : (Theme.withAlpha(Theme.textPrimary, 0.25)); border.width: 1
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    anchors.centerIn: parent
                    text: root.running ? "󰑐" : root.success ? "✓" : "✗"
                    font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(24)
                    color: root.running ? Theme.accent : root.success ? Theme.accent : Theme.errorColor
                }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    Layout.fillWidth: true
                    text: root.opTitle
                    color: Theme.textPrimary; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(16); font.weight: Font.Bold
                    elide: Text.ElideRight
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    Layout.fillWidth: true
                    text: (root.running ? "Running in background – Esc for list" : (root.success ? "✓ Completed successfully" : "✗ Failed (code " + bodyRoot.scope.packageOpExit + ")") + " – Enter to close").toUpperCase()
                    color: root.running ? Theme.textSecondary : root.success ? Theme.accent : Theme.errorColor
                    font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(10); font.weight: Font.Bold
                    font.letterSpacing: 1.2
                    elide: Text.ElideRight
                }
            }
        }

        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            Layout.fillWidth: true; Layout.leftMargin: 0; Layout.rightMargin: 0
            text: bodyRoot.scope.packageOpPkgs.join(", ")
            color: Theme.textMuted; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(10)
            elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth: true; height: 1
            color: Theme.withAlpha(Theme.textPrimary, 0.12)
        }

        Rectangle {
            antialiasing: Theme.shapesAa
            Layout.fillWidth: true; Layout.fillHeight: true
            radius: 0; color: Theme.withAlpha(Theme.textPrimary, 0.04)
            border.color: Theme.withAlpha(Theme.textPrimary, 0.25); border.width: 1; clip: true
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
                    color: Theme.textSecondary; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(11)
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
            Layout.fillWidth: true; Layout.preferredHeight: 36; radius: 0
            color: backMouse.containsMouse ? (Theme.withAlpha(Theme.textPrimary, 0.08)) : "transparent"
            border.color: Theme.withAlpha(Theme.textPrimary, 0.25); border.width: 1
            Text { anchors.centerIn: parent; text: root.running ? "Back to list (still running)" : "Back to list"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(12); font.weight: Font.Medium; color: Theme.textPrimary
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bodyRoot.scope.leavePackageOp() }
        }
    }
}
