import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth.dart';
import '../models/user.dart';
import '../models/vpn_server.dart';

/// API Exception
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;

  ApiException({
    required this.message,
    this.statusCode,
    this.body,
  });

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

/// API Service
/// Handles all communication with the backend API
class ApiService {
  // Base URL - can be changed in settings
  static String _baseUrl = 'http://localhost:4000';
  static String get baseUrl => _baseUrl;
  
  static set baseUrl(String url) {
    _baseUrl = url.replaceAll(RegExp(r'/+$'), ''); // Remove trailing slashes
    _saveBaseUrl(url);
  }

  // Load base URL from preferences on initialization
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('api_base_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _baseUrl = savedUrl;
    }
  }

  static Future<void> _saveBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', url);
  }

  // Auth token storage
  static String? _accessToken;
  static String? _refreshToken;

  static String? get accessToken => _accessToken;
  static String? get refreshToken => _refreshToken;

  static Future<void> setTokens(String access, String refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', access);
    await prefs.setString('refresh_token', refresh);
  }

  static Future<void> loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
  }

  static Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  // HTTP Headers
  static Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    
    // Add platform info headers
    headers['platform'] = Platform.operatingSystem;
    
    return headers;
  }

  // HTTP Methods
  static Future<dynamic> _get(String endpoint) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    
    try {
      final response = await http.get(url, headers: _headers);
      return _handleResponse(response);
    } on SocketException catch (e) {
      throw ApiException(
        message: 'Network error. Please check your connection.',
        body: e.toString(),
      );
    } catch (e) {
      throw ApiException(message: 'Request failed: $e');
    }
  }

  static Future<dynamic> _post(String endpoint, {Map<String, dynamic>? body}) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    
    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } on SocketException catch (e) {
      throw ApiException(
        message: 'Network error. Please check your connection.',
        body: e.toString(),
      );
    } catch (e) {
      throw ApiException(message: 'Request failed: $e');
    }
  }

  static Future<dynamic> _put(String endpoint, {Map<String, dynamic>? body}) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    
    try {
      final response = await http.put(
        url,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } on SocketException catch (e) {
      throw ApiException(
        message: 'Network error. Please check your connection.',
        body: e.toString(),
      );
    } catch (e) {
      throw ApiException(message: 'Request failed: $e');
    }
  }

  static Future<dynamic> _delete(String endpoint) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    
    try {
      final response = await http.delete(url, headers: _headers);
      return _handleResponse(response);
    } on SocketException catch (e) {
      throw ApiException(
        message: 'Network error. Please check your connection.',
        body: e.toString(),
      );
    } catch (e) {
      throw ApiException(message: 'Request failed: $e');
    }
  }

  static dynamic _handleResponse(http.Response response) {
    final body = response.body;
    final statusCode = response.statusCode;
    
    if (statusCode >= 200 && statusCode < 300) {
      if (body.isEmpty) return null;
      
      try {
        return jsonDecode(body);
      } catch (e) {
        return body; // Return raw string if not JSON
      }
    }
    
    // Handle specific status codes
    String message = 'Request failed';
    
    try {
      final jsonBody = jsonDecode(body);
      message = jsonBody['message'] ?? jsonBody['error'] ?? 'Request failed';
    } catch (e) {
      message = body.isNotEmpty ? body : 'HTTP $statusCode';
    }
    
    if (statusCode == 401) {
      message = 'Session expired. Please login again.';
      // TODO: Trigger automatic token refresh
    } else if (statusCode == 403) {
      message = 'Access denied. $message';
    } else if (statusCode == 404) {
      message = 'Resource not found.';
    } else if (statusCode == 409) {
      message = 'Conflict: $message';
    } else if (statusCode >= 500) {
      message = 'Server error. Please try again later.';
    }
    
    throw ApiException(
      message: message,
      statusCode: statusCode,
      body: body,
    );
  }

  // ==========================================
  // Authentication Endpoints
  // ==========================================

  /// Register new user (Test mode)
  static Future<AuthResponse> register({
    required String email,
    required String password,
    String? name,
  }) async {
    final response = await _post('/api/auth/register', body: {
      'email': email,
      'password': password,
      'name': name,
    });
    
    if (response['success'] == true && response['data'] != null) {
      final authResponse = AuthResponse.fromJson(response['data']);
      await setTokens(authResponse.tokens.accessToken, authResponse.tokens.refreshToken);
      return authResponse;
    }
    
    throw ApiException(message: response['message'] ?? 'Registration failed');
  }

  /// Login user (Test mode)
  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _post('/api/auth/login', body: {
      'email': email,
      'password': password,
    });
    
    if (response['success'] == true && response['data'] != null) {
      final authResponse = AuthResponse.fromJson(response['data']);
      await setTokens(authResponse.tokens.accessToken, authResponse.tokens.refreshToken);
      return authResponse;
    }
    
    throw ApiException(message: response['message'] ?? 'Login failed');
  }

  /// FUTURE: External OAuth/SSO Login
  /// This is a placeholder for future external auth integration
  static Future<AuthResponse> externalLogin({
    required String provider,
    required String token,
  }) async {
    // TODO: Implement when connecting to existing ecosystem
    throw ApiException(
      message: 'External authentication not yet implemented. Use login() for test mode.',
    );
  }

  /// Refresh access token
  static Future<bool> refreshAccessToken() async {
    if (_refreshToken == null) return false;
    
    try {
      final response = await _post('/api/auth/refresh', body: {
        'refreshToken': _refreshToken,
      });
      
      if (response['success'] == true && response['data'] != null) {
        final tokens = AuthTokens.fromJson(response['data']['tokens']);
        await setTokens(tokens.accessToken, tokens.refreshToken);
        return true;
      }
    } catch (e) {
      // Token refresh failed
    }
    
    return false;
  }

  /// Logout user
  static Future<bool> logout() async {
    try {
      if (_refreshToken != null) {
        await _post('/api/auth/logout', body: {
          'refreshToken': _refreshToken,
        });
      }
    } catch (e) {
      // Ignore logout errors
    }
    
    await clearTokens();
    return true;
  }

  /// Validate current session
  static Future<User?> validateSession() async {
    if (_accessToken == null) return null;
    
    try {
      final response = await _get('/api/auth/validate');
      
      if (response['success'] == true && response['data'] != null) {
        return User.fromJson(response['data']['user']);
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        // Try to refresh token
        final bool refreshed = await refreshAccessToken();
        if (refreshed == true) {
          return validateSession(); // Retry with new token
        }
      }
      rethrow;
    }
    
    return null;
  }

  // ==========================================
  // User Endpoints
  // ==========================================

  /// Get current user profile
  static Future<User> getProfile() async {
    final response = await _get('/api/user/profile');
    
    if (response['success'] == true && response['data'] != null) {
      return User.fromJson(response['data']['user']);
    }
    
    throw ApiException(message: response['message'] ?? 'Failed to get profile');
  }

  // ==========================================
  // Server Endpoints
  // ==========================================

  /// Get all VPN servers
  static Future<List<VpnServer>> getServers() async {
    final response = await _get('/api/servers');
    
    if (response['success'] == true && response['data'] != null) {
      final serversList = response['data']['servers'] as List;
      return serversList.map((s) => VpnServer.fromJson(s)).toList();
    }
    
    throw ApiException(message: response['message'] ?? 'Failed to get servers');
  }

  /// Get server by ID
  static Future<VpnServer> getServerById(String id) async {
    final response = await _get('/api/servers/$id');
    
    if (response['success'] == true && response['data'] != null) {
      return VpnServer.fromJson(response['data']['server']);
    }
    
    throw ApiException(message: response['message'] ?? 'Failed to get server');
  }

  // ==========================================
  // Subscription Endpoints
  // ==========================================

  /// Get user subscription info
  static Future<Map<String, dynamic>> getSubscription() async {
    final response = await _get('/api/subscription');
    
    if (response['success'] == true && response['data'] != null) {
      return {
        'subscriptionUrl': response['data']['subscriptionUrl'],
        'subscriptionContent': response['data']['subscriptionContent'],
        'servers': (response['data']['servers'] as List)
            .map((s) => VpnServer.fromJson(s))
            .toList(),
        'stats': response['data']['stats'],
      };
    }
    
    throw ApiException(message: response['message'] ?? 'Failed to get subscription');
  }

  /// Get subscription as JSON with VLESS URLs
  static Future<List<VpnServer>> getSubscriptionJson() async {
    final response = await _get('/api/subscription/json');
    
    if (response['success'] == true && response['data'] != null) {
      final serversList = response['data']['servers'] as List;
      return serversList.map((s) => VpnServer.fromJson(s)).toList();
    }
    
    throw ApiException(message: response['message'] ?? 'Failed to get subscription');
  }

  /// Get subscription by UUID (for VPN client)
  static Future<String> getSubscriptionByUuid(String uuid) async {
    final url = Uri.parse('$_baseUrl/api/subscription/$uuid');
    
    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        return response.body;
      }
      
      throw ApiException(
        message: 'Failed to get subscription',
        statusCode: response.statusCode,
      );
    } on SocketException catch (e) {
      throw ApiException(
        message: 'Network error. Please check your connection.',
        body: e.toString(),
      );
    }
  }

  // ==========================================
  // Admin Endpoints (Admin users only)
  // ==========================================

  /// Add new server (Admin only)
  static Future<VpnServer> addServer({
    required String name,
    required String country,
    required String countryCode,
    required String host,
    int port = 443,
    bool premium = false,
  }) async {
    final response = await _post('/api/admin/servers', body: {
      'name': name,
      'country': country,
      'countryCode': countryCode,
      'host': host,
      'port': port,
      'premium': premium,
    });
    
    if (response['success'] == true && response['data'] != null) {
      return VpnServer.fromJson(response['data']['server']);
    }
    
    throw ApiException(message: response['message'] ?? 'Failed to add server');
  }

  /// Update server (Admin only)
  static Future<VpnServer> updateServer(
    String id, {
    String? name,
    String? country,
    String? countryCode,
    String? host,
    int? port,
    bool? premium,
    bool? isActive,
    int? loadPercentage,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (country != null) body['country'] = country;
    if (countryCode != null) body['countryCode'] = countryCode;
    if (host != null) body['host'] = host;
    if (port != null) body['port'] = port;
    if (premium != null) body['premium'] = premium;
    if (isActive != null) body['isActive'] = isActive;
    if (loadPercentage != null) body['loadPercentage'] = loadPercentage;
    
    final response = await _put('/api/admin/servers/$id', body: body);
    
    if (response['success'] == true && response['data'] != null) {
      return VpnServer.fromJson(response['data']['server']);
    }
    
    throw ApiException(message: response['message'] ?? 'Failed to update server');
  }

  /// Delete server (Admin only)
  static Future<bool> deleteServer(String id) async {
    final response = await _delete('/api/admin/servers/$id');
    return response['success'] == true;
  }

  /// Get all users (Admin only)
  static Future<List<User>> getAllUsers() async {
    final response = await _get('/api/admin/users');
    
    if (response['success'] == true && response['data'] != null) {
      final usersList = response['data']['users'] as List;
      return usersList.map((u) => User.fromJson(u)).toList();
    }
    
    throw ApiException(message: response['message'] ?? 'Failed to get users');
  }

  /// Get Xray configuration (Admin only)
  static Future<Map<String, dynamic>> getXrayConfig() async {
    final response = await _get('/api/admin/xray-config');
    
    if (response['success'] == true && response['data'] != null) {
      return response['data']['config'];
    }
    
    throw ApiException(message: response['message'] ?? 'Failed to get Xray config');
  }

  // ==========================================
  // Health Check
  // ==========================================

  /// Check API health
  static Future<bool> checkHealth() async {
    try {
      final response = await _get('/api/health');
      return response['status'] == 'ok';
    } catch (e) {
      return false;
    }
  }
}
