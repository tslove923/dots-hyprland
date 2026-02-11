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

            root.updateHistories()
            interval = Config.options?.resources?.updateInterval ?? 3000
        }
	}

	FileView { id: fileMeminfo; path: "/proc/meminfo" }
    FileView { id: fileStat; path: "/proc/stat" }
    FileView { id: fileCpuCurFreq; path: "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq" }
    FileView { id: fileCpuMaxFreq; path: "/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq" }
    FileView { id: fileGpuActFreq; path: "/sys/class/drm/card0/device/tile0/gt0/freq0/act_freq" }
    FileView { id: fileGpuMaxFreq; path: "/sys/class/drm/card0/device/tile0/gt0/freq0/max_freq" }

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

    // GPU monitoring - supports both i915 (intel_gpu_top) and Xe (fdinfo) drivers
    property var previousGpuCycles: ({})
    
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
        command: ["bash", "-c", "if which intel_gpu_top > /dev/null 2>&1; then result=$(intel_gpu_top -J -s 100 2>/dev/null | head -1); if [ -n \"$result\" ] && echo \"$result\" | grep -q engines; then echo \"$result\"; exit 0; fi; fi; total_cycles_rcs=0; total_cycles_total_rcs=0; total_cycles_vcs=0; total_cycles_total_vcs=0; total_cycles_ccs=0; total_cycles_total_ccs=0; count=0; for fdinfo in /proc/*/fdinfo/*; do if [ -f \"$fdinfo\" ]; then if grep -q \"drm-driver.*xe\" \"$fdinfo\" 2>/dev/null; then cycles_rcs=$(grep \"drm-cycles-rcs:\" \"$fdinfo\" 2>/dev/null | awk '{print $2}'); total_rcs=$(grep \"drm-total-cycles-rcs:\" \"$fdinfo\" 2>/dev/null | awk '{print $2}'); cycles_vcs=$(grep \"drm-cycles-vcs:\" \"$fdinfo\" 2>/dev/null | awk '{print $2}'); total_vcs=$(grep \"drm-total-cycles-vcs:\" \"$fdinfo\" 2>/dev/null | awk '{print $2}'); cycles_ccs=$(grep \"drm-cycles-ccs:\" \"$fdinfo\" 2>/dev/null | awk '{print $2}'); total_ccs=$(grep \"drm-total-cycles-ccs:\" \"$fdinfo\" 2>/dev/null | awk '{print $2}'); if [ -n \"$cycles_rcs\" ]; then total_cycles_rcs=$((total_cycles_rcs + cycles_rcs)); total_cycles_total_rcs=$((total_cycles_total_rcs + total_rcs)); total_cycles_vcs=$((total_cycles_vcs + cycles_vcs)); total_cycles_total_vcs=$((total_cycles_total_vcs + total_vcs)); total_cycles_ccs=$((total_cycles_ccs + cycles_ccs)); total_cycles_total_ccs=$((total_cycles_total_ccs + total_ccs)); count=$((count + 1)); fi; fi; fi; done; if [ $count -gt 0 ]; then echo \"xe_fdinfo:$total_cycles_rcs:$total_cycles_total_rcs:$total_cycles_vcs:$total_cycles_total_vcs:$total_cycles_ccs:$total_cycles_total_ccs\"; exit 0; fi; echo \"unavailable\""]
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
                
                // Parse Xe driver fdinfo (drm-cycles)
                if (output.startsWith("xe_fdinfo:")) {
                    try {
                        const parts = output.split(":")
                        const cycles_rcs = parseInt(parts[1])
                        const total_rcs = parseInt(parts[2])
                        const cycles_vcs = parseInt(parts[3])
                        const total_vcs = parseInt(parts[4])
                        const cycles_ccs = parseInt(parts[5])
                        const total_ccs = parseInt(parts[6])
                        
                        // Calculate usage for each engine type
                        let totalUsage = 0
                        let engineCount = 0
                        
                        // Render/Compute engine (RCS)
                        if (root.previousGpuCycles.rcs !== undefined && total_rcs > root.previousGpuCycles.total_rcs) {
                            const cyclesDiff = cycles_rcs - root.previousGpuCycles.rcs
                            const totalDiff = total_rcs - root.previousGpuCycles.total_rcs
                            if (totalDiff > 0) {
                                totalUsage += cyclesDiff / totalDiff
                                engineCount++
                            }
                        }
                        
                        // Video engine (VCS)
                        if (root.previousGpuCycles.vcs !== undefined && total_vcs > root.previousGpuCycles.total_vcs) {
                            const cyclesDiff = cycles_vcs - root.previousGpuCycles.vcs
                            const totalDiff = total_vcs - root.previousGpuCycles.total_vcs
                            if (totalDiff > 0) {
                                totalUsage += cyclesDiff / totalDiff
                                engineCount++
                            }
                        }
                        
                        // Compute engine (CCS)
                        if (root.previousGpuCycles.ccs !== undefined && total_ccs > root.previousGpuCycles.total_ccs) {
                            const cyclesDiff = cycles_ccs - root.previousGpuCycles.ccs
                            const totalDiff = total_ccs - root.previousGpuCycles.total_ccs
                            if (totalDiff > 0) {
                                totalUsage += cyclesDiff / totalDiff
                                engineCount++
                            }
                        }
                        
                        // Store current values for next iteration
                        root.previousGpuCycles = {
                            rcs: cycles_rcs,
                            total_rcs: total_rcs,
                            vcs: cycles_vcs,
                            total_vcs: total_vcs,
                            ccs: cycles_ccs,
                            total_ccs: total_ccs
                        }
                        
                        if (engineCount > 0) {
                            root.gpuUsage = totalUsage / engineCount
                            root.gpuAvailable = true
                        } else {
                            // First run, no previous data
                            root.gpuUsage = 0
                            root.gpuAvailable = true
                        }
                        return
                    } catch (e) {
                        console.log("Error parsing GPU fdinfo:", e)
                    }
                }
                
                // No GPU detected
                if (output !== "unavailable") {
                    root.gpuAvailable = false
                }
            }
        }
    }

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
