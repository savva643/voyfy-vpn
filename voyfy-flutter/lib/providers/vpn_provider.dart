import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/vpn_server.dart';
import '../services/vpn_service.dart';
import '../services/tray_manager.dart';

/// VPN State Provider
/// Manages VPN connection state and server selection
class VpnProvider extends ChangeNotifier {
  final VpnService _vpnService = VpnService();
  
  // Connection state
  VpnStatus _status = VpnStatus.disconnected;
  VpnStatus get status => _status;
  
  /// Check actual VPN service status (for desktop platforms)
  Future<void> checkStatus() async {
    print('VPN PROVIDER: Checking service status');
    final actualStatus = await _vpnService.checkStatus();
    print('VPN PROVIDER: Service status is $actualStatus, current is $_status');
    
    if (_status != actualStatus) {
      _status = actualStatus;
      notifyListeners();
    }
  }
  
  bool get isConnected => _status == VpnStatus.connected;
  bool get isConnecting => _status == VpnStatus.connecting;
  bool get isDisconnecting => _status == VpnStatus.disconnecting;
  bool get isDisconnected => _status == VpnStatus.disconnected;
  
  // Selected server
  VpnServer? _selectedServer;
  VpnServer? get selectedServer => _selectedServer;
  
  // Available servers
  List<VpnServer> _servers = [];
  List<VpnServer> get servers => List.unmodifiable(_servers);
  
  // Data usage
  DataUsage? _dataUsage;
  DataUsage? get dataUsage => _dataUsage;
  
  // Speed tracking (bytes per second)
  int _downloadSpeed = 0;
  int get downloadSpeed => _downloadSpeed;
  int _uploadSpeed = 0;
  int get uploadSpeed => _uploadSpeed;
  DataUsage? _lastDataUsage;
  DateTime? _lastSpeedUpdate;
  Timer? _speedTimer;
  
  // Ping
  int _pingMs = 0;
  int get pingMs => _pingMs;
  Timer? _pingTimer;
  
  // Connection duration
  DateTime? _connectedAt;
  Duration? get connectionDuration {
    if (_connectedAt == null || !isConnected) return null;
    return DateTime.now().difference(_connectedAt!);
  }
  
  String get formattedDuration {
    final duration = connectionDuration;
    if (duration == null) return '00:00:00';
    
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    
    return '$hours:$minutes:$seconds';
  }
  
  // Error state
  VpnError? _lastError;
  VpnError? get lastError => _lastError;
  
  // Settings
  bool _killSwitchEnabled = false;
  bool get killSwitchEnabled => _killSwitchEnabled;
  
  bool _autoConnectEnabled = false;
  bool get autoConnectEnabled => _autoConnectEnabled;
  
  // Subscriptions
  StreamSubscription<VpnStatus>? _statusSubscription;
  StreamSubscription<VpnError>? _errorSubscription;
  Timer? _durationTimer;
  
  // Initialization state
  bool _isInitializing = false;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initialize the provider
  Future<void> initialize() async {
    if (_isInitializing || _isInitialized) {
      print('VPN PROVIDER: Already initialized or initializing, skipping');
      return;
    }
    
    _isInitializing = true;
    print('VPN PROVIDER: Starting initialization...');
    
    await _vpnService.initialize();
    
    // Listen to VPN status changes
    _statusSubscription = _vpnService.onStatusChanged.listen((status) {
      _status = status;
      
      if (status == VpnStatus.connected) {
        _connectedAt = DateTime.now();
        _startDurationTimer();
        _startPingTimer();
        _startSpeedTimer();
      } else if (status == VpnStatus.disconnected) {
        _connectedAt = null;
        _stopDurationTimer();
        _stopPingTimer();
        _stopSpeedTimer();
      }
      
      notifyListeners();
      
      // Update tray menu on desktop
      TrayManager().updateMenu();
    });
    
    // Listen to errors
    _errorSubscription = _vpnService.onError.listen((error) {
      _lastError = error;
      notifyListeners();
    });
    
    _isInitializing = false;
    _isInitialized = true;
    print('VPN PROVIDER: Initialization complete');
  }

  /// Set available servers
  void setServers(List<VpnServer> servers) {
    _servers = servers;
    
    // Auto-select first non-premium server if none selected
    if (_selectedServer == null && servers.isNotEmpty) {
      final freeServer = servers.firstWhere(
        (s) => !s.premium,
        orElse: () => servers.first,
      );
      _selectedServer = freeServer;
    }
    
    notifyListeners();
  }

  /// Select a server
  void selectServer(VpnServer server) {
    _selectedServer = server;
    
    // If connected, reconnect to new server
    if (isConnected) {
      connect();
    }
    
    notifyListeners();
  }

  /// Connect to VPN
  Future<bool> connect() async {
    if (_selectedServer == null) {
      _lastError = VpnError(
        type: 'config_error',
        message: 'No server selected',
      );
      notifyListeners();
      return false;
    }

    _lastError = null;
    notifyListeners();

    print('VPN PROVIDER: selectedServer=${_selectedServer?.name}, vlessUrl=${_selectedServer?.vlessUrl?.substring(0, _selectedServer?.vlessUrl?.length.clamp(0, 30) ?? 0)}');
    final result = await _vpnService.connect(
      config: _selectedServer!.vlessUrl ?? '',
      serverName: _selectedServer!.name,
    );

    return result;
  }

  /// Disconnect from VPN - non-blocking to prevent UI freeze
  Future<void> disconnect() async {
    _status = VpnStatus.disconnecting;
    notifyListeners();
    
    // Run disconnect in background to avoid UI freeze
    try {
      final result = await _vpnService.disconnect();
      print('VPN PROVIDER: Disconnect completed with result: $result');
    } catch (e) {
      print('VPN PROVIDER: Disconnect error: $e');
      _status = VpnStatus.error;
      notifyListeners();
    }
  }

  /// Toggle connection
  Future<bool> toggleConnection() async {
    print('VPN PROVIDER: toggleConnection called, _selectedServer=$_selectedServer, status=$_status');
    
    // Block if currently disconnecting
    if (_status == VpnStatus.disconnecting) {
      print('VPN PROVIDER: Ignoring toggle - currently disconnecting');
      return false;
    }
    
    if (_selectedServer == null) {
      _lastError = VpnError(
        type: 'config_error',
        message: 'Please select a server first',
      );
      notifyListeners();
      return false;
    }

    // Fetch VLESS config from API
    String? vlessUrl;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/subscriptions/config/${_selectedServer!.id}');
      print('VPN PROVIDER: Fetching config from $uri');
      
      final response = await http.get(
        uri,
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );
      
      print('VPN PROVIDER: Config API response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['config'] != null) {
          vlessUrl = data['config']['vlessUrl'] as String?;
          // Save vlessUrl to selectedServer for later use (ping, etc.)
          _selectedServer = _selectedServer!.copyWith(vlessUrl: vlessUrl);
          print('VPN PROVIDER: Got vlessUrl: ${vlessUrl?.substring(0, vlessUrl!.length.clamp(0, 50))}...');
          print('VPN PROVIDER: Saved vlessUrl to selectedServer');
        }
      }
    } catch (e) {
      print('VPN PROVIDER: Error fetching config: $e');
    }
    
    if (vlessUrl == null || vlessUrl.isEmpty) {
      _lastError = VpnError(
        type: 'config_error',
        message: 'Failed to get VLESS configuration',
      );
      notifyListeners();
      return false;
    }

    return await _vpnService.toggleConnection(
      config: vlessUrl,
      serverName: _selectedServer!.name,
    );
  }

  /// Enable/disable kill switch
  Future<void> setKillSwitch(bool enabled) async {
    _killSwitchEnabled = enabled;
    notifyListeners();
  }

  /// Enable/disable auto-connect
  Future<void> setAutoConnect(bool enabled) async {
    _autoConnectEnabled = enabled;
    notifyListeners();
  }

  /// Clear last error
  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners(); // Update duration display
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  /// Start ping measurement
  void _startPingTimer() {
    print('VPN PROVIDER: Starting ping timer, server: ${_selectedServer?.toString()}');
    print('VPN PROVIDER: vlessUrl: ${_selectedServer?.vlessUrl?.substring(0, 50)}, host: ${_selectedServer?.host}');
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      print('VPN PROVIDER: Ping timer tick, isConnected: $isConnected, server: ${_selectedServer != null}');
      if (isConnected && _selectedServer != null) {
        // Try vlessUrl first, fallback to server.host
        String host = _extractHostFromConfig(_selectedServer!.vlessUrl ?? '');
        if (host == '8.8.8.8' && _selectedServer!.host != null && _selectedServer!.host!.isNotEmpty) {
          host = _selectedServer!.host!;
        }
        print('VPN PROVIDER: Measuring ping to host: $host');
        final ping = await _vpnService.measurePing(host);
        print('VPN PROVIDER: Ping result: $ping ms');
        if (ping > 0) {
          _pingMs = ping;
          notifyListeners();
        }
      }
    });
  }
  
  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _pingMs = 0;
  }
  
  /// Start speed calculation using FFI
  void _startSpeedTimer() {
    print('VPN PROVIDER: Starting speed timer (FFI mode)');
    _speedTimer?.cancel();
    _lastDataUsage = null;
    _lastSpeedUpdate = null;
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!isConnected) return;
      
      print('VPN PROVIDER: Speed timer tick - getting stats via FFI');
      try {
        // Use FFI to get network stats directly from Windows API
        final stats = await _vpnService.getNetworkStats();
        final recv = stats['recv'] ?? 0;
        final sent = stats['sent'] ?? 0;
        
        print('VPN PROVIDER: FFI stats - recv: $recv, sent: $sent');
        
        // Update data usage
        _dataUsage = DataUsage(bytesReceived: recv, bytesSent: sent);
        
        // Calculate speed
        final now = DateTime.now();
        if (_lastDataUsage != null && _lastSpeedUpdate != null) {
          final timeDiff = now.difference(_lastSpeedUpdate!).inSeconds;
          if (timeDiff > 0) {
            final bytesDiffDown = recv - _lastDataUsage!.bytesReceived;
            final bytesDiffUp = sent - _lastDataUsage!.bytesSent;
            _downloadSpeed = (bytesDiffDown / timeDiff).round();
            _uploadSpeed = (bytesDiffUp / timeDiff).round();
            print('VPN PROVIDER: Speed updated - Down: $_downloadSpeed, Up: $_uploadSpeed');
            notifyListeners();
          }
        }
        _lastDataUsage = _dataUsage;
        _lastSpeedUpdate = now;
      } catch (e) {
        print('VPN PROVIDER: Error getting stats via FFI: $e');
      }
    });
  }
  
  void _stopSpeedTimer() {
    _speedTimer?.cancel();
    _speedTimer = null;
    _downloadSpeed = 0;
    _uploadSpeed = 0;
    _lastDataUsage = null;
    _lastSpeedUpdate = null;
  }
  
  String _extractHostFromConfig(String config) {
    try {
      // VLESS URL format: vless://uuid@host:port?params#tag
      // Extract host between @ and :
      final atIndex = config.indexOf('@');
      if (atIndex != -1) {
        final afterAt = config.substring(atIndex + 1);
        final colonIndex = afterAt.indexOf(':');
        if (colonIndex != -1) {
          final host = afterAt.substring(0, colonIndex);
          if (host.isNotEmpty) return host;
        }
      }
      // Fallback to IP parsing
      final ipRegex = RegExp(r'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})');
      final match = ipRegex.firstMatch(config);
      if (match != null) return match.group(1)!;
      return '8.8.8.8';
    } catch (e) {
      return '8.8.8.8';
    }
  }
  
  /// Disconnect VPN when app closes
  Future<void> disconnectOnAppClose() async {
    if (isConnected || isConnecting) {
      print('VPN PROVIDER: App closing, disconnecting VPN...');
      await disconnect();
    }
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _errorSubscription?.cancel();
    _stopDurationTimer();
    _stopPingTimer();
    _stopSpeedTimer();
    _vpnService.dispose();
    super.dispose();
  }
}
