import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  
  private var vpnChannel: FlutterMethodChannel?
  private var vpnDataChannel: FlutterMethodChannel?
  
  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    
    // Setup VPN MethodChannels
    let controller = mainFlutterWindow?.contentViewController as! FlutterViewController
    let messenger = controller.engine.binaryMessenger
    
    vpnChannel = FlutterMethodChannel(name: "com.voyfy.vpn/macos", binaryMessenger: messenger)
    vpnDataChannel = FlutterMethodChannel(name: "com.voyfy.vpn/macos_data", binaryMessenger: messenger)
    
    vpnChannel?.setMethodCallHandler { [weak self] call, result in
      self?.handleMethodCall(call, result: result)
    }
    
    // Initialize VPN service
    VpnService.shared.initialize(channel: vpnChannel!, dataChannel: vpnDataChannel!)
  }
  
  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      result(true)
      
    case "connect":
      guard let args = call.arguments as? [String: Any],
            let config = args["config"] as? String else {
        result(false)
        return
      }
      let success = VpnService.shared.connect(config: config)
      result(success)
      
    case "disconnect":
      let success = VpnService.shared.disconnect()
      result(success)
      
    case "getStatus":
      // Return current VPN status
      let status = VpnService.shared.isConnected ? "connected" : "disconnected"
      result(status)
      
    case "ping":
      // Simple ping - return -1 for not implemented
      // In production, could use simple ping to server
      result(-1)
      
    case "checkAndDownloadXray":
      // Check if xray binary exists
      let fileManager = FileManager.default
      let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      let dartPath = appSupportURL?.appendingPathComponent("bin/xray").path
      
      let possiblePaths = [
        dartPath,
        Bundle.main.bundlePath + "/xray",
        Bundle.main.bundlePath + "/../xray",
        "/usr/local/bin/xray",
        "/opt/voyfy/xray"
      ]
      
      var exists = false
      for path in possiblePaths {
        if let path = path, fileManager.fileExists(atPath: path) {
          exists = true
          break
        }
      }
      result(exists)
      
    case "testConfig":
      // Test if config is valid VLESS URL
      guard let args = call.arguments as? [String: Any],
            let config = args["config"] as? String else {
        result(false)
        return
      }
      let isValid = config.hasPrefix("vless://")
      result(isValid)
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }
}
