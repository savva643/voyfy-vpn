import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/user.dart';
import '../models/auth.dart';
import '../services/api_service.dart';

/// Authentication State
enum AuthState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

/// Auth Provider
/// Manages user authentication state
class AuthProvider extends ChangeNotifier {
  // State
  AuthState _state = AuthState.initial;
  AuthState get state => _state;
  
  bool get isLoading => _state == AuthState.loading;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isUnauthenticated => _state == AuthState.unauthenticated;
  bool get hasError => _state == AuthState.error;
  
  // User data
  User? _user;
  User? get user => _user;
  
  // Auth tokens
  AuthTokens? _tokens;
  AuthTokens? get tokens => _tokens;
  
  // Error message
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Initialize - check for stored session
  /// NOTE: Do NOT call notifyListeners here - it causes setState during build
  Future<void> initialize() async {
    _state = AuthState.loading;
    // Don't notify here - let the UI show loading state initially

    try {
      // Load saved tokens
      await ApiService.loadTokens();

      // Simply check if token exists - no backend validation to avoid issues
      if (ApiService.accessToken != null && ApiService.accessToken!.isNotEmpty) {
        _state = AuthState.authenticated;
      } else {
        _state = AuthState.unauthenticated;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _state = AuthState.unauthenticated; // Treat errors as unauthenticated
    }

    // Notify listeners to update UI with auth state
    notifyListeners();
  }

  /// Login with email and password
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final response = await ApiService.login(
        email: email,
        password: password,
      );
      
      _user = response.user;
      _tokens = response.tokens;
      _state = AuthState.authenticated;
      
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  /// Register new user
  Future<bool> register({
    required String email,
    required String password,
    String? name,
  }) async {
    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final response = await ApiService.register(
        email: email,
        password: password,
        name: name,
      );
      
      _user = response.user;
      _tokens = response.tokens;
      _state = AuthState.authenticated;
      
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  /// FUTURE: External OAuth/SSO Login
  /// Placeholder for future external auth integration
  Future<bool> externalLogin({
    required String provider,
    required String token,
  }) async {
    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();
    
    try {
      // TODO: Implement when connecting to existing ecosystem
      _errorMessage = 'External authentication not yet implemented';
      _state = AuthState.error;
      notifyListeners();
      return false;
      
      // When implemented:
      // final response = await ApiService.externalLogin(
      //   provider: provider,
      //   token: token,
      // );
      // _user = response.user;
      // _tokens = response.tokens;
      // _state = AuthState.authenticated;
      // notifyListeners();
      // return true;
    } catch (e) {
      _errorMessage = e.toString();
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    _state = AuthState.loading;
    notifyListeners();
    
    try {
      await ApiService.logout();
    } catch (e) {
      // Ignore logout errors
    }
    
    _user = null;
    _tokens = null;
    _errorMessage = null;
    _state = AuthState.unauthenticated;
    
    notifyListeners();
  }

  /// Refresh user profile
  Future<void> refreshProfile() async {
    if (!isAuthenticated) return;
    
    try {
      final user = await ApiService.getProfile();
      _user = user;
      notifyListeners();
    } catch (e) {
      // Ignore refresh errors
    }
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    if (_state == AuthState.error) {
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  /// Update API base URL
  Future<void> setApiUrl(String url) async {
    ApiService.baseUrl = url;
    
    // Test connection
    final isHealthy = await ApiService.checkHealth();
    if (!isHealthy) {
      _errorMessage = 'Cannot connect to API at $url';
      notifyListeners();
    }
  }

  /// Get current API URL
  String get apiUrl => ApiService.baseUrl;
}
