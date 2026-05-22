pragma Singleton
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

/**
 * A nice wrapper for date and time strings.
 */
Singleton {
    id: root

    property alias inhibit: idleInhibitor.enabled
    inhibit: false

    Connections {
        target: Persistent
        function onReadyChanged() {
            if (!Persistent.isNewHyprlandInstance) {
                root.inhibit = Persistent.states.idle.inhibit;
            } else {
                Persistent.states.idle.inhibit = root.inhibit;
            }
        }
    }

    function toggleInhibit(active = null) {
        if (active !== null) {
            root.inhibit = active;
        } else {
            root.inhibit = !root.inhibit;
        }
        Persistent.states.idle.inhibit = root.inhibit;
    }

    function notifyInhibitState() {
        Quickshell.execDetached([
            "notify-send",
            "Caffeine",
            root.inhibit ? "Idle inhibitor enabled" : "Idle inhibitor disabled",
            "-a", "Illogical Impulse"
        ])
    }

    IpcHandler {
        target: "idle"

        function toggle(): void {
            root.toggleInhibit()
            root.notifyInhibitState()
        }

        function enable(): void {
            root.toggleInhibit(true)
            root.notifyInhibitState()
        }

        function disable(): void {
            root.toggleInhibit(false)
            root.notifyInhibitState()
        }
    }

    IdleInhibitor {
        id: idleInhibitor
        window: PanelWindow {
            // Inhibitor requires a "visible" surface
            // Actually not lol
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"
            // Just in case...
            anchors {
                right: true
                bottom: true
            }
            // Make it not interactable
            mask: Region {
                item: null
            }
        }
    }
}
