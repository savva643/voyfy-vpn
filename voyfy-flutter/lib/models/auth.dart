import 'user.dart';

/// Auth Tokens Model
/// Represents JWT tokens received from authentication
class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final String? expiresIn;

  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.expiresIn,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    final tokensData = json['tokens'] ?? json;
    
    return AuthTokens(
      accessToken: tokensData['accessToken'] ?? tokensData['access_token'] ?? '',
      refreshToken: tokensData['refreshToken'] ?? tokensData['refresh_token'] ?? '',
      expiresIn: tokensData['expiresIn'] ?? tokensData['expires_in'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'expires_in': expiresIn,
    };
  }

  @override
  String toString() {
    return 'AuthTokens(accessToken: ${accessToken.substring(0, accessToken.length > 20 ? 20 : accessToken.length)}..., expiresIn: $expiresIn)';
  }
}

/// Auth Response Model
/// Combined user and tokens from login/register
class AuthResponse {
  final User user;
  final AuthTokens tokens;

  AuthResponse({
    required this.user,
    required this.tokens,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    
    return AuthResponse(
      user: User.fromJson(data),
      tokens: AuthTokens.fromJson(data),
    );
  }

  @override
  String toString() {
    return 'AuthResponse(user: $user, tokens: $tokens)';
  }
}
