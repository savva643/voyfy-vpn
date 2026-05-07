import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  
  // Whitelist bypass mode for Russia (uses Russian SNI domains)
  bool _whitelistBypass = false;
  bool get whitelistBypass => _whitelistBypass;

  /// Initialize settings from SharedPreferences
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoConnect = prefs.getBool('setting_auto_connect') ?? false;
      _killSwitch = prefs.getBool('setting_kill_switch') ?? false;
      _theme = prefs.getString('setting_theme') ?? 'system';
      _language = prefs.getString('setting_language') ?? 'en';
      _dns = prefs.getString('setting_dns') ?? 'default';
      _protocol = prefs.getString('setting_protocol') ?? 'vless';
      _excludedApps = prefs.getStringList('setting_excluded_apps') ?? [];
      _routeAllTraffic = prefs.getBool('setting_route_all_traffic') ?? true;
      _whitelistBypass = prefs.getBool('setting_whitelist_bypass') ?? false;
      notifyListeners();
    } catch (e) {
      print('SettingsProvider: Error initializing: $e');
    }
  }

  /// Set auto-connect
  Future<void> setAutoConnect(bool value) async {
    _autoConnect = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setting_auto_connect', value);
  }

  /// Set kill switch
  Future<void> setKillSwitch(bool value) async {
    _killSwitch = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setting_kill_switch', value);
  }

  /// Set theme
  Future<void> setTheme(String theme) async {
    _theme = theme;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('setting_theme', theme);
  }

  /// Set language
  Future<void> setLanguage(String lang) async {
    _language = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('setting_language', lang);
  }

  /// Set DNS
  Future<void> setDns(String dns) async {
    _dns = dns;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('setting_dns', dns);
  }

  /// Add excluded app
  Future<void> addExcludedApp(String packageName) async {
    if (!_excludedApps.contains(packageName)) {
      _excludedApps.add(packageName);
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('setting_excluded_apps', _excludedApps);
    }
  }

  /// Remove excluded app
  Future<void> removeExcludedApp(String packageName) async {
    _excludedApps.remove(packageName);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('setting_excluded_apps', _excludedApps);
  }

  /// Set route all traffic
  Future<void> setRouteAllTraffic(bool value) async {
    _routeAllTraffic = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setting_route_all_traffic', value);
  }
  
  /// Set whitelist bypass mode (for Russia)
  Future<void> setWhitelistBypass(bool value) async {
    _whitelistBypass = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setting_whitelist_bypass', value);
  }
}
