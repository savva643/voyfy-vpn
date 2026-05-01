import Foundation
import NetworkExtension
import FlutterMacOS

class VpnService: NSObject {
    static let shared = VpnService()
    
    private var vpnManager: NETunnelProviderManager?
    private var flutterChannel: FlutterMethodChannel?
    private var flutterDataChannel: FlutterMethodChannel?
    
    private var xrayTask: Process?
    private var configPath: String?
    
    var isConnected: Bool = false
    var bytesReceived: Int64 = 0
    var bytesSent: Int64 = 0
    
    override init() {
        super.init()
        loadVPNPreferences()
    }
    
    func initialize(channel: FlutterMethodChannel, dataChannel: FlutterMethodChannel) {
        flutterChannel = channel
        flutterDataChannel = dataChannel
        
        // Set up status callback
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(vpnStatusDidChange(_:)),
            name: NSNotification.Name.NEVPNStatusDidChange,
            object: nil
        )
    }
    
    private func loadVPNPreferences() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            if let error = error {
                print("Failed to load VPN preferences: \(error)")
                return
            }
            
            if let managers = managers, !managers.isEmpty {
                self?.vpnManager = managers.first
            } else {
                self?.createVPNManager()
            }
        }
    }
    
    private func createVPNManager() {
        let manager = NETunnelProviderManager()
        
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = "com.keeppixel.voyfy.tunnel"
        proto.serverAddress = "127.0.0.1"
        manager.protocolConfiguration = proto
        
        manager.localizedDescription = "Voyfy VPN"
        manager.isEnabled = true
        
        manager.saveToPreferences { [weak self] error in
            if let error = error {
                print("Failed to save VPN preferences: \(error)")
                return
            }
            self?.vpnManager = manager
        }
    }
    
    func connect(config: String) -> Bool {
        // Save config to temp file
        let tempDir = FileManager.default.temporaryDirectory
        let configURL = tempDir.appendingPathComponent("voyfy_config.json")
        
        do {
            try config.write(to: configURL, atomically: true, encoding: .utf8)
            configPath = configURL.path
        } catch {
            print("Failed to save config: \(error)")
            return false
        }
        
        // Start Xray
        if !startXray(configPath: configURL.path) {
            return false
        }
        
        // Start VPN tunnel
        guard let manager = vpnManager else {
            print("VPN manager not available")
            return false
        }
        
        do {
            try manager.connection.startVPNTunnel()
            isConnected = true
            
            // Start monitoring data usage
            startDataMonitoring()
            
            return true
        } catch {
            print("Failed to start VPN: \(error)")
            stopXray()
            return false
        }
    }
    
    func disconnect() -> Bool {
        guard let manager = vpnManager else {
            return false
        }
        
        manager.connection.stopVPNTunnel()
        stopXray()
        
        isConnected = false
        return true
    }
    
    private func startXray(configPath: String) -> Bool {
        // Get Xray path from app bundle
        guard let xrayPath = Bundle.main.path(forResource: "xray", ofType: nil) else {
            // Try to find in the same directory as the app
            let fileManager = FileManager.default
            let possiblePaths = [
                Bundle.main.bundlePath + "/xray",
                Bundle.main.bundlePath + "/../xray",
                "/usr/local/bin/xray",
                "/opt/voyfy/xray"
            ]
            
            var foundPath: String?
            for path in possiblePaths {
                if fileManager.fileExists(atPath: path) {
                    foundPath = path
                    break
                }
            }
            
            guard let xray = foundPath else {
                print("Xray binary not found")
                return false
            }
            
            return startXrayProcess(xrayPath: xray, configPath: configPath)
        }
        
        return startXrayProcess(xrayPath: xrayPath, configPath: configPath)
    }
    
    private func startXrayProcess(xrayPath: String, configPath: String) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: xrayPath)
        task.arguments = ["-c", configPath]
        
        do {
            try task.run()
            xrayTask = task
            return true
        } catch {
            print("Failed to start Xray: \(error)")
            return false
        }
    }
    
    private func stopXray() {
        xrayTask?.terminate()
        xrayTask = nil
    }
    
    private func startDataMonitoring() {
        // Monitor data usage via Xray API or network statistics
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isConnected else { return }
            
            // Get network statistics
            self.updateDataUsage()
            
            // Send to Flutter
            let args: [String: Any] = [
                "bytesReceived": self.bytesReceived,
                "bytesSent": self.bytesSent
            ]
            
            DispatchQueue.main.async {
                self.flutterDataChannel?.invokeMethod("onDataUsageUpdated", arguments: args)
            }
        }
    }
    
    private func updateDataUsage() {
        // For macOS, we can get interface statistics
        // This is a simplified version - in production, you'd use more sophisticated methods
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        
        guard getifaddrs(&ifaddr) == 0 else { return }
        defer { freeifaddrs(ifaddr) }
        
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            
            let interface = ptr?.pointee
            let name = String(cString: (interface?.ifa_name)!)
            
            // Look for TUN interface
            if name.hasPrefix("utun") {
                if let data = interface?.ifa_data {
                    let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                    bytesReceived = Int64(networkData.ifi_ibytes)
                    bytesSent = Int64(networkData.ifi_obytes)
                }
            }
        }
    }
    
    @objc private func vpnStatusDidChange(_ notification: Notification) {
        guard let connection = notification.object as? NEVPNConnection else { return }
        
        var status = "unknown"
        switch connection.status {
        case .connected:
            status = "connected"
            isConnected = true
        case .connecting:
            status = "connecting"
        case .disconnected:
            status = "disconnected"
            isConnected = false
        case .disconnecting:
            status = "disconnecting"
        case .invalid:
            status = "error"
        case .reasserting:
            status = "connecting"
        @unknown default:
            status = "unknown"
        }
        
        flutterChannel?.invokeMethod("onStatusChanged", arguments: status)
    }
    
    func getDataUsage() -> (received: Int64, sent: Int64) {
        return (bytesReceived, bytesSent)
    }
}
