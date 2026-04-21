// API Configuration for Voyfy VPN
// Change this to your production URL when deploying

class ApiConfig {
  // Production URL
  static const String baseUrl = 'https://vip.necsoura.ru';

  // Development URL (uncomment for local development)
  // static const String baseUrl = 'http://localhost:4000';

  // API Endpoints
  static String get servers => '$baseUrl/api/servers';
  static String get authLogin => '$baseUrl/api/auth/login';
  static String get authRegister => '$baseUrl/api/auth/register';
  static String get authRefresh => '$baseUrl/api/auth/refresh';
  static String get authLogout => '$baseUrl/api/auth/logout';
  static String get authValidate => '$baseUrl/api/auth/validate';
  static String get subscription => '$baseUrl/api/subscription';
  static String get userProfile => '$baseUrl/api/user/profile';
  
  // Subscription URL for VPN client (requires UUID)
  static String subscriptionByUuid(String uuid) => '$baseUrl/api/subscription/$uuid';
}
