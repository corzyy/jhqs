pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "../../../themes"
import ".."

Column {
    id: root
    width: parent ? parent.width : 400
    spacing: 10

    SettingsControls.SettingsSection {
        title: "Calendar"
        SettingsControls.SettingsDropdown {
            label: "Week Starts"
            options: ["sunday", "monday"]
            current: calWeekStart.currentName
            onPicked: v => calWeekStart.setStart(v)
        }
    }

    Process { id: calProc; command: ["bash", "-c", "echo"]; stdout: StdioCollector { } }
    QtObject {
        id: calWeekStart
        property string currentName: "sunday"
        function setStart(v) {
            if (v !== "sunday" && v !== "monday") return
            currentName = v
            calProc.command = ["bash", "-c", "f=~/.config/quickshell/jhqs/config/calendar.json; mkdir -p \"$(dirname \"$f\")\"; [ -f \"$f\" ] || echo '{ }' > \"$f\"; jq '.weekStartDay = \"" + v + "\"' \"$f\" > /tmp/jhqs-cal.json && mv /tmp/jhqs-cal.json \"$f\""]
            if (!calProc.running) calProc.running = true
        }
    }
    Process {
        id: calFetchProc
        command: ["bash", "-c", "jq -r '.weekStartDay // \"sunday\"' ~/.config/quickshell/jhqs/config/calendar.json 2>/dev/null | tr -d '\\n'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let o = ((text || "").trim().toLowerCase())
                calWeekStart.currentName = (o === "monday") ? "monday" : "sunday"
            }
        }
    }
    Component.onCompleted: Qt.callLater(() => { if (!calFetchProc.running) calFetchProc.running = true })
}
