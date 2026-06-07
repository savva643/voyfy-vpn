import NetworkExtension
import Network
import OSLog

/// Forwards TCP packets from TUN interface to SOCKS5 proxy.
/// This is a simplified implementation. For production, consider using
/// Tun2SocksKit or a complete tun2socks library.
class PacketForwarder {
    private let logger = Logger(subsystem: "com.keeppixel.voyfy", category: "PacketForwarder")
    
    private let packetFlow: NEPacketTunnelFlow
    private let socks5Address: String
    private var isRunning = false
    private var activeConnections: [String: NWConnection] = [:]
    private let connectionQueue = DispatchQueue(label: "com.keeppixel.voyfy.connections", qos: .utility)
    
    init(packetFlow: NEPacketTunnelFlow, socks5Address: String) {
        self.packetFlow = packetFlow
        self.socks5Address = socks5Address
    }
    
    func start() {
        isRunning = true
        logger.info("PacketForwarder starting...")
        readPackets()
    }
    
    func stop() {
        isRunning = false
        logger.info("PacketForwarder stopping...")
        
        connectionQueue.sync {
            for (_, connection) in activeConnections {
                connection.cancel()
            }
            activeConnections.removeAll()
        }
    }
    
    private func readPackets() {
        guard isRunning else { return }
        
        packetFlow.readPacketObjects { [weak self] packets in
            guard let self = self, self.isRunning else { return }
            
            for packet in packets {
                self.handlePacket(packet)
            }
            
            // Continue reading
            self.readPackets()
        }
    }
    
    private func handlePacket(_ packet: NEPacket) {
        let data = packet.data
        guard data.count >= 20 else { return } // Minimum IPv4 header
        
        let version = (data[0] >> 4) & 0x0F
        guard version == 4 else { return } // Only IPv4 for now
        
        let protocolNumber = data[9]
        let srcIP = "\(data[12]).\(data[13]).\(data[14]).\(data[15])"
        let dstIP = "\(data[16]).\(data[17]).\(data[18]).\(data[19])"
        
        let headerLength = Int((data[0] & 0x0F) * 4)
        guard data.count > headerLength + 4 else { return }
        
        let srcPort = (UInt16(data[headerLength]) << 8) | UInt16(data[headerLength + 1])
        let dstPort = (UInt16(data[headerLength + 2]) << 8) | UInt16(data[headerLength + 3])
        
        let connectionKey = "\(srcIP):\(srcPort)->\(dstIP):\(dstPort)"
        
        if protocolNumber == 6 { // TCP
            handleTcpPacket(data: data, srcIP: srcIP, srcPort: srcPort, dstIP: dstIP, dstPort: dstPort, key: connectionKey)
        } else if protocolNumber == 17 { // UDP
            // UDP packets are handled by UdpForwarder
            // This is a simplified architecture
        }
    }
    
    private func handleTcpPacket(data: Data, srcIP: String, srcPort: UInt16, dstIP: String, dstPort: UInt16, key: String) {
        // Check for existing connection
        if let connection = activeConnections[key], connection.state == .ready {
            // Forward data through existing connection
            let payload = data.subdata(in: Int((data[0] & 0x0F) * 4)..<data.count)
            connection.send(content: payload, completion: .contentProcessed { _ in })
        } else {
            // Create new SOCKS5 connection
            connectToSocks5(dstIP: dstIP, dstPort: dstPort, key: key) { [weak self] connection in
                guard let self = self, let connection = connection else { return }
                self.activeConnections[key] = connection
                
                // Send initial payload
                let headerLength = Int((data[0] & 0x0F) * 4)
                let payload = data.subdata(in: headerLength..<data.count)
                if !payload.isEmpty {
                    connection.send(content: payload, completion: .contentProcessed { _ in })
                }
            }
        }
    }
    
    private func connectToSocks5(dstIP: String, dstPort: UInt16, key: String, completion: @escaping (NWConnection?) -> Void) {
        let parts = socks5Address.components(separatedBy: ":")
        guard parts.count == 2,
              let proxyHost = parts.first,
              let proxyPort = UInt16(parts[1]) else {
            logger.error("Invalid SOCKS5 address: \(socks5Address)")
            completion(nil)
            return
        }
        
        let endpoint = NWEndpoint.hostPort(host: .name(proxyHost, nil), port: .integer(proxyPort))
        let connection = NWConnection(endpoint: endpoint, using: .tcp)
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.performSocks5Handshake(connection: connection, dstIP: dstIP, dstPort: dstPort) { success in
                    if success {
                        completion(connection)
                    } else {
                        connection.cancel()
                        completion(nil)
                    }
                }
            case .failed(let error):
                self?.logger.error("SOCKS5 connection failed: \(error.localizedDescription)")
                completion(nil)
            case .cancelled:
                break
            default:
                break
            }
        }
        
        connection.start(queue: connectionQueue)
    }
    
    private func performSocks5Handshake(connection: NWConnection, dstIP: String, dstPort: UInt16, completion: @escaping (Bool) -> Void) {
        // SOCKS5 handshake: no auth
        let greeting = Data([0x05, 0x01, 0x00])
        
        connection.send(content: greeting, completion: .contentProcessed { [weak self] error in
            if let error = error {
                self?.logger.error("SOCKS5 greeting send failed: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            connection.receive(minimumIncompleteLength: 2, maximumLength: 2) { [weak self] data, _, isComplete, error in
                guard let data = data, data.count == 2, data[0] == 0x05, data[1] == 0x00 else {
                    self?.logger.error("SOCKS5 auth failed")
                    completion(false)
                    return
                }
                
                // Send CONNECT request
                var request: [UInt8] = [0x05, 0x01, 0x00, 0x01] // VER, CMD, RSV, ATYP(IPv4)
                let ipParts = dstIP.components(separatedBy: ".").compactMap { UInt8($0) }
                guard ipParts.count == 4 else {
                    completion(false)
                    return
                }
                request.append(contentsOf: ipParts)
                request.append(UInt8(dstPort >> 8))
                request.append(UInt8(dstPort & 0xFF))
                
                connection.send(content: Data(request), completion: .contentProcessed { [weak self] error in
                    if let error = error {
                        self?.logger.error("SOCKS5 connect send failed: \(error.localizedDescription)")
                        completion(false)
                        return
                    }
                    
                    connection.receive(minimumIncompleteLength: 10, maximumLength: 22) { data, _, _, error in
                        guard let data = data, data.count >= 10, data[1] == 0x00 else {
                            self?.logger.error("SOCKS5 connect failed")
                            completion(false)
                            return
                        }
                        completion(true)
                    }
                })
            }
        })
    }
}

/// Simplified UDP forwarder using UDP-over-TCP or UDP-in-UDP relay.
/// For production, this should be more robust.
class UdpForwarder {
    private let logger = Logger(subsystem: "com.keeppixel.voyfy", category: "UdpForwarder")
    
    private let packetFlow: NEPacketTunnelFlow
    private let socks5Address: String
    private var isRunning = false
    
    init(packetFlow: NEPacketTunnelFlow, socks5Address: String) {
        self.packetFlow = packetFlow
        self.socks5Address = socks5Address
    }
    
    func start() {
        isRunning = true
        logger.info("UdpForwarder starting (placeholder - UDP relay requires SOCKS5 UDP ASSOCIATE)")
        // UDP forwarding is complex and requires SOCKS5 UDP ASSOCIATE support.
        // For a production app, integrate a complete tun2socks library like
        // hev-socks5-tunnel compiled for iOS.
    }
    
    func stop() {
        isRunning = false
    }
}
