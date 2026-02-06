// Aurora Glow Effect for AI Assistant
// Animated border glow when listening

import QtQuick
import QtQuick.Effects

Item {
    id: root
    
    property bool active: false
    property real glowSize: 20
    property color color1: "#00ff88"  // Teal
    property color color2: "#0088ff"  // Blue  
    property color color3: "#ff0088"  // Pink
    
    // Animated gradient rotation
    property real rotation: 0
    
    SequentialAnimation on rotation {
        running: root.active
        loops: Animation.Infinite
        
        NumberAnimation {
            from: 0
            to: 360
            duration: 3000
            easing.type: Easing.Linear
        }
    }
    
    // Multi-layer glow effect
    Rectangle {
        id: glowLayer1
        anchors.fill: parent
        color: "transparent"
        border.width: 2
        border.color: root.color1
        opacity: root.active ? 0.6 : 0
        radius: 12
        
        Behavior on opacity {
            NumberAnimation { duration: 300 }
        }
        
        // Pulsing animation
        SequentialAnimation on border.width {
            running: root.active
            loops: Animation.Infinite
            
            NumberAnimation {
                from: 2
                to: 4
                duration: 1000
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                from: 4
                to: 2
                duration: 1000
                easing.type: Easing.InOutSine
            }
        }
    }
    
    Rectangle {
        id: glowLayer2
        anchors.fill: parent
        anchors.margins: -2
        color: "transparent"
        border.width: 3
        border.color: root.color2
        opacity: root.active ? 0.4 : 0
        radius: 14
        
        Behavior on opacity {
            NumberAnimation { duration: 300 }
        }
    }
    
    Rectangle {
        id: glowLayer3
        anchors.fill: parent
        anchors.margins: -4
        color: "transparent"
        border.width: 2
        border.color: root.color3
        opacity: root.active ? 0.3 : 0
        radius: 16
        
        Behavior on opacity {
            NumberAnimation { duration: 300 }
        }
        
        // Counter-rotating pulse
        SequentialAnimation on border.width {
            running: root.active
            loops: Animation.Infinite
            
            NumberAnimation {
                from: 2
                to: 3
                duration: 1500
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                from: 3
                to: 2
                duration: 1500
                easing.type: Easing.InOutSine
            }
        }
    }
    
    // Outer glow particles (optional advanced effect)
    Repeater {
        model: 12
        
        Rectangle {
            property real angle: (index / 12) * 360 + root.rotation
            property real radius: (parent.width / 2) + 10
            
            x: parent.width / 2 + Math.cos(angle * Math.PI / 180) * radius - width / 2
            y: parent.height / 2 + Math.sin(angle * Math.PI / 180) * radius - height / 2
            
            width: 4
            height: 4
            radius: 2
            
            color: index % 3 === 0 ? root.color1 :
                   index % 3 === 1 ? root.color2 : root.color3
            
            opacity: root.active ? (0.5 + Math.sin(root.rotation * 2 * Math.PI / 180 + index) * 0.3) : 0
            
            Behavior on opacity {
                NumberAnimation { duration: 300 }
            }
        }
    }
}
