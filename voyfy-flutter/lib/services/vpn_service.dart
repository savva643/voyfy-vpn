import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_vpnengine/vpnclient_engine_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';

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

  final _statusController = StreamController<VpnStatus>.broadcast();
  final _dataUsageController = StreamController<DataUsage>.broadcast();
  final _errorController = StreamController<VpnError>.broadcast();

  // Windows MethodChannels
  static const MethodChannel _windowsChannel = MethodChannel('com.voyfy.vpn/windows');
  static const MethodChannel _windowsDataChannel = MethodChannel('com.voyfy.vpn/data');

  // Platform check
  bool get _isWindows => Platform.isWindows;

  Stream<VpnStatus> get onStatusChanged => _statusController.stream;
  Stream<DataUsage> get onDataUsageUpdated => _dataUsageController.stream;
  Stream<VpnError> get onError => _errorController.stream;

  VpnStatus _currentStatus = VpnStatus.disconnected;
  VpnStatus get currentStatus => _currentStatus;

  String? _currentConfig;
  String? _currentServerName;

  /// Initialize VPN
  Future<bool> initialize() async {
    try {
      if (_isWindows) {
        // Setup Windows MethodChannel status listener
        _windowsChannel.setMethodCallHandler((call) async {
          if (call.method == 'onStatusChanged') {
            final status = _parseWindowsStatus(call.arguments as String);
            _updateStatus(status);
          }
          return null;
        });
        
        // Setup data usage channel
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
        print('VPN SERVICE: Windows initialized');
        return result ?? false;
      } else {
        // Use flutter_vpnengine for mobile
        VpnclientEngineFlutter.instance.setStatusCallback((status) {
          _updateStatus(_mapStatus(status));
        });
        await VpnclientEngineFlutter.instance.initialize();
      }
      print('VPN SERVICE: Initialized');
      return true;
    } catch (e) {
      print('VPN SERVICE: Init error: $e');
      return false;
    }
  }

  VpnStatus _parseWindowsStatus(String status) {
    switch (status) {
      case 'connecting': return VpnStatus.connecting;
      case 'connected': return VpnStatus.connected;
      case 'disconnecting': return VpnStatus.disconnecting;
      case 'error': return VpnStatus.error;
      default: return VpnStatus.disconnected;
    }
  }

  VpnStatus _mapStatus(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.disconnected:
        return VpnStatus.disconnected;
      case ConnectionStatus.connecting:
        return VpnStatus.connecting;
      case ConnectionStatus.connected:
        return VpnStatus.connected;
      case ConnectionStatus.error:
        return VpnStatus.error;
      default:
        return VpnStatus.disconnected;
    }
  }

  /// Connect using VLESS/Xray config
  Future<bool> connect({required String config, String? serverName}) async {
    print('VPN SERVICE: connect() called, isWindows=$_isWindows');
    try {
      _updateStatus(VpnStatus.connecting);
      _currentConfig = config;
      _currentServerName = serverName;

      if (_isWindows) {
        print('VPN SERVICE: Windows detected, checking xray...');
        // Download xray.exe if not exists
        final xrayReady = await _ensureXrayExists();
        if (!xrayReady) {
          _errorController.add(VpnError(
            type: 'xray_not_found',
            message: 'Failed to download Xray core',
          ));
          _updateStatus(VpnStatus.error);
          return false;
        }
        print('VPN SERVICE: Calling Windows connect...');
        print('VPN SERVICE: Config length: ${config.length}, starts with: ${config.substring(0, config.length > 20 ? 20 : config.length)}');
        final result = await _windowsChannel.invokeMethod<bool>('connect', {'config': config});
        print('VPN SERVICE: Windows connect returned: $result');
        return result ?? false;
      }

      final result = await VpnclientEngineFlutter.client.connect(EngineType.libxray, config);
      
      if (!result) {
        _updateStatus(VpnStatus.error);
      }
      return result;
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
      }
      
      await VpnclientEngineFlutter.client.disconnect();
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
  
  /// Download Xray for Windows
  Future<bool> _downloadXray() async {
    try {
      // Xray Windows download URL (latest release)
      const xrayUrl = 'https://github.com/XTLS/Xray-core/releases/latest/download/Xray-windows-64.zip';
      
      print('VPN SERVICE: Downloading from $xrayUrl');
      final response = await http.get(Uri.parse(xrayUrl));
      
      if (response.statusCode != 200) {
        print('VPN SERVICE: Download failed: ${response.statusCode}');
        return false;
      }
      
      // Get AppData path
      final appData = Platform.environment['LOCALAPPDATA'];
      final xrayDir = Directory('$appData\\VoyfyVPN');
      
      if (!await xrayDir.exists()) {
        await xrayDir.create(recursive: true);
      }
      
      // Save zip file
      final zipPath = '${xrayDir.path}\\xray.zip';
      await File(zipPath).writeAsBytes(response.bodyBytes);
      print('VPN SERVICE: Saved to $zipPath');
      
      // Extract zip file
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      // Find and extract xray.exe
      for (final file in archive) {
        if (file.name.toLowerCase() == 'xray.exe') {
          final xrayPath = '${xrayDir.path}\\xray.exe';
          await File(xrayPath).writeAsBytes(file.content as List<int>);
          print('VPN SERVICE: Extracted xray.exe to $xrayPath');
          
          // Delete zip file
          await File(zipPath).delete();
          return true;
        }
      }
      
      print('VPN SERVICE: xray.exe not found in archive');
      return false;
    } catch (e) {
      print('VPN SERVICE: Download error: $e');
      return false;
    }
  }

  /// Copy Xray from assets to app directory
  Future<bool> _copyXrayFromAssets() async {
    try {
      final appData = Platform.environment['LOCALAPPDATA'];
      final xrayDir = Directory('$appData\\VoyfyVPN');
      
      print('VPN SERVICE: Copying to $xrayDir');
      
      if (!await xrayDir.exists()) {
        print('VPN SERVICE: Creating directory $xrayDir');
        await xrayDir.create(recursive: true);
      }
      
      // Files to copy from assets
      final files = ['xray.exe', 'geoip.dat', 'geosite.dat', 'wintun.dll'];
      
      for (final file in files) {
        try {
          print('VPN SERVICE: Loading $file from assets...');
          final byteData = await rootBundle.load('assets/xray/$file');
          print('VPN SERVICE: Loaded $file, size: ${byteData.lengthInBytes} bytes');
          final bytes = byteData.buffer.asUint8List();
          final filePath = '${xrayDir.path}\\$file';
          await File(filePath).writeAsBytes(bytes);
          print('VPN SERVICE: Copied $file to $filePath');
        } catch (e) {
          print('VPN SERVICE: Failed to copy $file: $e');
          // Continue with other files
        }
      }
      
      // Check if xray.exe exists
      final xrayPath = '${xrayDir.path}\\xray.exe';
      if (await File(xrayPath).exists()) {
        print('VPN SERVICE: Xray ready at $xrayPath');
        return true;
      }
      
      print('VPN SERVICE: xray.exe not found after copy');
      return false;
    } catch (e, stackTrace) {
      print('VPN SERVICE: Copy from assets error: $e');
      print('VPN SERVICE: Stack trace: $stackTrace');
      return false;
    }
  }

  /// Ping server with config
  Future<int> ping(String config, String url, {int timeout = 10}) async {
    try {
      if (_isWindows) {
        final result = await _windowsChannel.invokeMethod<int>('ping', {
          'config': config,
          'url': url,
          'timeout': timeout,
        });
        return result ?? -1;
      }
      return await VpnclientEngineFlutter.client.ping(EngineType.libxray, config, url, timeout: timeout);
    } catch (e) {
      print('VPN SERVICE: Ping error: $e');
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
      return await VpnclientEngineFlutter.client.testConfig(EngineType.libxray, config);
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
      final status = await VpnclientEngineFlutter.client.getConnectionStatus();
      return _mapStatus(status);
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

  /// Dispose resources
  void dispose() {
    if (_currentStatus == VpnStatus.connected) {
      disconnect();
    }
    
    if (!_statusController.isClosed) _statusController.close();
    if (!_errorController.isClosed) _errorController.close();
  }

  // Private methods
  void _updateStatus(VpnStatus status) {
    _currentStatus = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }
  
  void _updateDataUsage(DataUsage usage) {
    if (!_dataUsageController.isClosed) {
      _dataUsageController.add(usage);
    }
  }
}
