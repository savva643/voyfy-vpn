import 'package:flutter/foundation.dart';

/// App Settings Provider
/// Manages application settings and preferences
class SettingsProvider extends ChangeNotifier {
  // Connection settings
  bool _autoConnect = false;
  bool get autoConnect => _autoConnect;
  
  bool _killSwitch = false;
  bool get killSwitch => _killSwitch;
  
  // UI settings
  String _theme = 'system'; // 'light', 'dark', 'system'
  String get theme => _theme;
  
  // Language
  String _language = 'en';
  String get language => _language;
  
  // Advanced settings
  String _dns = 'default'; // 'default', 'cloudflare', 'google', 'custom'
  String get dns => _dns;
  
  String _protocol = 'vless'; // 'vless', 'vmess'
  String get protocol => _protocol;
  
  // Split tunneling / App routing
  List<String> _excludedApps = [];
  List<String> get excludedApps => List.unmodifiable(_excludedApps);
  
  bool _routeAllTraffic = true;
  bool get routeAllTraffic => _routeAllTraffic;

  /// Set auto-connect
  Future<void> setAutoConnect(bool value) async {
    _autoConnect = value;
    notifyListeners();
    // TODO: Save to SharedPreferences
  }

  /// Set kill switch
  Future<void> setKillSwitch(bool value) async {
    _killSwitch = value;
    notifyListeners();
    // TODO: Save to SharedPreferences
  }

  /// Set theme
  Future<void> setTheme(String theme) async {
    _theme = theme;
    notifyListeners();
    // TODO: Save to SharedPreferences
  }

  /// Set language
  Future<void> setLanguage(String lang) async {
    _language = lang;
    notifyListeners();
    // TODO: Save to SharedPreferences
  }

  /// Set DNS
  Future<void> setDns(String dns) async {
    _dns = dns;
    notifyListeners();
    // TODO: Save to SharedPreferences
  }

  /// Add excluded app
  Future<void> addExcludedApp(String packageName) async {
    if (!_excludedApps.contains(packageName)) {
      _excludedApps.add(packageName);
      notifyListeners();
    }
  }

  /// Remove excluded app
  Future<void> removeExcludedApp(String packageName) async {
    _excludedApps.remove(packageName);
    notifyListeners();
  }

  /// Set route all traffic
  Future<void> setRouteAllTraffic(bool value) async {
    _routeAllTraffic = value;
    notifyListeners();
  }
}
