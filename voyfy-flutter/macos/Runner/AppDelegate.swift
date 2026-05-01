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
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }
}
