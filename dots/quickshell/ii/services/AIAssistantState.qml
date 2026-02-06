// AI Assistant State Manager
// Monitors /tmp/ai-assistant-state.json and provides state to UI

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // States
    enum State {
        Idle = 0,
        Listening = 1,
        Processing = 2
    }

    property int currentState: AIAssistantState.State.Idle
    property real lastUpdate: 0
    property bool glowEnabled: false

    // File watcher for state changes
    property var stateWatcher: FileWatcher {
        path: "/tmp/ai-assistant-state.json"
        
        onFileChanged: {
            root.loadState()
        }
    }

    // Timer to poll state file
    property var pollTimer: Timer {
        interval: 500  // Check every 500ms
        running: true
        repeat: true
        
        onTriggered: {
            root.loadState()
        }
    }

    function loadState() {
        const stateFile = "/tmp/ai-assistant-state.json"
        
        try {
            // Read state file
            const process = Process {
                command: ["cat", stateFile]
                running: true
            }
            
            process.finished.connect(() => {
                if (process.exitCode === 0) {
                    const data = JSON.parse(process.standardOutput)
                    
                    if (data.timestamp > root.lastUpdate) {
                        root.lastUpdate = data.timestamp
                        
                        // Update state
                        switch(data.state) {
                            case "idle":
                                root.currentState = AIAssistantState.State.Idle
                                root.glowEnabled = false
                                break
                            case "listening":
                                root.currentState = AIAssistantState.State.Listening
                                root.glowEnabled = true
                                break
                            case "processing":
                                root.currentState = AIAssistantState.State.Processing
                                root.glowEnabled = true
                                break
                        }
                        
                        console.log("AI Assistant state:", data.state)
                    }
                }
            })
            
        } catch (e) {
            // File doesn't exist yet or can't be read
        }
    }

    // Signals for UI to connect to
    signal stateChanged(int newState)
    signal glowChanged(bool enabled)

    onCurrentStateChanged: {
        stateChanged(currentState)
    }

    onGlowEnabledChanged: {
        glowChanged(glowEnabled)
    }
}
