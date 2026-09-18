pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../themes"
import "../Ui"
import QtQuick.Effects

Scope {
    id: lockScope
    property bool locked: false
    property string pinInput: ""
    property bool failed: false
    property string errorText: ""
    property string wallpaperPath: ""
    readonly property string wallpaperSource: wallpaperPath !== "" ? "file://" + wallpaperPath : ""

    // Einziger Reset-Pfad für den PIN-Zustand (war 3x kopiert).
    function resetPinState(): void {
        pinInput = ""
        failed = false
        errorText = ""
    }
    function lock(): void {
        if (locked) return
        resetPinState()
        refreshWallpaper()
        locked = true
    }
    function unlock(): void {
        locked = false
        resetPinState()
    }
    function refreshWallpaper(): void {
        if (!wallpaperResolveProc.running) wallpaperResolveProc.running = true
    }
    function submitPin(): void {
        if (pinInput.length === 0) return
        clearPinError()
        authProc.command = [Quickshell.shellDir + "/scripts/lock-auth.sh", pinInput]
        if (!authProc.running) authProc.running = true
    }

    // Fehler-Reset ohne die gerade eingegebene PIN zu löschen.
    function clearPinError(): void {
        failed = false
        errorText = ""
    }

    Process {
        id: wallpaperResolveProc
        command: ["bash", "-c", "for f in \"$(cat ~/.config/quickshell/jhqs/config/current_wallpaper.txt 2>/dev/null)\" \"$(cat ~/.cache/swaybg/current 2>/dev/null)\" \"$(cat ~/.cache/awww/current 2>/dev/null)\"; do f=\"${f#file://}\"; if [ -n \"$f\" ] && [ -f \"$f\" ]; then printf '%s' \"$f\"; exit 0; fi; done"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: lockScope.wallpaperPath = String(text || "").trim()
        }
    }
    Component.onCompleted: refreshWallpaper()

    Process {
        id: authProc
        stdout: StdioCollector { }
        stderr: StdioCollector { }
        onExited: (code) => {
            if (code === 0) {
                lockScope.unlock()
            } else {
                lockScope.failed = true
                lockScope.errorText = "Wrong PIN"
                lockScope.pinInput = ""
                failTimer.restart()
            }
        }
    }
    Timer {
        id: failTimer
        interval: 1500
        onTriggered: lockScope.clearPinError()
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: lockScope.locked
            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "lockscreen"
            WlrLayershell.keyboardFocus: Theme.isPrimaryScreen(modelData) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            anchors { top: true; left: true; right: true; bottom: true }

            Item {
                id: contentRoot
                anchors.fill: parent
                clip: false
                // Lock-in: M3 fade through (fade + settle from 92%) driven by
                // one shared progress so background, clock and PIN all move
                // together. Unlock exit is instant (the window unmaps).
                Motion {
                    id: lockMotion
                    active: lockScope.locked
                    pattern: Motion.FadeThrough
                }
                opacity: lockMotion.opacity

                Image {
                    smooth: Theme.imageSmooth
                    mipmap: Theme.imageMipmap
                    id: bgImage
                    anchors.fill: parent
                    source: lockScope.wallpaperSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    opacity: lockMotion.opacity
                }
                Rectangle {
                    antialiasing: Theme.shapesAa
                    id: fallbackBg
                    anchors.fill: parent
                    color: Theme.bg
                    visible: bgImage.status !== Image.Ready || bgImage.source === ""
                }
                Rectangle {
                    antialiasing: Theme.shapesAa
                    anchors.fill: parent
                    color: Theme.scrim
                    opacity: 0.20 * lockMotion.opacity
                }

                Item {
                    id: topClock
                    visible: Theme.isPrimaryScreen(modelData)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Math.round(parent.height * 0.24)
                    width: clockCol.implicitWidth
                    height: clockCol.implicitHeight
                    opacity: lockMotion.opacity
                    scale: 0.96 + 0.04 * lockMotion.opacity
                    transform: Translate { y: (1 - lockMotion.opacity) * -18 }
                    SystemClock { id: lockClock; enabled: lockScope.locked && Theme.isPrimaryScreen(modelData); precision: SystemClock.Minutes }
                    // iOS-style stacked clock: rounded variable-font digits
                    // (Google Sans Flex, ROND axis), hours over minutes with
                    // tight leading, then the date underneath.
                    readonly property int clockFontSize: Math.max(64, Math.round(parent.height * 0.18))
                    Column {
                        id: clockCol
                        anchors.centerIn: parent
                        spacing: Theme.fs(16)
                        Column {
                            id: clockDigits
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: -Math.round(topClock.clockFontSize * 0.26)
                            Text {
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Qt.formatDateTime(lockClock.date, "HH")
                                color: Theme.textPrimary
                                font.family: "Google Sans Flex"
                                font.pixelSize: topClock.clockFontSize
                                font.weight: Font.Light
                                font.variableAxes: ({ "ROND": 100, "wght": 300 })
                                font.letterSpacing: -topClock.clockFontSize * 0.02
                                horizontalAlignment: Text.AlignHCenter
                                opacity: 0.97
                            }
                            Text {
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Qt.formatDateTime(lockClock.date, "mm")
                                color: Theme.textPrimary
                                font.family: "Google Sans Flex"
                                font.pixelSize: topClock.clockFontSize
                                font.weight: Font.Light
                                font.variableAxes: ({ "ROND": 100, "wght": 300 })
                                font.letterSpacing: -topClock.clockFontSize * 0.02
                                horizontalAlignment: Text.AlignHCenter
                                opacity: 0.97
                            }
                        }
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDateTime(lockClock.date, "ddd, MMM d")
                            color: Theme.textPrimary
                            font.family: "Google Sans Flex"
                            font.pixelSize: Theme.fs(18)
                            font.weight: Font.DemiBold
                            opacity: 0.9
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                    // PERF: shadow passes gated on locked (were 3 always-on
                    // offscreen passes, even when the lockscreen hid).
                    layer.enabled: lockScope.locked
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Theme.withAlpha(Theme.scrim, 0.40)
                        shadowBlur: 0.9
                        shadowOpacity: 0.38
                        shadowVerticalOffset: 6
                    }
                }

                TextInput {
                    id: pinField
                    anchors.fill: parent
                    visible: false
                    focus: lockScope.locked && Theme.isPrimaryScreen(modelData)
                    activeFocusOnTab: Theme.isPrimaryScreen(modelData)
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    text: lockScope.pinInput
                    onTextChanged: if (text !== lockScope.pinInput) lockScope.pinInput = text
                    Connections {
                        target: lockScope
                        function onPinInputChanged() { if (pinField.text !== lockScope.pinInput) pinField.text = lockScope.pinInput }
                    }
                    onAccepted: lockScope.submitPin()
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            lockScope.pinInput = ""
                            pinField.text = ""
                            event.accepted = true
                        }
                    }
                }
                MouseArea { anchors.fill: parent; onClicked: pinField.forceActiveFocus() }
                onVisibleChanged: if (visible) Qt.callLater(() => pinField.forceActiveFocus())
                Connections {
                    target: lockScope
                    function onLockedChanged() { if (lockScope.locked) Qt.callLater(() => pinField.forceActiveFocus()) }
                }

                Item {
                    id: pinContainer
                    visible: Theme.isPrimaryScreen(modelData)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 185
                    width: 360; height: 150
                    opacity: lockMotion.opacity
                    scale: 0.96 + 0.04 * lockMotion.opacity
                    property real shakeOffset: 0
                    // Denied PIN: short standard-easing shake (collapses when
                    // animations are off).
                    readonly property int shakeStep: Theme.animationsEnabled ? 60 : 0
                    transform: Translate { y: (1 - lockMotion.opacity) * 24; x: pinContainer.shakeOffset }
                    Connections {
                        target: lockScope
                        function onFailedChanged() { if (lockScope.failed) shakeAnim.restart() }
                    }
                    SequentialAnimation {
                        id: shakeAnim
                        NumberAnimation { target: pinContainer; property: "shakeOffset"; to: -12; duration: pinContainer.shakeStep; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveStandardAccel }
                        NumberAnimation { target: pinContainer; property: "shakeOffset"; to: 10; duration: pinContainer.shakeStep; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveStandard }
                        NumberAnimation { target: pinContainer; property: "shakeOffset"; to: -6; duration: pinContainer.shakeStep; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveStandard }
                        NumberAnimation { target: pinContainer; property: "shakeOffset"; to: 4; duration: pinContainer.shakeStep; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveStandard }
                        NumberAnimation { target: pinContainer; property: "shakeOffset"; to: 0; duration: pinContainer.shakeStep; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveStandardDecel }
                    }
                    ColumnLayout {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        spacing: 18
                        width: parent.width
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            Layout.alignment: Qt.AlignHCenter
                            width: 44; height: 44; radius: Theme.cornerRadius
                            color: Theme.withAlpha(Theme.surface2, lockScope.failed ? 0.85 : 0.52)
                            border.color: lockScope.failed ? Theme.errorColor : Theme.withAlpha(Theme.outline, 0.18)
                            border.width: 1
                            Text {
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                anchors.centerIn: parent
                                text: "󰌾"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fs(16)
                                color: lockScope.failed ? Theme.errorColor : Theme.textPrimary
                                opacity: lockScope.failed ? 1.0 : 0.9
                            }
                        }
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            id: pinBox
                            Layout.alignment: Qt.AlignHCenter
                            width: 320; height: 56
                            radius: Theme.cornerRadius
                            color: lockScope.failed ? Theme.withAlpha(Theme.error, 0.18) : Theme.withAlpha(Theme.surface2, 0.62)
                            border.color: lockScope.failed ? Theme.errorColor : (pinField.activeFocus ? Theme.primary : Theme.withAlpha(Theme.outline, 0.22))
                            border.width: lockScope.failed || pinField.activeFocus ? 1.6 : 1
                            layer.enabled: lockScope.locked
                            layer.effect: MultiEffect {
                                shadowEnabled: true
                                shadowColor: Theme.withAlpha(Theme.scrim, 0.25)
                                shadowBlur: 0.7
                                shadowOpacity: 0.28
                                shadowVerticalOffset: 4
                            }
                            Row {
                                id: dotRow
                                anchors.centerIn: parent
                                spacing: 14
                                visible: lockScope.pinInput.length > 0
                                // PERF: fixed 12 dots (was model: pinInput.length,
                                // creating/destroying delegates per keystroke).
                                Repeater {
                                    model: 12
                                    delegate: Rectangle {
                                        required property int index
                                        width: 12; height: 12; radius: Theme.cornerRadiusSmall
                                        color: lockScope.failed ? Theme.errorColor : Theme.textPrimary
                                        opacity: 0.95
                                        visible: index < lockScope.pinInput.length
                                    }
                                }
                            }
                            Text {
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                anchors.centerIn: parent
                                visible: lockScope.pinInput.length === 0
                                text: lockScope.failed ? lockScope.errorText : "Enter PIN  •  Enter"
                                color: lockScope.failed ? Theme.errorColor : Theme.withAlpha(Theme.textPrimary, 0.62)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fs(13)
                                font.weight: Font.Medium
                                font.letterSpacing: 0.4
                                horizontalAlignment: Text.AlignHCenter
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: pinField.forceActiveFocus() }
                        }
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            Layout.alignment: Qt.AlignHCenter
                            visible: lockScope.failed
                            text: lockScope.errorText
                            color: Theme.errorColor
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(12)
                            font.weight: Font.Medium
                            opacity: 0.95
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            Layout.alignment: Qt.AlignHCenter
                            visible: !lockScope.failed && lockScope.pinInput.length === 0
                            text: "Unlock with PIN or system password"
                            color: Theme.withAlpha(Theme.textPrimary, 0.42)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(11)
                            font.letterSpacing: 0.2
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "lockscreen"
        function lock(): void { lockScope.lock() }
        function unlock(): void { lockScope.unlock() }
        function toggle(): void { if (lockScope.locked) lockScope.unlock(); else lockScope.lock() }
        function isLocked(): string { return lockScope.locked ? "true" : "false" }
    }
}
