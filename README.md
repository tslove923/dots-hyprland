# dots-hyprland - VPN Indicator Feature

> **Branch**: `feature/vpn-indicator`  
> **Based on**: [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)

## 🔒 VPN Status Indicator

This branch adds a VPN connection indicator to the Quickshell status bar.

### Features

- **Real-time monitoring**: Checks VPN status every 5 seconds
- **Visual indicator**: Shows vpn_lock icon in the system tray
  - 🟢 Green when connected
  - 🔴 Red when disconnected
- **Click to toggle**: Single click to run VPN toggle script
- **Multiple VPN support**: Detects OpenVPN, WireGuard, or tun0 interface

### Files Added/Modified

#### New Files
- `dots/quickshell/ii/services/VpnStatus.qml` - VPN status monitoring service

#### Modified Files
- `dots/quickshell/ii/modules/ii/bar/BarContent.qml` - Bar integration (around line 306)

### Installation

If you want to use just this feature:

```bash
# Copy the VPN service
cp dots/quickshell/ii/services/VpnStatus.qml ~/.config/quickshell/ii/services/

# Add to your BarContent.qml (around line 306, near other indicators):
MouseArea {
    Layout.fillHeight: true
    Layout.rightMargin: indicatorsRowLayout.realSpacing
    implicitWidth: vpnIcon.implicitWidth
    implicitHeight: vpnIcon.implicitHeight
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true
    onClicked: VpnStatus.toggleVpn()
    
    MaterialSymbol {
        id: vpnIcon
        anchors.centerIn: parent
        text: VpnStatus.materialSymbol
        fill: VpnStatus.symbolFill
        iconSize: Appearance.font.pixelSize.larger
        color: VpnStatus.connected ? VpnStatus.indicatorColor : rightSidebarButton.colText
    }
}

# Also add the import at the top of BarContent.qml:
import qs.services.vpnstatus
```

### Requirements

- VPN toggle script at `~/Documents/vpn-toggle.sh` (or modify the path in VpnStatus.qml)
- One of: OpenVPN, WireGuard, or any VPN that creates a tun0 interface

### How It Works

The `VpnStatus.qml` service:
1. Runs a bash command to check for VPN processes and interfaces
2. Updates the `connected` property based on findings
3. Provides a `toggleVpn()` function to execute your toggle script
4. Refreshes status after toggle with a 2-second delay

### Customization

Edit `dots/quickshell/ii/services/VpnStatus.qml` to customize:
- Check interval (default: 5000ms = 5 seconds)
- VPN detection command (line 22)
- Toggle script path (line 58)
- Colors (line 17: `indicatorColor`)

### Screenshots

[Add your screenshots here]

---

**Original Repository**: [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)  
**Customization by**: tslove923
