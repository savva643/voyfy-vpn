import NetworkExtension
import Network
import OSLog

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private let logger = Logger(subsystem: "com.keeppixel.voyfy", category: "PacketTunnelProvider")
    
    // MARK: - Properties
    
    /// Hysteria2 config YAML content
    private var hysteria2Config: String?
    
    /// SOCKS5 proxy address (Hysteria2 listens here)
    private var socks5Address: String = "127.0.0.1:1080"
    
    /// Packet forwarder handles TUN <-> SOCKS5 routing
    private var packetForwarder: PacketForwarder?
    
    /// UDP forwarder for UDP relay
    private var udpForwarder: UdpForwarder?
    
    // MARK: - NEPacketTunnelProvider Lifecycle
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        logger.info("Starting Voyfy tunnel...")
        
        guard let options = options,
              let configString = options["config"] as? String else {
            logger.error("No config provided in options")
            completionHandler(NSError(domain: "VoyfyTunnel", code: 1,
                                      userInfo: [NSLocalizedDescriptionKey: "No Hysteria2 config provided"]))
            return
        }
        
        self.hysteria2Config = configString
        
        // Parse config to extract SOCKS5 listen address
        if let socksAddr = parseSocks5Address(from: configString) {
            self.socks5Address = socksAddr
            logger.info("SOCKS5 address: \(socksAddr)")
        }
        
        // 1. Configure and bring up TUN interface
        setupTunnelNetworkSettings { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to set tunnel network settings: \(error.localizedDescription)")
                completionHandler(error)
                return
            }
            
            self?.logger.info("TUN interface configured successfully")
            
            // 2. Start Hysteria2 (via Go Mobile framework or binary)
            // NOTE: On iOS, you cannot spawn subprocesses in Network Extensions.
            // Hysteria2 must be compiled as a Go Mobile framework and linked.
            // See BUILD_INSTRUCTIONS.md for how to build Hysteria2 for iOS.
            self?.startHysteria2 { success in
                if !success {
                    self?.logger.error("Failed to start Hysteria2")
                    // Continue anyway - SOCKS5 might already be running from main app
                }
                
                // 3. Start packet forwarding (TUN -> SOCKS5)
                self?.startPacketForwarding()
                
                self?.logger.info("Tunnel started successfully")
                completionHandler(nil)
            }
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.info("Stopping Voyfy tunnel... reason: \(reason.rawValue)")
        
        // Stop packet forwarding
        packetForwarder?.stop()
        packetForwarder = nil
        
        udpForwarder?.stop()
        udpForwarder = nil
        
        // Stop Hysteria2
        stopHysteria2()
        
        logger.info("Tunnel stopped")
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Handle messages from the main app if needed
        // e.g. config updates, stats requests
        completionHandler?(nil)
    }
    
    // MARK: - Private Methods
    
    private func setupTunnelNetworkSettings(completion: @escaping (Error?) -> Void) {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        
        // IPv4 configuration
        let ipv4Settings = NEIPv4Settings(addresses: ["172.19.0.1"], subnetMasks: ["255.255.255.252"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4Settings
        
        // IPv6 - disable for simplicity, can be added later
        settings.ipv6Settings = nil
        
        // DNS - use system DNS (Hysteria2 handles DNS via SOCKS5/HTTP proxy)
        // Or set specific DNS servers if needed
        let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "1.1.1.1"])
        settings.dnsSettings = dnsSettings
        
        // MTU
        settings.mtu = NSNumber(value: 1500)
        
        setTunnelNetworkSettings(settings) { error in
            completion(error)
        }
    }
    
    // MARK: - Hysteria2 Integration
    
    /// Start Hysteria2 client.
    /// NOTE: This requires Hysteria2 compiled as a Go Mobile framework.
    /// Replace this stub with actual framework calls once built.
    private func startHysteria2(completion: @escaping (Bool) -> Void) {
        // TODO: Integrate Hysteria2 Go Mobile framework here.
        // Example (once framework is built):
        //
        // import Hysteria2
        // Hysteria2Start(hysteria2Config)
        //
        // For now, if Hysteria2 is started from the main app and bound to 127.0.0.1,
        // the extension can connect to its SOCKS5 port.
        
        // Give Hysteria2 time to start (if running in main app)
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            completion(true)
        }
    }
    
    private func stopHysteria2() {
        // TODO: Stop Hysteria2 Go Mobile framework
        // Hysteria2Stop()
    }
    
    // MARK: - Packet Forwarding
    
    private func startPacketForwarding() {
        guard let flow = self.packetFlow else {
            logger.error("No packet flow available")
            return
        }
        
        logger.info("Starting packet forwarding to SOCKS5: \(socks5Address)")
        
        let forwarder = PacketForwarder(packetFlow: flow, socks5Address: socks5Address)
        self.packetForwarder = forwarder
        forwarder.start()
        
        // UDP forwarding
        let udp = UdpForwarder(packetFlow: flow, socks5Address: socks5Address)
        self.udpForwarder = udp
        udp.start()
    }
    
    // MARK: - Config Parsing
    
    private func parseSocks5Address(from config: String) -> String? {
        // Parse YAML config to extract socks5.listen address
        let lines = config.components(separatedBy: .newlines)
        var inSocks5Section = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("socks5:") {
                inSocks5Section = true
                continue
            }
            
            if inSocks5Section {
                if trimmed.hasPrefix("listen:") {
                    let parts = trimmed.components(separatedBy: ":")
                    if parts.count >= 3 {
                        let addr = parts[1].trimmingCharacters(in: .whitespaces)
                        let port = parts[2].trimmingCharacters(in: .whitespaces)
                        return "\(addr):\(port)"
                    }
                }
                // Exit socks5 section if we hit another top-level key
                if trimmed.first?.isLetter == true && !trimmed.hasPrefix(" ") {
                    break
                }
            }
        }
        
        return "127.0.0.1:1080" // Default
    }
}
