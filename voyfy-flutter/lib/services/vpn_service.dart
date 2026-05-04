import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vless/flutter_vless.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'xray_downloader.dart';

/// Fix VLESS URL for IPv6 addresses (add brackets if missing)
String _fixVlessUrl(String url) {
  // Match vless://uuid@IPv6:port?... or vless://uuid@IPv6?...
  // IPv6 address contains multiple colons, IPv4 contains max 1 colon for port separator
  final ipv6Regex = RegExp(r'vless://([^@]+)@([0-9a-fA-F:]+:[0-9a-fA-F:]+)(:\d+)');
  final match = ipv6Regex.firstMatch(url);
  if (match != null) {
    final host = match.group(2)!;
    final port = match.group(3)!;
    // Check if host is IPv6 (contains at least 2 colons and not already in brackets)
    if (!host.startsWith('[') && host.contains(':')) {
      // Replace with bracketed IPv6 + port outside: [ipv6]:port
      return url.replaceFirst('@$host$port', '@[$host]$port');
    }
  }
  return url;
}

/// VPN Status
enum VpnStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

/// VPN Error
class VpnError {
  final String type;
  final String message;
  final String? details;

  VpnError({
    required this.type,
    required this.message,
    this.details,
  });
}

/// Data Usage
class DataUsage {
  final int bytesSent;
  final int bytesReceived;
  final DateTime timestamp;

  DataUsage({
    required this.bytesSent,
    required this.bytesReceived,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// VPN Service using flutter_vpnengine plugin
class VpnService {
  static final VpnService _instance = VpnService._internal();
  static VpnService get instance => _instance;
  factory VpnService() => _instance;
  VpnService._internal();

  StreamController<VpnStatus> _statusController = StreamController<VpnStatus>.broadcast();
  StreamController<DataUsage> _dataUsageController = StreamController<DataUsage>.broadcast();
  StreamController<VpnError> _errorController = StreamController<VpnError>.broadcast();

  // Windows MethodChannels
  static const MethodChannel _windowsChannel = MethodChannel('com.voyfy.vpn/windows');
  static const MethodChannel _windowsDataChannel = MethodChannel('com.voyfy.vpn/data');

  // Linux/macOS MethodChannels
  static const MethodChannel _linuxChannel = MethodChannel('com.voyfy.vpn/linux');
  static const MethodChannel _linuxDataChannel = MethodChannel('com.voyfy.vpn/linux_data');
  static const MethodChannel _macosChannel = MethodChannel('com.voyfy.vpn/macos');
  static const MethodChannel _macosDataChannel = MethodChannel('com.voyfy.vpn/macos_data');

  // Platform check
  bool get _isWindows => Platform.isWindows;
  bool get _isLinux => Platform.isLinux;
  bool get _isMacOS => Platform.isMacOS;
  bool get _isDesktop => _isWindows || _isLinux || _isMacOS;

  Stream<VpnStatus> get onStatusChanged => _statusController.stream;
  Stream<DataUsage> get onDataUsageUpdated => _dataUsageController.stream;
  Stream<VpnError> get onError => _errorController.stream;

  VpnStatus _currentStatus = VpnStatus.disconnected;
  VpnStatus get currentStatus => _currentStatus;

  String? _currentConfig;
  String? _currentServerName;

  /// Initialize VPN
  Future<bool> initialize() async {
    // Recreate controllers if they were closed
    if (_statusController.isClosed) {
      print('VPN SERVICE: Recreating status controller');
      _statusController = StreamController<VpnStatus>.broadcast();
    }
    if (_dataUsageController.isClosed) {
      _dataUsageController = StreamController<DataUsage>.broadcast();
    }
    if (_errorController.isClosed) {
      _errorController = StreamController<VpnError>.broadcast();
    }
    
    try {
      if (_isWindows) {
        // Setup Windows MethodChannel status listener
        _windowsChannel.setMethodCallHandler((call) async {
          print('VPN SERVICE: Method call received: ${call.method}, args: ${call.arguments}');
          if (call.method == 'onStatusChanged') {
            final statusStr = call.arguments as String;
            print('VPN SERVICE: Status update from native: $statusStr');
            final status = _parseWindowsStatus(statusStr);
            _updateStatus(status);
          }
          return null;
        });
        
        // Setup data usage channel
        _windowsDataChannel.setMethodCallHandler((call) async {
          print('VPN SERVICE: Data channel call: ${call.method}, args: ${call.arguments}');
          if (call.method == 'onDataUsageUpdated') {
            final args = call.arguments as Map<dynamic, dynamic>;
            final received = args['bytesReceived'] as int? ?? 0;
            final sent = args['bytesSent'] as int? ?? 0;
            print('VPN SERVICE: Data from native - received: $received, sent: $sent');
            _updateDataUsage(DataUsage(
              bytesReceived: received,
              bytesSent: sent,
            ));
          }
          return null;
        });
        final result = await _windowsChannel.invokeMethod<bool>('initialize');
        print('VPN SERVICE: Windows initialized');
        return result ?? false;
      } else if (_isLinux) {
        // Setup Linux MethodChannel
        _linuxChannel.setMethodCallHandler((call) async {
          if (call.method == 'onStatusChanged') {
            final statusStr = call.arguments as String;
            _updateStatus(_parseDesktopStatus(statusStr));
          }
          return null;
        });
        _linuxDataChannel.setMethodCallHandler((call) async {
          if (call.method == 'onDataUsageUpdated') {
            final args = call.arguments as Map<dynamic, dynamic>;
            _updateDataUsage(DataUsage(
              bytesReceived: args['bytesReceived'] as int? ?? 0,
              bytesSent: args['bytesSent'] as int? ?? 0,
            ));
          }
          return null;
        });
        final result = await _linuxChannel.invokeMethod<bool>('initialize');
        return result ?? false;
      } else if (_isMacOS) {
        // Setup macOS MethodChannel
        _macosChannel.setMethodCallHandler((call) async {
          if (call.method == 'onStatusChanged') {
            final statusStr = call.arguments as String;
            _updateStatus(_parseDesktopStatus(statusStr));
          }
          return null;
        });
        _macosDataChannel.setMethodCallHandler((call) async {
          if (call.method == 'onDataUsageUpdated') {
            final args = call.arguments as Map<dynamic, dynamic>;
            _updateDataUsage(DataUsage(
              bytesReceived: args['bytesReceived'] as int? ?? 0,
              bytesSent: args['bytesSent'] as int? ?? 0,
            ));
          }
          return null;
        });
        final result = await _macosChannel.invokeMethod<bool>('initialize');
        return result ?? false;
      } else {
        // Use flutter_vless for mobile (Android/iOS)
        _flutterVless = FlutterVless(onStatusChanged: _onVlessStatusChanged);
        await _flutterVless!.initializeVless(
          providerBundleIdentifier: 'com.voyfy.vpn.VPNProvider',
          groupIdentifier: 'group.com.voyfy.vpn',
        );
      }
      print('VPN SERVICE: Initialized');
      return true;
    } catch (e) {
      print('VPN SERVICE: Init error: $e');
      return false;
    }
  }

  VpnStatus _parseWindowsStatus(String status) {
    // Ignore empty status - don't change state
    if (status.isEmpty) {
      print('VPN SERVICE: Ignoring empty status update');
      return _currentStatus; // Keep current status
    }
    switch (status) {
      case 'connecting': return VpnStatus.connecting;
      case 'connected': return VpnStatus.connected;
      case 'disconnecting': return VpnStatus.disconnecting;
      case 'disconnected': return VpnStatus.disconnected;
      case 'error': return VpnStatus.error;
      default: 
        print('VPN SERVICE: Unknown status "$status", keeping current');
        return _currentStatus; // Keep current status for unknown
    }
  }

  VpnStatus _parseDesktopStatus(String status) {
    // Same logic for Linux/macOS desktop
    return _parseWindowsStatus(status);
  }

  FlutterVless? _flutterVless;

  void _onVlessStatusChanged(VlessStatus status) {
    // VlessStatus is a class, not an enum - parse from toString()
    final statusStr = status.toString().toLowerCase();
    print('VPN SERVICE: Raw VlessStatus: $status');
    print('VPN SERVICE: VlessStatus toString: $statusStr');
    
    // Try to extract status from various possible formats
    String parsedStatus = '';
    
    // Check if it's in format "VlessStatus.disconnected"
    if (statusStr.contains('.')) {
      final parts = statusStr.split('.');
      final lastPart = parts.last.trim();
      // Remove any trailing chars like ')' or ']'
      parsedStatus = lastPart.replaceAll(RegExp(r'[^a-z]'), '');
    } else {
      // Direct string representation
      parsedStatus = statusStr.replaceAll(RegExp(r'[^a-z]'), '');
    }
    
    print('VPN SERVICE: Parsed status: $parsedStatus');
    
    switch (parsedStatus) {
      case 'disconnected':
        _updateStatus(VpnStatus.disconnected);
        break;
      case 'connecting':
        _updateStatus(VpnStatus.connecting);
        break;
      case 'connected':
        _updateStatus(VpnStatus.connected);
        break;
      case 'error':
        _updateStatus(VpnStatus.error);
        break;
      default:
        print('VPN SERVICE: Unknown status "$parsedStatus", defaulting to disconnected');
        _updateStatus(VpnStatus.disconnected);
    }
  }

  VpnStatus _mapStatus(dynamic status) {
    // Fallback for compatibility
    return VpnStatus.disconnected;
  }

  /// Connect using VLESS/Xray config
  Future<bool> connect({required String config, String? serverName}) async {
    print('VPN SERVICE: connect() called, platform: Windows=$_isWindows, Linux=$_isLinux, macOS=$_isMacOS');
    try {
      _updateStatus(VpnStatus.connecting);
      _currentConfig = config;
      _currentServerName = serverName;

      // For desktop platforms (Windows, Linux, macOS)
      if (_isDesktop) {
        print('VPN SERVICE: Desktop detected, checking xray...');
        // Download xray binary if not exists
        final xrayReady = await _ensureXrayExists();
        if (!xrayReady) {
          _errorController.add(VpnError(
            type: 'xray_not_found',
            message: 'Failed to download Xray core',
          ));
          _updateStatus(VpnStatus.error);
          return false;
        }
        
        // Platform-specific connect
        if (_isWindows) {
          print('VPN SERVICE: Calling Windows connect...');
          final result = await _windowsChannel.invokeMethod<bool>('connect', {'config': config});
          print('VPN SERVICE: Windows connect returned: $result');
          return result ?? false;
        } else if (_isLinux) {
          print('VPN SERVICE: Calling Linux connect...');
          final result = await _linuxChannel.invokeMethod<bool>('connect', {'config': config});
          print('VPN SERVICE: Linux connect returned: $result');
          return result ?? false;
        } else if (_isMacOS) {
          print('VPN SERVICE: Calling macOS connect...');
          final result = await _macosChannel.invokeMethod<bool>('connect', {'config': config});
          print('VPN SERVICE: macOS connect returned: $result');
          return result ?? false;
        }
        return false;
      }

      // Mobile platforms use flutter_vless
      try {
        // Fix IPv6 address formatting if needed
        final fixedConfig = _fixVlessUrl(config);
        print('VPN SERVICE: Original URL: $config');
        print('VPN SERVICE: Fixed URL: $fixedConfig');
        
        // Try to parse and log the config
        FlutterVlessURL parsed;
        String newConfig;
        try {
          parsed = FlutterVless.parseFromURL(fixedConfig);
          newConfig = parsed.getFullConfiguration();
          print('VPN SERVICE: Parsed remark: ${parsed.remark}');
          print('VPN SERVICE: Config JSON length: ${newConfig.length}');
          print('VPN SERVICE: Config JSON preview: ${newConfig.substring(0, newConfig.length > 500 ? 500 : newConfig.length)}...');
        } catch (parseError) {
          print('VPN SERVICE: Failed to parse URL: $parseError');
          // Try with original URL as fallback
          print('VPN SERVICE: Trying original URL without IPv6 fix...');
          parsed = FlutterVless.parseFromURL(config);
          newConfig = parsed.getFullConfiguration();
        }
        
        final hasPermission = await _flutterVless?.requestPermission() ?? false;
        print('VPN SERVICE: VPN permission: $hasPermission');
        
        if (hasPermission) {
          print('VPN SERVICE: Calling startVless...');
          await _flutterVless!.startVless(
            remark: serverName ?? 'Voyfy Server',
            config: newConfig,
            blockedApps: null,
            bypassSubnets: null,
            proxyOnly: false,
          );
          print('VPN SERVICE: startVless completed successfully');
          // Force status update since callback might not work
          _updateStatus(VpnStatus.connected);
          return true;
        }
        print('VPN SERVICE: No VPN permission');
        return false;
      } catch (e, stackTrace) {
        print('VPN SERVICE: VLESS connection error: $e');
        print('VPN SERVICE: Stack trace: $stackTrace');
        _updateStatus(VpnStatus.error);
        return false;
      }
    } catch (e) {
      _updateStatus(VpnStatus.error);
      if (!_errorController.isClosed) {
        _errorController.add(VpnError(
          type: 'connection_error',
          message: 'Failed to connect',
          details: e.toString(),
        ));
      }
      return false;
    }
  }

  /// Disconnect from VPN
  Future<bool> disconnect() async {
    try {
      _updateStatus(VpnStatus.disconnecting);
      
      if (_isWindows) {
        final result = await _windowsChannel.invokeMethod<bool>('disconnect');
        return result ?? false;
      } else if (_isLinux) {
        final result = await _linuxChannel.invokeMethod<bool>('disconnect');
        return result ?? false;
      } else if (_isMacOS) {
        final result = await _macosChannel.invokeMethod<bool>('disconnect');
        return result ?? false;
      }
      
      try {
        await _flutterVless?.stopVless();
      } catch (e) {
        print('VPN SERVICE: VLESS disconnect error: $e');
      }
      return true;
    } catch (e) {
      _updateStatus(VpnStatus.error);
      if (!_errorController.isClosed) {
        _errorController.add(VpnError(
          type: 'disconnect_error',
          message: 'Failed to disconnect',
          details: e.toString(),
        ));
      }
      return false;
    }
  }

  /// Toggle connection
  Future<bool> toggleConnection({String? config, String? serverName}) async {
    if (_currentStatus == VpnStatus.connected || _currentStatus == VpnStatus.connecting) {
      return disconnect();
    } else {
      if (config == null) {
        if (!_errorController.isClosed) {
          _errorController.add(VpnError(
            type: 'config_error',
            message: 'No config provided',
          ));
        }
        return false;
      }
      return connect(config: config, serverName: serverName);
    }
  }

  /// Ensure xray.exe exists on Windows
  Future<bool> _ensureXrayExists() async {
    print('VPN SERVICE: _ensureXrayExists() started');
    try {
      // Check if xray exists via native code
      print('VPN SERVICE: Calling checkAndDownloadXray...');
      final result = await _windowsChannel.invokeMethod<bool>('checkAndDownloadXray');
      print('VPN SERVICE: checkAndDownloadXray returned: $result');
      if (result == true) {
        print('VPN SERVICE: Xray already exists');
        return true;
      }
      
      // Xray not found, copy from assets
      print('VPN SERVICE: Xray not found, copying from assets...');
      return await _copyXrayFromAssets();
    } catch (e, stackTrace) {
      print('VPN SERVICE: Xray check error: $e');
      print('VPN SERVICE: Stack trace: $stackTrace');
      return false;
    }
  }

  /// Ping server with config
  Future<int> ping(String config, String url, {int timeout = 10}) async {
    try {
      // Extract host from vless URL
      String host = _extractHostFromConfig(config);
      
      if (_isWindows) {
        final result = await _windowsChannel.invokeMethod<int>('ping', {
          'host': host,
          'timeout': timeout,
        });
        return result ?? -1;
      }
      // flutter_v2ray doesn't have direct ping, use HTTP fallback
      return await _pingHttpFallback(config);
    } catch (e) {
      print('VPN SERVICE: Ping error: $e');
      return -1;
    }
  }
  
  /// Extract host from vless config URL
  String _extractHostFromConfig(String config) {
    try {
      // Parse vless://uuid@host:port?...
      if (config.startsWith('vless://')) {
        final uri = Uri.tryParse(config);
        if (uri != null) {
          return uri.host;
        }
        // Fallback: manual parsing
        final withoutPrefix = config.substring(8); // Remove 'vless://'
        final atIndex = withoutPrefix.indexOf('@');
        if (atIndex > 0) {
          final hostPort = withoutPrefix.substring(atIndex + 1);
          final colonIndex = hostPort.indexOf(':');
          final questionIndex = hostPort.indexOf('?');
          if (colonIndex > 0) {
            final endIndex = questionIndex > 0 ? questionIndex : colonIndex;
            return hostPort.substring(0, endIndex);
          }
        }
      }
    } catch (e) {
      print('VPN SERVICE: Error extracting host: $e');
    }
    return '8.8.8.8'; // Default fallback
  }

  /// HTTP fallback ping for mobile platforms
  Future<int> _pingHttpFallback(String config) async {
    try {
      final host = _extractHostFromConfig(config);
      final stopwatch = Stopwatch()..start();
      
      // Try to connect to port 443 (HTTPS) - most servers have it open
      final socket = await Socket.connect(host, 443, timeout: const Duration(seconds: 5));
      await socket.close();
      stopwatch.stop();
      
      return stopwatch.elapsedMilliseconds;
    } catch (e) {
      print('VPN SERVICE: HTTP fallback ping error: $e');
      return -1;
    }
  }

  /// Test config
  Future<bool> testConfig(String config) async {
    try {
      if (_isWindows) {
        final result = await _windowsChannel.invokeMethod<bool>('testConfig', {'config': config});
        return result ?? false;
      }
      // flutter_vless test via parsing
      try {
        FlutterVless.parseFromURL(config);
        return true;
      } catch (e) {
        return false;
      }
    } catch (e) {
      print('VPN SERVICE: Test config error: $e');
      return false;
    }
  }

  /// Get connection status
  Future<VpnStatus> getConnectionStatus() async {
    try {
      if (_isWindows) {
        final result = await _windowsChannel.invokeMethod<String>('getStatus');
        return _parseWindowsStatus(result ?? 'disconnected');
      }
      // Check status via current status variable since flutter_vless doesn't expose isConnected
      return _currentStatus;
    } catch (e) {
      return VpnStatus.disconnected;
    }
  }

  /// Get current connection info
  Map<String, dynamic>? getCurrentConnectionInfo() {
    if (_currentStatus != VpnStatus.connected) return null;
    
    return {
      'serverName': _currentServerName,
      'connectedSince': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
    };
  }

  /// Measure ping to server using native ICMP (Windows) or HTTP fallback
  Future<int> measurePing(String host) async {
    if (_isWindows) {
      // Use native ICMP ping on Windows
      try {
        final result = await _windowsChannel.invokeMethod<int>('ping', {
          'host': host,
        }).timeout(const Duration(seconds: 5));
        
        // If ICMP succeeded, return the result
        if (result != null && result > 0) {
          return result;
        }
        
        // ICMP failed or returned -1, try HTTP ping as fallback
        print('VPN SERVICE: ICMP ping failed, trying HTTP fallback...');
      } catch (e) {
        print('VPN SERVICE: Native ping error: $e, trying HTTP fallback...');
      }
      
      // HTTP fallback - try to ping via HTTP request
      try {
        final stopwatch = Stopwatch()..start();
        final isIp = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(host);
        
        // For IP addresses, try HTTP to avoid SSL cert issues
        // For domains, try HTTPS
        final protocol = isIp ? 'http' : 'https';
        
        // Try Cloudflare's 1.1.1.1 or Google's DNS as fallback
        // or use the host directly if it's an IP
        String pingUrl;
        if (host == '1.1.1.1' || host == '8.8.8.8' || host == '8.8.4.4') {
          // DNS servers - just try HTTP to port 80
          pingUrl = '$protocol://$host';
        } else {
          // Try common endpoints
          pingUrl = '$protocol://$host/health';
        }
        
        print('VPN SERVICE: HTTP ping to $pingUrl');
        
        final response = await http.get(
          Uri.parse(pingUrl),
        ).timeout(const Duration(seconds: 3));
        stopwatch.stop();
        
        // Any response (even error) means server is reachable
        print('VPN SERVICE: HTTP ping response: ${response.statusCode} in ${stopwatch.elapsedMilliseconds}ms');
        return stopwatch.elapsedMilliseconds;
      } catch (e) {
        print('VPN SERVICE: HTTP ping error: $e');
        return -1;
      }
    } else {
      // Fallback to HTTP ping on other platforms
      try {
        final stopwatch = Stopwatch()..start();
        final isIp = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(host);
        final protocol = isIp ? 'http' : 'https';
        final response = await http.get(
          Uri.parse('$protocol://$host/health'),
        ).timeout(const Duration(seconds: 5));
        stopwatch.stop();
        
        if (response.statusCode == 200) {
          return stopwatch.elapsedMilliseconds;
        }
        return -1;
      } catch (e) {
        print('VPN SERVICE: HTTP ping error: $e');
        return -1;
      }
    }
  }

  /// Get current ping (calls native method on Windows)
  Future<int> getCurrentPing() async {
    if (!_isWindows) return -1;
    try {
      final result = await _windowsChannel.invokeMethod<int>('getPing');
      return result ?? -1;
    } catch (e) {
      print('VPN SERVICE: Get ping error: $e');
      return -1;
    }
  }

  /// Get network statistics (bytes received/sent) for Windows TUN interface
  Future<Map<String, int>> getNetworkStats() async {
    if (!_isWindows) {
      return {'recv': 0, 'sent': 0};
    }
    return _getWindowsNetworkStats();
  }

  /// Measure speed (download/upload in Mbps)
  Future<Map<String, double>> measureSpeed() async {
    try {
      // Test download speed using a small test file
      final downloadUrl = 'https://speed.cloudflare.com/__down?bytes=250000';
      final downloadStopwatch = Stopwatch()..start();
      final downloadResponse = await http.get(Uri.parse(downloadUrl))
          .timeout(const Duration(seconds: 10));
      downloadStopwatch.stop();
      
      double downloadSpeed = 0;
      if (downloadResponse.statusCode == 200) {
        final bytes = downloadResponse.bodyBytes.length;
        final seconds = downloadStopwatch.elapsedMilliseconds / 1000;
        downloadSpeed = (bytes * 8) / (seconds * 1000000); // Mbps
      }
      
      return {
        'download': downloadSpeed,
        'upload': 0.0, // Upload test would require server-side endpoint
      };
    } catch (e) {
      print('VPN SERVICE: Speed test error: $e');
      return {'download': 0.0, 'upload': 0.0};
    }
  }

  /// Windows network stats using netsh command (reliable, no FFI offset guessing)
  static Future<Map<String, int>> _getWindowsNetworkStats() async {
    if (!Platform.isWindows) {
      return {'recv': 0, 'sent': 0};
    }
    
    try {
      // Use netsh to get interface statistics
      final result = await Process.run('netsh', ['interface', 'ipv4', 'show', 'subinterfaces'], 
        runInShell: true,
        stdoutEncoding: const SystemEncoding(),
      );
      
      if (result.exitCode != 0) {
        print('VPN SERVICE: netsh failed with exit code ${result.exitCode}');
        return {'recv': 0, 'sent': 0};
      }
      
      final output = result.stdout.toString();
      print('VPN SERVICE: netsh output:\n$output');
      
      int totalRecv = 0;
      int totalSent = 0;
      
      // Parse netsh output - format is:
      // MTU  MediaSenseState   Bytes In   Bytes Out  Interface
      // 1500                1  123456789  987654321  Ethernet
      final lines = output.split('\n');
      for (final line in lines) {
        // Skip header lines and empty lines
        if (line.contains('MTU') || line.contains('---') || line.trim().isEmpty) continue;
        
        // Parse data line - format: MTU  State  BytesIn  BytesOut  InterfaceName
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length >= 5) {
          // Bytes In is 3rd column, Bytes Out is 4th column
          final bytesInStr = parts[2].replaceAll(',', '');
          final bytesOutStr = parts[3].replaceAll(',', '');
          final interfaceName = parts.sublist(4).join(' ');
          
          final bytesIn = int.tryParse(bytesInStr) ?? 0;
          final bytesOut = int.tryParse(bytesOutStr) ?? 0;
          
          print('VPN SERVICE: Interface "$interfaceName": in=$bytesIn, out=$bytesOut');
          
          // Sum all interfaces with traffic for now
          if (bytesIn > 0 || bytesOut > 0) {
            totalRecv += bytesIn;
            totalSent += bytesOut;
          }
        }
      }
      
      print('VPN SERVICE: Total stats - recv: $totalRecv, sent: $totalSent');
      return {'recv': totalRecv, 'sent': totalSent};
    } catch (e) {
      print('VPN SERVICE: Error getting Windows network stats: $e');
      return {'recv': 0, 'sent': 0};
    }
  }

  /// Check current VPN status
  Future<VpnStatus> checkStatus() async {
    try {
      if (_isWindows) {
        final result = await _windowsChannel.invokeMethod<String>('getStatus');
        return _parseWindowsStatus(result ?? 'disconnected');
      } else if (_isLinux) {
        final result = await _linuxChannel.invokeMethod<String>('getStatus');
        return _parseDesktopStatus(result ?? 'disconnected');
      } else if (_isMacOS) {
        final result = await _macosChannel.invokeMethod<String>('getStatus');
        return _parseDesktopStatus(result ?? 'disconnected');
      } else {
        // Check status via _currentStatus for flutter_vless
        return _currentStatus;
      }
    } catch (e) {
      print('VPN SERVICE: Check status error: $e');
      return _currentStatus;
    }
  }

  /// Copy Xray from assets (fallback method)
  Future<bool> _copyXrayFromAssets() async {
    // This method is deprecated - Xray is now downloaded from backend
    // Keeping for backward compatibility
    print('VPN SERVICE: _copyXrayFromAssets() called - deprecated, using downloader instead');
    return await XrayDownloader.downloadAndVerifyXray();
  }

  /// Dispose resources
  void dispose() {
    if (_currentStatus == VpnStatus.connected) {
      disconnect();
    }
    
    // Don't close controllers here - let them stay open for the app lifetime
    // Just cancel any active connection
    print('VPN SERVICE: dispose() called but keeping controllers open');
  }

  // Private methods
  void _updateStatus(VpnStatus status) {
    print('VPN SERVICE: _updateStatus called: $status (previous: $_currentStatus)');
    _currentStatus = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
      print('VPN SERVICE: Status added to controller, listeners notified');
    } else {
      print('VPN SERVICE: Status controller is closed!');
    }
  }
  
  void _updateDataUsage(DataUsage usage) {
    if (!_dataUsageController.isClosed) {
      _dataUsageController.add(usage);
    }
  }
}
