pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/**
 * VPN status service.
 */
Singleton {
    id: root

    property bool connected: false
    property string status: "disconnected"
    property string materialSymbol: "vpn_lock"
    property int symbolFill: connected ? 1 : 0
    property color indicatorColor: connected ? "#a6e3a1" : "#f38ba8"

    // Process to check VPN status
    Process {
        id: checkVpnProcess
        command: ["bash", "-c", "if pgrep -x openvpn > /dev/null || pgrep -x wireguard > /dev/null || ip link show | grep -q tun0; then echo 'connected'; else echo 'disconnected'; fi"]

        stdout: SplitParser {
            onRead: data => {
                const status = data.trim()
                root.connected = (status === "connected")
                root.status = status
            }
        }

        onExited: (code, exitStatus) => {
            // Restart check after exit
            Qt.callLater(() => {
                if (statusTimer.running) {
                    checkVpnProcess.running = true
                }
            })
        }
    }

    // Timer to periodically check VPN status
    Timer {
        id: statusTimer
        interval: 5000 // Check every 5 seconds
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!checkVpnProcess.running) {
                checkVpnProcess.running = true
            }
        }
    }

    // Function to toggle VPN
    function toggleVpn(): void {
        const vpnScriptPath = "/home/tslove/Documents/vpn-toggle.sh"
        Quickshell.execDetached(["bash", vpnScriptPath])
        
        // Check status after a short delay
        Qt.callLater(() => {
            statusCheckDelayTimer.start()
        })
    }

    Timer {
        id: statusCheckDelayTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (!checkVpnProcess.running) {
                checkVpnProcess.running = true
            }
        }
    }
}
