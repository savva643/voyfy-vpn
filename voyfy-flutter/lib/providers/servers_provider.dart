import 'package:flutter/foundation.dart';

import '../models/vpn_server.dart';
import '../services/api_service.dart';

/// Servers Provider
/// Manages VPN servers list from API
class ServersProvider extends ChangeNotifier {
  // Servers list
  List<VpnServer> _servers = [];
  List<VpnServer> get servers => List.unmodifiable(_servers);
  
  // Filtered/Premium servers
  List<VpnServer> get freeServers => _servers.where((s) => !s.premium).toList();
  List<VpnServer> get premiumServers => _servers.where((s) => s.premium).toList();
  
  // State
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  
  DateTime? _lastUpdated;
  DateTime? get lastUpdated => _lastUpdated;

  /// Fetch servers from API
  Future<void> fetchServers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final servers = await ApiService.getServers();
      _servers = servers;
      _lastUpdated = DateTime.now();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh servers (force reload)
  Future<void> refreshServers() async {
    await fetchServers();
  }

  /// Get server by ID
  VpnServer? getServerById(String id) {
    try {
      return _servers.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get server by country code
  List<VpnServer> getServersByCountry(String countryCode) {
    return _servers.where((s) => s.countryCode == countryCode).toList();
  }

  /// Get countries list
  List<String> get countries {
    final countrySet = _servers.map((s) => s.country).toSet();
    return countrySet.toList()..sort();
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
