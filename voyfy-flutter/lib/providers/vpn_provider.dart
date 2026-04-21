import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/vpn_server.dart';
import '../services/vpn_service.dart';

/// VPN State Provider
/// Manages VPN connection state and server selection
class VpnProvider extends ChangeNotifier {
  final VpnService _vpnService = VpnService();
  
  // Connection state
  VpnStatus _status = VpnStatus.disconnected;
  VpnStatus get status => _status;
  
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
  StreamSubscription<DataUsage>? _dataUsageSubscription;
  StreamSubscription<VpnError>? _errorSubscription;
  Timer? _durationTimer;

  /// Initialize the provider
  Future<void> initialize() async {
    await _vpnService.initialize();
    
    // Listen to VPN status changes
    _statusSubscription = _vpnService.onStatusChanged.listen((status) {
      _status = status;
      
      if (status == VpnStatus.connected) {
        _connectedAt = DateTime.now();
        _startDurationTimer();
      } else if (status == VpnStatus.disconnected) {
        _connectedAt = null;
        _stopDurationTimer();
      }
      
      notifyListeners();
    });
    
    // Listen to data usage updates
    _dataUsageSubscription = _vpnService.onDataUsageUpdated.listen((usage) {
      _dataUsage = usage;
      notifyListeners();
    });
    
    // Listen to errors
    _errorSubscription = _vpnService.onError.listen((error) {
      _lastError = error;
      notifyListeners();
    });
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

  /// Disconnect from VPN
  Future<bool> disconnect() async {
    return await _vpnService.disconnect();
  }

  /// Toggle connection
  Future<bool> toggleConnection() async {
    print('VPN PROVIDER: toggleConnection called, _selectedServer=$_selectedServer');
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
          print('VPN PROVIDER: Got vlessUrl: ${vlessUrl?.substring(0, vlessUrl!.length.clamp(0, 50))}...');
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

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _dataUsageSubscription?.cancel();
    _errorSubscription?.cancel();
    _stopDurationTimer();
    _vpnService.dispose();
    super.dispose();
  }
}
