import 'dart:async';
import 'package:flutter/foundation.dart';

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
        type: VpnErrorType.configurationError,
        message: 'No server selected',
      );
      notifyListeners();
      return false;
    }

    _lastError = null;
    notifyListeners();

    final result = await _vpnService.connect(
      serverIndex: _servers.indexOf(_selectedServer!),
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
    if (_selectedServer == null) {
      _lastError = VpnError(
        type: VpnErrorType.configurationError,
        message: 'Please select a server first',
      );
      notifyListeners();
      return false;
    }

    return await _vpnService.toggleConnection(
      serverIndex: _servers.indexOf(_selectedServer!),
      serverName: _selectedServer!.name,
    );
  }

  /// Add subscription URL
  Future<bool> addSubscription(String url) async {
    try {
      final result = await _vpnService.addSubscription(url);
      return result != null;
    } catch (e) {
      _lastError = VpnError(
        type: VpnErrorType.configurationError,
        message: 'Failed to add subscription',
        details: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }

  /// Enable/disable kill switch
  Future<void> setKillSwitch(bool enabled) async {
    _killSwitchEnabled = enabled;
    await _vpnService.setKillSwitch(enabled);
    notifyListeners();
  }

  /// Enable/disable auto-connect
  Future<void> setAutoConnect(bool enabled) async {
    _autoConnectEnabled = enabled;
    await _vpnService.setAutoConnect(enabled);
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
