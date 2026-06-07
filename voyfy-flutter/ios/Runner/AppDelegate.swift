import UIKit
import Flutter
import NetworkExtension
import OSLog

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    
    private let logger = Logger(subsystem: "com.keeppixel.voyfy", category: "AppDelegate")
    private var vpnManager: NETunnelProviderManager?
    private var vpnStatusObserver: NSObjectProtocol?
    
    // Method channels
    private var vpnChannel: FlutterMethodChannel?
    private var vpnDataChannel: FlutterMethodChannel?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        setupMethodChannels()
        loadVPNPreferences()
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // MARK: - Method Channels
    
    private func setupMethodChannels() {
        guard let controller = window?.rootViewController as? FlutterViewController else { return }
        
        let binaryMessenger = controller.binaryMessenger
        
        vpnChannel = FlutterMethodChannel(
            name: "com.voyfy.vpn/ios",
            binaryMessenger: binaryMessenger
        )
        
        vpnDataChannel = FlutterMethodChannel(
            name: "com.voyfy.vpn/ios_data",
            binaryMessenger: binaryMessenger
        )
        
        vpnChannel?.setMethodCallHandler { [weak self] call, result in
            self?.handleVpnCall(call, result: result)
        }
    }
    
    private func handleVpnCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            result(true)
            
        case "connect":
            guard let args = call.arguments as? [String: Any],
                  let config = args["config"] as? String else {
                result(FlutterError(code: "INVALID_CONFIG", message: "Config required", details: nil))
                return
            }
            connectVPN(config: config, result: result)
            
        case "disconnect":
            disconnectVPN(result: result)
            
        case "getStatus":
            let status = vpnManager?.connection.status
            result(statusToString(status))
            
        case "ping":
            // iOS doesn't have a native ping API accessible from app
            result(-1)
            
        case "testConfig":
            // Basic validation
            result(true)
            
        case "getDataUsage":
            // Data usage from packet tunnel extension is not directly accessible
            result(["bytesReceived": 0, "bytesSent": 0])
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - VPN Management
    
    private func loadVPNPreferences() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            if let error = error {
                self?.logger.error("Failed to load VPN preferences: \(error.localizedDescription)")
                return
            }
            
            if let managers = managers, !managers.isEmpty {
                self?.vpnManager = managers.first
            } else {
                self?.createVPNManager()
            }
            
            // Setup status observer
            self?.setupStatusObserver()
        }
    }
    
    private func createVPNManager() {
        let manager = NETunnelProviderManager()
        
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = "com.keeppixel.voyfy.VoyfyTunnel"
        proto.serverAddress = "127.0.0.1"
        proto.providerConfiguration = [:]
        
        manager.protocolConfiguration = proto
        manager.localizedDescription = "Voyfy VPN"
        manager.isEnabled = true
        
        manager.saveToPreferences { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to save VPN preferences: \(error.localizedDescription)")
                return
            }
            self?.vpnManager = manager
            self?.setupStatusObserver()
        }
    }
    
    private func setupStatusObserver() {
        // Remove old observer
        if let observer = vpnStatusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        vpnStatusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: vpnManager?.connection,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            let status = self.vpnManager?.connection.status
            let statusStr = self.statusToString(status)
            self.logger.info("VPN status changed: \(statusStr)")
            self.vpnChannel?.invokeMethod("onStatusChanged", arguments: statusStr)
        }
    }
    
    private func connectVPN(config: String, result: @escaping FlutterResult) {
        guard let manager = vpnManager else {
            result(FlutterError(code: "NO_MANAGER", message: "VPN manager not available", details: nil))
            return
        }
        
        // Update protocol configuration with Hysteria2 config
        if let proto = manager.protocolConfiguration as? NETunnelProviderProtocol {
            proto.providerConfiguration = ["config": config as NSString]
            manager.protocolConfiguration = proto
        }
        
        do {
            try manager.connection.startVPNTunnel()
            result("OK")
        } catch {
            logger.error("Failed to start VPN tunnel: \(error.localizedDescription)")
            result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
        }
    }
    
    private func disconnectVPN(result: @escaping FlutterResult) {
        guard let manager = vpnManager else {
            result(false)
            return
        }
        
        manager.connection.stopVPNTunnel()
        result(true)
    }
    
    private func statusToString(_ status: NEVPNStatus?) -> String {
        switch status {
        case .invalid: return "error"
        case .disconnected: return "disconnected"
        case .connecting: return "connecting"
        case .connected: return "connected"
        case .reasserting: return "connecting"
        case .disconnecting: return "disconnecting"
        default: return "unknown"
        }
    }
    
    deinit {
        if let observer = vpnStatusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
