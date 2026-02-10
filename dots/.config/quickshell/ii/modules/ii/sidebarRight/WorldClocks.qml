import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1
    implicitHeight: clockColumn.implicitHeight + 20

    // Add/remove cities here. Use IANA timezone names.
    property var worldClocks: [
        { city: "Chandler, AZ",   tz: "America/Phoenix",       flag: "🇺🇸" },
        { city: "San José, CR",   tz: "America/Costa_Rica",    flag: "🇨🇷" },
        { city: "Penang",         tz: "Asia/Kuala_Lumpur",     flag: "🇲🇾" },
        { city: "Haifa",          tz: "Asia/Jerusalem",        flag: "🇮🇱" },
        { city: "Bangalore",      tz: "Asia/Kolkata",          flag: "🇮🇳" },
        { city: "Taipei",         tz: "Asia/Taipei",           flag: "🇹🇼" },
    ]

    // Holds the resolved times: { "America/Phoenix": "14:30|09", ... }
    property var tzTimes: ({})

    // Build the shell command that prints time and day for each tz
    function buildCommand() {
        let parts = [];
        for (let i = 0; i < worldClocks.length; i++) {
            const tz = worldClocks[i].tz;
            parts.push(`echo "$(TZ='${tz}' date +'%-I:%M %p|%d')"`);
        }
        return parts.join("; ");
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            tzProc.running = true;
        }
    }

    // Re-trigger when the minute changes
    Connections {
        target: DateTime.clock
        function onDateChanged() {
            tzProc.running = true;
        }
    }

    Process {
        id: tzProc
        command: ["bash", "-c", root.buildCommand()]
        running: true
        stdout: StdioCollector {
            id: tzOutput
            onStreamFinished: {
                const lines = tzOutput.text.trim().split("\n");
                let result = {};
                for (let i = 0; i < lines.length && i < root.worldClocks.length; i++) {
                    result[root.worldClocks[i].tz] = lines[i].trim();
                }
                root.tzTimes = result;
            }
        }
    }

    ColumnLayout {
        id: clockColumn
        anchors.fill: parent
        anchors.margins: 10
        spacing: 4

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            MaterialSymbol {
                text: "public"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnLayer1
            }

            StyledText {
                text: Translation.tr("World Clocks")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.bold: true
                color: Appearance.colors.colOnLayer1
            }
        }

        // Separator
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Appearance.colors.colOnLayer1
            opacity: 0.12
        }

        // Clock rows
        Repeater {
            model: root.worldClocks

            RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    text: modelData.flag
                    font.pixelSize: Appearance.font.pixelSize.small
                }

                StyledText {
                    text: modelData.city
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                    Layout.fillWidth: true
                }

                StyledText {
                    property string tzData: root.tzTimes[modelData.tz] ?? ""
                    property string tzTime: tzData ? tzData.split("|")[0] : "--:--"
                    text: tzTime
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.family: Appearance.font.family.numbers
                    color: Appearance.colors.colSubtext
                    horizontalAlignment: Text.AlignRight
                }

                StyledText {
                    property string tzData: root.tzTimes[modelData.tz] ?? ""
                    property string tzDay: tzData ? tzData.split("|")[1] : ""
                    property string localDay: {
                        const now = DateTime.clock.date;
                        const d = now.getDate();
                        return String(d).padStart(2, '0');
                    }
                    property string dayDiff: {
                        if (!tzDay || !localDay) return "";
                        const tz = parseInt(tzDay);
                        const local = parseInt(localDay);
                        if (tz > local) return "+1d";
                        if (tz < local) return "−1d";
                        return "";
                    }
                    visible: dayDiff !== ""
                    text: dayDiff
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                    opacity: 0.7
                }
            }
        }
    }
}
