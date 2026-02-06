pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Simple polled resource usage service with RAM, Swap, and CPU usage.
 */
Singleton {
    id: root
	property real memoryTotal: 1
	property real memoryFree: 0
	property real memoryUsed: memoryTotal - memoryFree
    property real memoryUsedPercentage: memoryUsed / memoryTotal
    property real swapTotal: 1
	property real swapFree: 0
	property real swapUsed: swapTotal - swapFree
    property real swapUsedPercentage: swapTotal > 0 ? (swapUsed / swapTotal) : 0
    property real cpuUsage: 0
    property var previousCpuStats
    property real gpuUsage: 0
    property real npuUsage: 0
    property bool gpuAvailable: false
    property bool npuAvailable: false

    property string maxAvailableMemoryString: kbToGbString(ResourceUsage.memoryTotal)
    property string maxAvailableSwapString: kbToGbString(ResourceUsage.swapTotal)
    property string maxAvailableCpuString: "--"
    property string maxAvailableGpuString: "100%"
    property string maxAvailableNpuString: "100%"

    readonly property int historyLength: Config?.options.resources.historyLength ?? 60
    property list<real> cpuUsageHistory: []
    property list<real> memoryUsageHistory: []
    property list<real> swapUsageHistory: []
    property list<real> gpuUsageHistory: []
    property list<real> npuUsageHistory: []

    function kbToGbString(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    function updateMemoryUsageHistory() {
        memoryUsageHistory = [...memoryUsageHistory, memoryUsedPercentage]
        if (memoryUsageHistory.length > historyLength) {
            memoryUsageHistory.shift()
        }
    }
    function updateSwapUsageHistory() {
        swapUsageHistory = [...swapUsageHistory, swapUsedPercentage]
        if (swapUsageHistory.length > historyLength) {
            swapUsageHistory.shift()
        }
    }
    function updateCpuUsageHistory() {
        cpuUsageHistory = [...cpuUsageHistory, cpuUsage]
        if (cpuUsageHistory.length > historyLength) {
            cpuUsageHistory.shift()
        }
    }
    function updateGpuUsageHistory() {
        gpuUsageHistory = [...gpuUsageHistory, gpuUsage]
        if (gpuUsageHistory.length > historyLength) {
            gpuUsageHistory.shift()
        }
    }
    function updateNpuUsageHistory() {
        npuUsageHistory = [...npuUsageHistory, npuUsage]
        if (npuUsageHistory.length > historyLength) {
            npuUsageHistory.shift()
        }
    }
    function updateHistories() {
        updateMemoryUsageHistory()
        updateSwapUsageHistory()
        updateCpuUsageHistory()
        if (gpuAvailable) updateGpuUsageHistory()
        if (npuAvailable) updateNpuUsageHistory()
    }

	Timer {
		interval: 1
        running: true 
        repeat: true
		onTriggered: {
            // Reload files
            fileMeminfo.reload()
            fileStat.reload()

            // Parse memory and swap usage
            const textMeminfo = fileMeminfo.text()
            memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 1)
            memoryFree = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0)
            swapTotal = Number(textMeminfo.match(/SwapTotal: *(\d+)/)?.[1] ?? 1)
            swapFree = Number(textMeminfo.match(/SwapFree: *(\d+)/)?.[1] ?? 0)

            // Parse CPU usage
            const textStat = fileStat.text()
            const cpuLine = textStat.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
            if (cpuLine) {
                const stats = cpuLine.slice(1).map(Number)
                const total = stats.reduce((a, b) => a + b, 0)
                const idle = stats[3]

                if (previousCpuStats) {
                    const totalDiff = total - previousCpuStats.total
                    const idleDiff = idle - previousCpuStats.idle
                    cpuUsage = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0
                }

                previousCpuStats = { total, idle }
            }

            root.updateHistories()
            interval = Config.options?.resources?.updateInterval ?? 3000
        }
	}

	FileView { id: fileMeminfo; path: "/proc/meminfo" }
    FileView { id: fileStat; path: "/proc/stat" }

    Process {
        id: findCpuMaxFreqProc
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        command: ["bash", "-c", "lscpu | grep 'CPU max MHz' | awk '{print $4}'"]
        running: true
        stdout: StdioCollector {
            id: outputCollector
            onStreamFinished: {
                root.maxAvailableCpuString = (parseFloat(outputCollector.text) / 1000).toFixed(0) + " GHz"
            }
        }
    }

    // GPU monitoring - supports both i915 (intel_gpu_top) and Xe (sysfs) drivers
    Timer {
        id: gpuMonitorTimer
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            gpuMonitorProc.running = true
        }
    }

    Process {
        id: gpuMonitorProc
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        command: ["bash", "-c", `
            # Try intel_gpu_top for i915 driver
            if which intel_gpu_top > /dev/null 2>&1; then
                result=$(intel_gpu_top -J -s 100 2>/dev/null | head -1)
                if [ -n "$result" ] && echo "$result" | grep -q engines; then
                    echo "$result"
                    exit 0
                fi
            fi
            
            # Fallback for Xe driver - monitor via fdinfo and power state
            if [ -e /sys/class/drm/card0/device/power_state ]; then
                power_state=$(cat /sys/class/drm/card0/device/power_state)
                
                # Get active GPU clients from fdinfo
                total_usage=0
                count=0
                for fdinfo in /proc/*/fdinfo/*; do
                    if [ -f "$fdinfo" ]; then
                        client=$(grep -h "drm-client-id" "$fdinfo" 2>/dev/null)
                        if [ -n "$client" ]; then
                            # Found a DRM client, check for usage
                            usage=$(grep "drm-engine-render" "$fdinfo" 2>/dev/null | awk '{print $2}')
                            if [ -n "$usage" ]; then
                                count=$((count + 1))
                            fi
                        fi
                    fi
                done
                
                # Simple heuristic: D0 + active clients = estimate usage
                if [ "$power_state" = "D0" ] && [ $count -gt 0 ]; then
                    # Estimate 30% base usage when active with clients
                    echo "xe_active:$count"
                elif [ "$power_state" = "D0" ]; then
                    echo "xe_idle"
                else
                    echo "xe_suspended"
                fi
                exit 0
            fi
            
            echo "unavailable"
        `]
        running: false
        stdout: StdioCollector {
            id: gpuOutputCollector
            onStreamFinished: {
                const output = gpuOutputCollector.text.trim()
                
                // Try parsing intel_gpu_top JSON
                if (output.startsWith('{')) {
                    try {
                        const data = JSON.parse(output)
                        if (data && data.engines) {
                            let totalBusy = 0
                            let engineCount = 0
                            for (const engineName in data.engines) {
                                const engine = data.engines[engineName]
                                if (engine.busy !== undefined) {
                                    totalBusy += engine.busy
                                    engineCount++
                                }
                            }
                            if (engineCount > 0) {
                                root.gpuUsage = totalBusy / engineCount / 100
                                root.gpuAvailable = true
                                return
                            }
                        }
                    } catch (e) {}
                }
                
                // Parse Xe driver status
                if (output.startsWith("xe_active:")) {
                    const clients = parseInt(output.split(":")[1])
                    root.gpuUsage = Math.min(0.3 + (clients * 0.15), 1.0)  // Rough estimate
                    root.gpuAvailable = true
                } else if (output === "xe_idle") {
                    root.gpuUsage = 0.05  // Idle but powered on
                    root.gpuAvailable = true
                } else if (output === "xe_suspended") {
                    root.gpuUsage = 0
                    root.gpuAvailable = true
                } else if (output !== "unavailable") {
                    root.gpuAvailable = false
                }
            }
        }
    }

    // NPU monitoring via sysfs
    Timer {
        id: npuMonitorTimer
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            npuCheckProc.running = true
        }
    }

    Process {
        id: npuCheckProc
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        command: ["bash", "-c", "if [ -e /sys/class/accel/accel0/device/power/runtime_status ]; then status=$(cat /sys/class/accel/accel0/device/power/runtime_status); if [ \"$status\" = \"active\" ]; then echo 1; else echo 0; fi; else echo -1; fi"]
        running: false
        stdout: StdioCollector {
            id: npuOutputCollector
            onStreamFinished: {
                const status = parseInt(npuOutputCollector.text.trim())
                if (status >= 0) {
                    root.npuAvailable = true
                    // Active = 1 (100%), Suspended = 0 (0%)
                    // This is a simplified metric - actual NPU load would need more sophisticated monitoring
                    root.npuUsage = status
                } else {
                    root.npuAvailable = false
                    root.npuUsage = 0
                }
            }
        }
    }
}
