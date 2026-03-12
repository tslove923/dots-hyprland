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

    // CPU frequency (MHz)
    property int cpuFreqMhz: 0
    property int cpuMaxFreqMhz: 0
    // GPU frequency (MHz)
    property int gpuFreqMhz: 0
    property int gpuMaxFreqMhz: 0
    // GPU idle residency tracking (gtidle method, like nvtop)
    property real previousGpuIdleMs: -1
    property real previousGpuTimestamp: -1

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
		interval: Config.options?.resources?.updateInterval ?? 3000
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

            // Read CPU frequency (kHz -> MHz)
            fileCpuCurFreq.reload()
            fileCpuMaxFreq.reload()
            const curFreqKhz = parseInt(fileCpuCurFreq.text()) || 0
            const maxFreqKhz = parseInt(fileCpuMaxFreq.text()) || 0
            cpuFreqMhz = Math.round(curFreqKhz / 1000)
            cpuMaxFreqMhz = Math.round(maxFreqKhz / 1000)

            // Read GPU frequency (already in MHz)
            fileGpuActFreq.reload()
            fileGpuMaxFreq.reload()
            const gpuAct = parseInt(fileGpuActFreq.text()) || 0
            const gpuMax = parseInt(fileGpuMaxFreq.text()) || 0
            gpuFreqMhz = gpuAct
            gpuMaxFreqMhz = gpuMax

            // GPU utilization via GT idle residency (like nvtop/mission center)
            // Read idle_residency_ms and compute busy = 1 - idle_delta / wall_delta
            fileGpuIdleResidency.reload()
            const idleMs = parseFloat(fileGpuIdleResidency.text()) || 0
            if (idleMs > 0) {
                root.gpuAvailable = true
                const now = Date.now()
                if (root.previousGpuIdleMs >= 0 && root.previousGpuTimestamp >= 0) {
                    const idleDelta = idleMs - root.previousGpuIdleMs
                    const wallDelta = now - root.previousGpuTimestamp  // ms
                    if (wallDelta > 0) {
                        root.gpuUsage = Math.max(0, Math.min(1, 1 - (idleDelta / wallDelta)))
                    }
                }
                root.previousGpuIdleMs = idleMs
                root.previousGpuTimestamp = now
            }

            root.updateHistories()
        }
	}

	FileView { id: fileMeminfo; path: "/proc/meminfo" }
    FileView { id: fileStat; path: "/proc/stat" }
    FileView { id: fileCpuCurFreq; path: "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq" }
    FileView { id: fileCpuMaxFreq; path: "/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq" }
    FileView { id: fileGpuActFreq; path: "/sys/class/drm/card0/device/tile0/gt0/freq0/act_freq" }
    FileView { id: fileGpuMaxFreq; path: "/sys/class/drm/card0/device/tile0/gt0/freq0/max_freq" }
    FileView { id: fileGpuIdleResidency; path: "/sys/class/drm/card0/device/tile0/gt0/gtidle/idle_residency_ms" }

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

    // GPU availability is now determined by gtidle sysfs in the main timer above.
    // The old approach spawned a bash process every 3s that scanned ~10K /proc/*/fdinfo/* files,
    // which caused high CPU usage. Now we read a single sysfs file: gtidle/idle_residency_ms
    // This matches how nvtop/mission center compute Intel GPU utilization.


    // NPU monitoring via npu_busy_time_us (actual compute utilization)
    // Also reads frequency and memory utilization from sysfs
    property real previousNpuBusyUs: -1
    property real previousNpuTimestamp: -1
    property string npuStatus: "suspended"
    property string npuDeviceName: ""
    property int npuFreqMhz: 0
    property int npuMaxFreqMhz: 0
    property real npuMemoryBytes: 0

    Timer {
        id: npuMonitorTimer
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            npuCheckProc.running = true
        }
    }

    // Detect NPU device name and max frequency at startup
    Process {
        id: npuNameProc
        environment: ({ LANG: "C", LC_ALL: "C" })
        command: ["bash", "-c", "lspci | grep -i 'Processing accelerators.*NPU' | sed 's/.*: //'"]
        running: true
        stdout: StdioCollector {
            id: npuNameOutput
            onStreamFinished: {
                const name = npuNameOutput.text.trim()
                if (name) root.npuDeviceName = name
            }
        }
    }

    Process {
        id: npuCheckProc
        environment: ({ LANG: "C", LC_ALL: "C" })
        command: ["bash", "-c", "DEV=/sys/class/accel/accel0/device; if [ -e $DEV/npu_busy_time_us ]; then echo \"$(cat $DEV/npu_busy_time_us)|$(cat $DEV/power/runtime_status)|$(cat $DEV/npu_current_frequency_mhz)|$(cat $DEV/npu_max_frequency_mhz)|$(cat $DEV/npu_memory_utilization)\"; else echo 'unavailable'; fi"]
        running: false
        stdout: StdioCollector {
            id: npuOutputCollector
            onStreamFinished: {
                const output = npuOutputCollector.text.trim()
                if (output === "unavailable") {
                    root.npuAvailable = false
                    root.npuUsage = 0
                    return
                }

                root.npuAvailable = true
                const parts = output.split("|")
                const busyUs = parseFloat(parts[0])
                root.npuStatus = parts[1] || "unknown"
                root.npuFreqMhz = parseInt(parts[2]) || 0
                root.npuMaxFreqMhz = parseInt(parts[3]) || 0
                root.npuMemoryBytes = parseFloat(parts[4]) || 0

                const now = Date.now()

                if (root.previousNpuBusyUs >= 0 && root.previousNpuTimestamp >= 0) {
                    const busyDiffUs = busyUs - root.previousNpuBusyUs
                    const wallDiffUs = (now - root.previousNpuTimestamp) * 1000 // ms → μs

                    if (wallDiffUs > 0) {
                        const usage = Math.min(busyDiffUs / wallDiffUs, 1.0)
                        root.npuUsage = Math.max(usage, 0)
                    }
                } else {
                    root.npuUsage = 0
                }

                root.previousNpuBusyUs = busyUs
                root.previousNpuTimestamp = now
            }
        }
    }
}
