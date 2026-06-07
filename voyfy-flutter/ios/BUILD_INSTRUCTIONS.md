# iOS VPN Setup Instructions

This document explains how to complete the iOS VPN implementation for Voyfy.

## Architecture

The iOS VPN uses a **Packet Tunnel Provider** Network Extension:
- **Main App** (`Runner`): Flutter app that controls the VPN via `NETunnelProviderManager`
- **Network Extension** (`VoyfyTunnel`): Runs in background, creates TUN interface, forwards packets to Hysteria2 SOCKS5 proxy

## Prerequisites

- macOS with Xcode 14+
- Apple Developer account (for signing and Network Extension entitlement)
- Go 1.21+ installed (for building Hysteria2 framework)
- gomobile installed: `go install golang.org/x/mobile/cmd/gomobile@latest`

## Step 1: Xcode Project Setup (Required)

Since Network Extensions cannot be added via files alone, you must configure the Xcode project:

### 1.1 Add Network Extension Target

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the project in the navigator, then click **+** under "Targets"
3. Choose **Network Extension** → **Packet Tunnel Provider**
4. Configure:
   - **Product Name**: `VoyfyTunnel`
   - **Team**: Your Apple Developer team
   - **Language**: Swift
   - **Include UI Extension**: No (not needed)

### 1.2 Configure Target Settings

For the **VoyfyTunnel** target:
1. **General** tab:
   - Set Bundle Identifier to: `com.keeppixel.voyfy.VoyfyTunnel`
   - Ensure it matches the `providerBundleIdentifier` in `AppDelegate.swift`

2. **Signing & Capabilities** tab:
   - Add `Packet Tunnel` capability
   - Add `App Groups` capability with group: `group.com.keeppixel.voyfy`

3. **Build Settings** tab:
   - Set **iOS Deployment Target** to `12.0` or higher

### 1.3 Add Source Files to Extension Target

1. In Xcode, right-click the `VoyfyTunnel` folder and select **Add Files to "VoyfyTunnel"...**
2. Select these files (ensure "Copy items if needed" is **NOT** checked):
   - `ios/VoyfyTunnel/PacketTunnelProvider.swift`
   - `ios/VoyfyTunnel/PacketForwarder.swift`
3. Make sure both files are added to the **VoyfyTunnel** target (check the target membership in the file inspector)

### 1.4 Replace Auto-Generated Files

Xcode generated `PacketTunnelProvider.swift` in the extension. Replace its contents with the version from `ios/VoyfyTunnel/PacketTunnelProvider.swift`.

### 1.5 Configure Runner Target

For the **Runner** target:
1. **Signing & Capabilities** tab:
   - Add `Packet Tunnel` capability
   - Add `App Groups` capability with group: `group.com.keeppixel.voyfy`

### 1.6 Update Info.plist for Extension

Replace the auto-generated `VoyfyTunnel/Info.plist` with the one from `ios/VoyfyTunnel/Info.plist`.

## Step 2: Build Hysteria2 for iOS (Required)

The Packet Tunnel Provider needs Hysteria2 running as a library. On iOS, you cannot spawn subprocesses in extensions, so Hysteria2 must be compiled as a Go Mobile framework.

### 2.1 Clone Hysteria2

```bash
cd ~/Documents
git clone https://github.com/apernet/hysteria.git
cd hysteria
```

### 2.2 Create Go Mobile Binding

Create a wrapper package that exposes Hysteria2's client functionality:

**`hysteria-ios/mobile.go`**:
```go
package hysteria

import (
    "context"
    "github.com/apernet/hysteria/app/cmd"
    "github.com/spf13/cobra"
)

func Start(config string) {
    // Parse YAML config and start client
    // This is a simplified example - you'll need to adapt based on
    // Hysteria2's actual API
    go func() {
        rootCmd := cmd.RootCmd
        rootCmd.SetArgs([]string{"-c", "/dev/stdin"})
        // You'd need to pass config via stdin or temp file
        rootCmd.Execute()
    }()
}

func Stop() {
    // Implement stop logic
}
```

### 2.3 Build the Framework

```bash
cd ~/Documents/hysteria

# Initialize gomobile
gomobile init

# Build framework for iOS
gomobile bind -target=ios -o Hysteria2.xcframework ./hysteria-ios
```

This produces `Hysteria2.xcframework`.

### 2.4 Add Framework to Xcode Project

1. Drag `Hysteria2.xcframework` into the Xcode project
2. In the **General** tab of the **VoyfyTunnel** target, add `Hysteria2.xcframework` to **Frameworks, Libraries, and Embedded Content**
3. Set embed option to **Embed & Sign**

### 2.5 Update PacketTunnelProvider.swift

Once the framework is linked, replace the `startHysteria2` stub in `PacketTunnelProvider.swift`:

```swift
import Hysteria2

private func startHysteria2(completion: @escaping (Bool) -> Void) {
    guard let config = hysteria2Config else {
        completion(false)
        return
    }
    
    // Write config to shared app group container
    if let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.keeppixel.voyfy") {
        let configURL = sharedURL.appendingPathComponent("hysteria2.yaml")
        try? config.write(to: configURL, atomically: true, encoding: .utf8)
        
        // Start Hysteria2 via framework
        Hysteria2Start(configURL.path)
    }
    
    DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
        completion(true)
    }
}

private func stopHysteria2() {
    Hysteria2Stop()
}
```

## Step 3: Alternative Approach - Use Pre-built Libraries

If building Hysteria2 from source is too complex, consider these alternatives:

### Option A: Use sing-box
- sing-box supports Hysteria2 and can be built for iOS
- It provides a `box.Box` API that can be called from Swift
- Repository: `https://github.com/SagerNet/sing-box`

### Option B: Use Tun2SocksKit + Separate Hysteria2
- Use `Tun2SocksKit` (Swift Package Manager) for packet routing
- Run Hysteria2 in the main app process (binds to localhost)
- Extension connects to Hysteria2's SOCKS5 port on localhost

This is the **easiest approach** for initial implementation:

1. Add `Tun2SocksKit` via Swift Package Manager:
   - URL: `https://github.com/EbrahimTahernejad/Tun2SocksKit`

2. In `PacketTunnelProvider.swift`:
```swift
import Tun2SocksKit

// In startTunnel():
// Start Hysteria2 in main app before calling startVPNTunnel()
// Then in extension:
Tun2SocksKit.start(tunFd: tunFd, socks5Addr: "127.0.0.1:1080")
```

Note: For this approach, Hysteria2 must run in the main app and bind to `127.0.0.1:1080` before the tunnel starts.

## Step 4: Build and Run

1. In Xcode, select the **Runner** scheme and your device
2. Build and run (`Cmd+R`)
3. The first time you start the VPN, iOS will prompt to allow the VPN configuration

## Troubleshooting

### "Packet Tunnel Provider" capability not available
- Ensure your Apple Developer account has the Network Extension entitlement
- You may need to request it from Apple for non-enterprise accounts

### Extension not found
- Verify the bundle identifier in `AppDelegate.swift` matches the extension target
- Check that the extension target is included in the scheme

### Hysteria2 framework not linking
- Ensure the framework is added to the **VoyfyTunnel** target, not just the project
- Check that `Embed & Sign` is selected

### VPN starts but no traffic
- Check that Hysteria2 is actually running and bound to `127.0.0.1:1080`
- Check `NEPacketTunnelFlow` is reading/writing packets correctly
- Review logs in Console.app filtering by `com.keeppixel.voyfy`

## Apple App Store Considerations

- Network Extension apps require special review from Apple
- You must explain why you need the `com.apple.developer.networking.networkextension` entitlement
- VPN apps are subject to additional scrutiny
- Consider using TestFlight for initial testing

## Files Created/Modified

- `ios/VoyfyTunnel/PacketTunnelProvider.swift` - Network Extension entry point
- `ios/VoyfyTunnel/PacketForwarder.swift` - Packet routing logic
- `ios/VoyfyTunnel/Info.plist` - Extension configuration
- `ios/VoyfyTunnel/VoyfyTunnel.entitlements` - Extension capabilities
- `ios/Runner/AppDelegate.swift` - Flutter MethodChannel for VPN control
- `ios/Runner/Runner.entitlements` - Added App Groups
- `lib/services/vpn_service.dart` - Added iOS platform support
