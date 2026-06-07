import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'hysteria2_downloader.dart';

/// Parse Hysteria2 URI and extract connection parameters
/// Format: hysteria2://password@host:port?obfs=salamander&obfs-password=xxx&sni=xxx
Map<String, dynamic>? _parseHysteria2Uri(String uri) {
  try {
    final url = Uri.parse(uri);
    if (url.scheme != 'hysteria2') return null;

    return {
      'password': url.userInfo,
      'host': url.host,
      'port': url.port,
      'obfs': url.queryParameters['obfs'],
      'obfsPassword': url.queryParameters['obfs-password'],
      'sni': url.queryParameters['sni'],
    };
  } catch (e) {
    print('VPN: Error parsing Hysteria2 URI: $e');
    return null;
  }
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

/// VPN Service using flutter_vpnengine plugin (simplified for Hysteria2 on desktop)
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

  // Android MethodChannel for data usage
  static const MethodChannel _androidChannel = MethodChannel('com.voyfy.vpn/android');
  static const MethodChannel _androidDataChannel = MethodChannel('com.voyfy.vpn/android_data');

  // iOS MethodChannels
  static const MethodChannel _iosChannel = MethodChannel('com.voyfy.vpn/ios');
  static const MethodChannel _iosDataChannel = MethodChannel('com.voyfy.vpn/ios_data');

  // Platform check
  bool get _isWindows => Platform.isWindows;
  bool get _isLinux => Platform.isLinux;
  bool get _isMacOS => Platform.isMacOS;
  bool get _isAndroid => Platform.isAndroid;
  bool get _isIOS => Platform.isIOS;
  bool get _isDesktop => _isWindows || _isLinux || _isMacOS;

  // Data usage tracking for mobile
  Timer? _dataUsageTimer;
  int _lastBytesReceived = 0;
  int _lastBytesSent = 0;

  Stream<VpnStatus> get onStatusChanged => _statusController.stream;
  Stream<DataUsage> get onDataUsageUpdated => _dataUsageController.stream;
  Stream<VpnError> get onError => _errorController.stream;

  VpnStatus _currentStatus = VpnStatus.disconnected;
  VpnStatus get currentStatus => _currentStatus;

  String? _currentConfig;
  String? _currentServerName;

  // Xray process for Linux/macOS
  Process? _xrayProcess;
  String? _xrayConfigPath;

  /// Initialize VPN
  Future<bool> initialize() async {
    // Recreate controllers if they were closed
    if (_statusController.isClosed) {
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
        _windowsChannel.setMethodCallHandler((call) async {
          if (call.method == 'onStatusChanged') {
            final statusStr = call.arguments as String;
            final status = _parseWindowsStatus(statusStr);
            _updateStatus(status);
          }
          return null;
        });
        _windowsDataChannel.setMethodCallHandler((call) async {
          if (call.method == 'onDataUsageUpdated') {
            final args = call.arguments as Map<dynamic, dynamic>;
            _updateDataUsage(DataUsage(
              bytesReceived: args['bytesReceived'] as int? ?? 0,
              bytesSent: args['bytesSent'] as int? ?? 0,
            ));
          }
          return null;
        });
        final result = await _windowsChannel.invokeMethod<bool>('initialize');
        return result ?? false;
      } else if (_isLinux) {
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
        if (!(result ?? false)) return false;

        // Check system dependencies (pkexec, setcap, getcap, ip, pkill)
        final depResult = await _linuxChannel.invokeMethod<String>('checkDependencies');
        if (depResult != null && depResult.isNotEmpty) {
          print('VPN SERVICE: Linux dependencies missing: $depResult');
          _errorController.add(VpnError(
            type: 'missing_dependencies',
            message: depResult,
          ));
          return false;
        }
        return true;
      } else if (_isMacOS) {
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
      } else if (_isIOS) {
        _iosChannel.setMethodCallHandler((call) async {
          if (call.method == 'onStatusChanged') {
            final statusStr = call.arguments as String;
            _updateStatus(_parseDesktopStatus(statusStr));
          }
          return null;
        });
        _iosDataChannel.setMethodCallHandler((call) async {
          if (call.method == 'onDataUsageUpdated') {
            final args = call.arguments as Map<dynamic, dynamic>;
            _updateDataUsage(DataUsage(
              bytesReceived: args['bytesReceived'] as int? ?? 0,
              bytesSent: args['bytesSent'] as int? ?? 0,
            ));
          }
          return null;
        });
        final result = await _iosChannel.invokeMethod<bool>('initialize');
        return result ?? false;
      } else {
        // Mobile platforms – not fully implemented for Hysteria2
        print('VPN SERVICE: Mobile platforms not fully supported for Hysteria2 yet');
        return true;
      }
    } catch (e) {
      print('VPN SERVICE: Init error: $e');
      return false;
    }
  }

  VpnStatus _parseWindowsStatus(String status) {
    if (status.isEmpty) return _currentStatus;
    switch (status) {
      case 'connecting':
        return VpnStatus.connecting;
      case 'connected':
        return VpnStatus.connected;
      case 'disconnecting':
        return VpnStatus.disconnecting;
      case 'disconnected':
        return VpnStatus.disconnected;
      case 'error':
        return VpnStatus.error;
      default:
        return _currentStatus;
    }
  }

  VpnStatus _parseDesktopStatus(String status) => _parseWindowsStatus(status);

  /// Parse Hysteria2 URL and generate YAML config
  String _generateHysteria2Config(String url) {
    try {
      if (!url.startsWith('hysteria2://')) {
        throw Exception('Invalid URL scheme: must be hysteria2://');
      }

      // Remove hysteria2:// prefix
      final withoutPrefix = url.substring('hysteria2://'.length);

      // Find the @ that separates auth from host
      final atIndex = withoutPrefix.indexOf('@');
      if (atIndex == -1) {
        throw Exception('Invalid URL format: missing @ separator');
      }

      // Extract auth (everything before @)
      final auth = withoutPrefix.substring(0, atIndex);

      // Parse the rest as URI to get host, port, query
      final rest = withoutPrefix.substring(atIndex + 1);
      final uri = Uri.parse('http://$rest'); // Use http as dummy scheme

      final host = uri.host;
      final port = uri.port;
      final query = uri.queryParameters;

      if (host.isEmpty) {
        throw Exception('Invalid URL: host is empty');
      }

      final obfs = query['obfs'] ?? 'salamander';
      final obfsPassword = query['obfs-password'] ?? 'voyfy_obfs_secret';
      final sni = query['sni'] ?? host;

      // Platform-specific TUN config
      String tunSection;
      if (_isWindows) {
        tunSection = '''
tun:
  name: Hysteria2
  mtu: 1500
  autoRoute: false
  postUp:
    - cmd: powershell -Command "Get-NetAdapter -InterfaceDescription 'Hysteria2' | Set-NetIPInterface -InterfaceMetric 1"
  postDown:
    - cmd: powershell -Command "Get-NetAdapter -InterfaceDescription 'Hysteria2' | Set-NetIPInterface -InterfaceMetric 50"
''';
      } else if (_isLinux) {
        tunSection = '''
tun:
  name: hy2
  mtu: 1500
  autoRoute: false
  ipv4: 172.16.0.2/30
  ipv6: fd00:dead:beef::2/126
''';
      } else if (_isMacOS) {
        tunSection = '''
tun:
  name: utun123
  mtu: 1500
  autoRoute: true
''';
      } else {
        tunSection = '';
      }

      return '''
server: $host:$port
auth: $auth

bandwidth:
  up: 100 mbps
  down: 100 mbps

obfs:
  type: $obfs
  salamander:
    password: $obfsPassword

tls:
  sni: $sni
  insecure: true
${tunSection}
socks5:
  listen: 127.0.0.1:1080

http:
  listen: 127.0.0.1:8080
'''.trim();
    } catch (e) {
      print('VPN SERVICE: Failed to parse Hysteria2 URL: $e');
      throw Exception('Invalid Hysteria2 URL: $e');
    }
  }

  /// Connect using Hysteria2 config (desktop only)
  Future<bool> connect({
    required String config,
    String? serverName,
    List<String>? blockedApps,
    bool proxyOnly = false,
  }) async {
    print('VPN SERVICE: connect() called');
    try {
      _updateStatus(VpnStatus.connecting);
      _currentConfig = config;
      _currentServerName = serverName;

      if (_isDesktop) {
        // Ensure hysteria2 binary exists
        final hysteria2Ready = await _ensureHysteria2Exists();
        if (!hysteria2Ready) {
          _errorController.add(VpnError(
            type: 'hysteria2_not_found',
            message: 'Failed to download Hysteria2 core',
          ));
          _updateStatus(VpnStatus.error);
          return false;
        }

        // Convert Hysteria2 URL to YAML config
        final hysteria2Config = _generateHysteria2Config(config);
        print('VPN SERVICE: Generated Hysteria2 config');

        // Platform-specific connect using native MethodChannels
        dynamic result;
        if (_isWindows) {
          result = await _windowsChannel.invokeMethod<dynamic>('connect', {'config': hysteria2Config});
        } else if (_isLinux) {
          result = await _linuxChannel.invokeMethod<dynamic>('connect', {'config': hysteria2Config});
        } else if (_isMacOS) {
          result = await _macosChannel.invokeMethod<dynamic>('connect', {'config': hysteria2Config});
        }
        
        print('VPN SERVICE: Native response: $result');
        
        // C++ service returns "OK" string or "ERR..." on failure
        if (result != null && (result == true || result.toString().startsWith('OK'))) {
          _updateStatus(VpnStatus.connected);
          return true;
        } else {
          _updateStatus(VpnStatus.error);
          String errorMsg;
          if (_isLinux && (result == false || result == null)) {
            errorMsg = 'VPN failed. Make sure you enter the administrator password when prompted, or check your server config.';
          } else {
            errorMsg = 'Native service failed: ${result ?? "no response"}';
          }
          _errorController.add(VpnError(
            type: 'connection_error',
            message: errorMsg,
          ));
          return false;
        }
      } else if (Platform.isAndroid) {
        // Android: download binaries, generate config, start VpnService
        final hysteria2Ready = await _ensureHysteria2Exists();
        if (!hysteria2Ready) {
          _errorController.add(VpnError(
            type: 'hysteria2_not_found',
            message: 'Failed to download Hysteria2 core for Android',
          ));
          _updateStatus(VpnStatus.error);
          return false;
        }

        // Convert Hysteria2 URL to YAML config (mobile version: no tun, just socks5)
        final hysteria2Config = _generateHysteria2Config(config);
        print('VPN SERVICE: Generated Hysteria2 config for Android');

        // Start VPN via Android VpnService
        final result = await _androidChannel.invokeMethod<bool>('startVpn', {
          'config': hysteria2Config,
        });

        print('VPN SERVICE: Android startVpn response: $result');

        if (result == true) {
          _updateStatus(VpnStatus.connected);
          return true;
        } else {
          _updateStatus(VpnStatus.error);
          _errorController.add(VpnError(
            type: 'connection_error',
            message: 'Android VPN service failed to start',
          ));
          return false;
        }
      } else if (Platform.isIOS) {
        // iOS: Pass Hysteria2 YAML config to Packet Tunnel Provider
        final hysteria2Config = _generateHysteria2Config(config);
        print('VPN SERVICE: Generated Hysteria2 config for iOS');

        final result = await _iosChannel.invokeMethod<dynamic>('connect', {
          'config': hysteria2Config,
        });

        print('VPN SERVICE: iOS connect response: $result');

        if (result != null && (result == true || result.toString().startsWith('OK'))) {
          _updateStatus(VpnStatus.connected);
          return true;
        } else {
          _updateStatus(VpnStatus.error);
          _errorController.add(VpnError(
            type: 'connection_error',
            message: 'iOS VPN service failed: ${result ?? "no response"}',
          ));
          return false;
        }
      } else {
        // iOS not implemented yet
        print('VPN SERVICE: iOS not supported yet for Hysteria2');
        _updateStatus(VpnStatus.error);
        _errorController.add(VpnError(
          type: 'platform_not_supported',
          message: 'iOS Hysteria2 support is coming soon',
        ));
        return false;
      }
    } catch (e) {
      _updateStatus(VpnStatus.error);
      _errorController.add(VpnError(
        type: 'connection_error',
        message: 'Failed to connect',
        details: e.toString(),
      ));
      return false;
    }
  }

  /// Disconnect from VPN
  Future<bool> disconnect() async {
    try {
      _updateStatus(VpnStatus.disconnecting);
      // Let UI render "disconnecting" before completing
      await Future.delayed(Duration(milliseconds: 500));

      if (_isWindows) {
        final result = await _windowsChannel.invokeMethod<bool>('disconnect');
        return result ?? false;
      } else if (_isLinux) {
        final result = await _linuxChannel.invokeMethod<bool>('disconnect');
        return result ?? false;
      } else if (_isMacOS) {
        final result = await _macosChannel.invokeMethod<bool>('disconnect');
        return result ?? false;
      } else if (Platform.isAndroid) {
        final result = await _androidChannel.invokeMethod<bool>('stopVpn');
        _updateStatus(VpnStatus.disconnected);
        return result ?? false;
      } else if (Platform.isIOS) {
        final result = await _iosChannel.invokeMethod<bool>('disconnect');
        _updateStatus(VpnStatus.disconnected);
        return result ?? false;
      }

      // Fallback: kill any local xray process
      await _disconnectDesktopLinuxMacOS();
      _updateStatus(VpnStatus.disconnected);
      return true;
    } catch (e) {
      _updateStatus(VpnStatus.error);
      _errorController.add(VpnError(
        type: 'disconnect_error',
        message: 'Failed to disconnect',
        details: e.toString(),
      ));
      return false;
    }
  }

  /// Toggle connection
  Future<bool> toggleConnection({
    String? config,
    String? serverName,
    List<String>? blockedApps,
    bool proxyOnly = false,
  }) async {
    if (_currentStatus == VpnStatus.connected || _currentStatus == VpnStatus.connecting) {
      return disconnect();
    } else {
      if (config == null) {
        _errorController.add(VpnError(
          type: 'config_error',
          message: 'No config provided',
        ));
        return false;
      }
      return connect(
        config: config,
        serverName: serverName,
        blockedApps: blockedApps,
        proxyOnly: proxyOnly,
      );
    }
  }

  /// Ensure Hysteria2 binary exists
  Future<bool> _ensureHysteria2Exists() async {
    try {
      // Download Hysteria2 directly from GitHub
      return await Hysteria2Downloader.downloadAndVerifyHysteria2();
    } catch (e) {
      print('VPN SERVICE: Ensure hysteria2 error: $e');
      return false;
    }
  }

  /// Ping server with config
  Future<int> ping(String config, String url, {int timeout = 10}) async {
    try {
      String host = _extractHostFromConfig(config);

      if (_isWindows) {
        final result = await _windowsChannel.invokeMethod<int>('ping', {
          'host': host,
          'timeout': timeout,
        });
        return result ?? -1;
      } else if (_isLinux) {
        final result = await _linuxChannel.invokeMethod<int>('ping', {
          'host': host,
          'timeout': timeout,
        });
        return result ?? -1;
      } else if (_isMacOS) {
        final result = await _macosChannel.invokeMethod<int>('ping', {
          'host': host,
          'timeout': timeout,
        });
        return result ?? -1;
      }

      return await _pingHttpFallback(config);
    } catch (e) {
      print('VPN SERVICE: Ping error: $e');
      return -1;
    }
  }

  String _extractHostFromConfig(String config) {
    try {
      if (config.startsWith('hysteria2://')) {
        // Manual parsing to handle auth with / characters
        final withoutPrefix = config.substring('hysteria2://'.length);
        final atIndex = withoutPrefix.indexOf('@');
        if (atIndex != -1) {
          final rest = withoutPrefix.substring(atIndex + 1);
          final uri = Uri.parse('http://$rest');
          return uri.host;
        }
      }
    } catch (e) {
      print('VPN SERVICE: Error extracting host: $e');
    }
    return '8.8.8.8';
  }

  Future<int> _pingHttpFallback(String config) async {
    try {
      final host = _extractHostFromConfig(config);
      final stopwatch = Stopwatch()..start();
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
      } else if (_isLinux) {
        final result = await _linuxChannel.invokeMethod<bool>('testConfig', {'config': config});
        return result ?? false;
      } else if (_isMacOS) {
        final result = await _macosChannel.invokeMethod<bool>('testConfig', {'config': config});
        return result ?? false;
      }
      // For mobile, just parse
      return _parseHysteria2Uri(config) != null;
    } catch (e) {
      return false;
    }
  }

  /// Get connection status
  Future<VpnStatus> getConnectionStatus() async {
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
      } else if (Platform.isAndroid) {
        final result = await _androidChannel.invokeMethod<String>('getVpnStatus');
        return _parseWindowsStatus(result ?? 'disconnected');
      } else if (Platform.isIOS) {
        final result = await _iosChannel.invokeMethod<String>('getStatus');
        return _parseDesktopStatus(result ?? 'disconnected');
      }
      return _currentStatus;
    } catch (e) {
      return _currentStatus;
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

  /// Measure ping to server (simplified)
  Future<int> measurePing(String host) async {
    try {
      final stopwatch = Stopwatch()..start();
      final socket = await Socket.connect(host, 443, timeout: const Duration(seconds: 3));
      await socket.close();
      stopwatch.stop();
      return stopwatch.elapsedMilliseconds;
    } catch (e) {
      return -1;
    }
  }

  /// Get current ping (native call)
  Future<int> getCurrentPing() async {
    if (!_isWindows) return -1;
    try {
      final result = await _windowsChannel.invokeMethod<int>('getPing');
      return result ?? -1;
    } catch (e) {
      return -1;
    }
  }

  /// Get network statistics
  Future<Map<String, int>> getNetworkStats() async {
    if (_isWindows) {
      return _getWindowsNetworkStats();
    } else if (_isAndroid) {
      final stats = await _getAndroidDataUsage();
      if (stats != null) {
        return {
          'recv': stats['bytesReceived'] ?? 0,
          'sent': stats['bytesSent'] ?? 0,
        };
      }
    }
    return {'recv': 0, 'sent': 0};
  }

  /// Windows network stats using netsh
  static Future<Map<String, int>> _getWindowsNetworkStats() async {
    if (!Platform.isWindows) return {'recv': 0, 'sent': 0};
    try {
      final result = await Process.run('netsh', ['interface', 'ipv4', 'show', 'subinterfaces'],
          runInShell: true, stdoutEncoding: const SystemEncoding());
      if (result.exitCode != 0) return {'recv': 0, 'sent': 0};
      final output = result.stdout.toString();
      int totalRecv = 0;
      int totalSent = 0;
      final lines = output.split('\n');
      for (final line in lines) {
        if (line.contains('MTU') || line.contains('---') || line.trim().isEmpty) continue;
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length >= 5) {
          final bytesInStr = parts[2].replaceAll(',', '');
          final bytesOutStr = parts[3].replaceAll(',', '');
          final bytesIn = int.tryParse(bytesInStr) ?? 0;
          final bytesOut = int.tryParse(bytesOutStr) ?? 0;
          totalRecv += bytesIn;
          totalSent += bytesOut;
        }
      }
      return {'recv': totalRecv, 'sent': totalSent};
    } catch (e) {
      return {'recv': 0, 'sent': 0};
    }
  }

  /// Measure speed (simple version)
  Future<Map<String, double>> measureSpeed() async {
    try {
      final downloadUrl = 'https://speed.cloudflare.com/__down?bytes=250000';
      final stopwatch = Stopwatch()..start();
      final response = await http.get(Uri.parse(downloadUrl)).timeout(const Duration(seconds: 10));
      stopwatch.stop();
      double downloadSpeed = 0;
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes.length;
        final seconds = stopwatch.elapsedMilliseconds / 1000;
        downloadSpeed = (bytes * 8) / (seconds * 1000000);
      }
      return {'download': downloadSpeed, 'upload': 0.0};
    } catch (e) {
      return {'download': 0.0, 'upload': 0.0};
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
      } else if (Platform.isAndroid) {
        final result = await _androidChannel.invokeMethod<String>('getVpnStatus');
        return _parseWindowsStatus(result ?? 'disconnected');
      } else if (Platform.isIOS) {
        final result = await _iosChannel.invokeMethod<String>('getStatus');
        return _parseDesktopStatus(result ?? 'disconnected');
      }
      return _currentStatus;
    } catch (e) {
      return _currentStatus;
    }
  }

  /// Dispose resources
  void dispose() {
    if (_currentStatus == VpnStatus.connected) {
      disconnect();
    }
    _dataUsageTimer?.cancel();
    _dataUsageTimer = null;
    print('VPN SERVICE: dispose() called');
  }

  // ---------- Private helpers ----------

  void _updateStatus(VpnStatus status) {
    print('VPN SERVICE: Status changed to $status');
    _currentStatus = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
    if (_isAndroid) {
      if (status == VpnStatus.connected) {
        _startAndroidDataUsageTimer();
      } else {
        _stopAndroidDataUsageTimer();
      }
    }
  }

  void _startAndroidDataUsageTimer() {
    _dataUsageTimer?.cancel();
    _dataUsageTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentStatus != VpnStatus.connected) {
        timer.cancel();
        return;
      }
      _getAndroidDataUsage().then((stats) {
        if (stats != null) {
          _updateDataUsage(DataUsage(
            bytesReceived: stats['bytesReceived'] ?? 0,
            bytesSent: stats['bytesSent'] ?? 0,
          ));
        }
      }).catchError((e) {});
    });
  }

  void _stopAndroidDataUsageTimer() {
    _dataUsageTimer?.cancel();
    _dataUsageTimer = null;
  }

  Future<Map<String, int>?> _getAndroidDataUsage() async {
    try {
      final result = await _androidChannel.invokeMethod<Map<dynamic, dynamic>>('getDataUsage');
      if (result != null) {
        return {
          'bytesReceived': result['bytesReceived'] as int? ?? 0,
          'bytesSent': result['bytesSent'] as int? ?? 0,
        };
      }
    } catch (e) {}
    return null;
  }

  void _updateDataUsage(DataUsage usage) {
    if (!_dataUsageController.isClosed) {
      _dataUsageController.add(usage);
    }
  }

  // Linux/macOS direct control (fallback)
  Future<bool> _connectDesktopLinuxMacOS(String hysteria2Url) async {
    try {
      await _disconnectDesktopLinuxMacOS();

      final downloader = Hysteria2Downloader();
      final hysteria2Path = await downloader.binaryPath;
      if (hysteria2Path == null || hysteria2Path.isEmpty) {
        print('VPN SERVICE: hysteria2 binary path not available');
        return false;
      }

      final hysteria2File = File(hysteria2Path);
      if (!await hysteria2File.exists()) {
        final downloaded = await downloader.downloadAndVerify();
        if (downloaded == null) return false;
      }

      await Process.run('chmod', ['+x', hysteria2Path]);

      final uriData = _parseHysteria2Uri(hysteria2Url);
      if (uriData == null) return false;

      final configJson = {
        "server": "${uriData['host']}:${uriData['port']}",
        "auth": uriData['password'],
        "tls": {
          "sni": uriData['sni'] ?? uriData['host'],
          "insecure": false,
        },
        "obfs": {
          "type": uriData['obfs'] ?? 'salamander',
          "password": uriData['obfsPassword'] ?? '',
        }
      };

      final tempDir = Directory.systemTemp;
      final configFile = File('${tempDir.path}/voyfy_hysteria2_config.json');
      await configFile.writeAsString(jsonEncode(configJson));
      _xrayConfigPath = configFile.path;

      _xrayProcess = await Process.start(
        hysteria2Path,
        ['-c', _xrayConfigPath!],
        mode: ProcessStartMode.detached,
      );

      await Future.delayed(const Duration(seconds: 2));
      _updateStatus(VpnStatus.connected);
      return true;
    } catch (e) {
      print('VPN SERVICE: Linux/macOS connect error: $e');
      return false;
    }
  }

  Future<bool> _disconnectDesktopLinuxMacOS() async {
    try {
      if (_xrayProcess != null) {
        _xrayProcess!.kill();
        _xrayProcess = null;
      }
      if (_isMacOS || _isLinux) {
        await Process.run('pkill', ['-f', 'hysteria2']);
      }
      if (_xrayConfigPath != null) {
        final configFile = File(_xrayConfigPath!);
        if (await configFile.exists()) await configFile.delete();
        _xrayConfigPath = null;
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}