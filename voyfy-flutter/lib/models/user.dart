/// User Model
/// Represents authenticated user with subscription info
class User {
  final String id;
  final String email;
  final String uuid;
  final String? subscriptionUrl;
  final int dataLimit;
  final int usedData;
  final DateTime? expiryDate;
  final bool isActive;
  final bool isAdmin;
  final DateTime? createdAt;

  User({
    required this.id,
    required this.email,
    required this.uuid,
    this.subscriptionUrl,
    this.dataLimit = 10737418240, // 10GB default
    this.usedData = 0,
    this.expiryDate,
    this.isActive = true,
    this.isAdmin = false,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final userData = json['user'] ?? json;
    
    return User(
      id: userData['id']?.toString() ?? '',
      email: userData['email'] ?? '',
      uuid: userData['uuid'] ?? '',
      subscriptionUrl: userData['subscriptionUrl'] ?? userData['subscription_url'],
      dataLimit: userData['dataLimit'] ?? userData['data_limit'] ?? 10737418240,
      usedData: userData['usedData'] ?? userData['used_data'] ?? 0,
      expiryDate: userData['expiryDate'] != null || userData['expiry_date'] != null
          ? DateTime.tryParse(userData['expiryDate'] ?? userData['expiry_date'])
          : null,
      isActive: userData['isActive'] ?? userData['is_active'] ?? true,
      isAdmin: userData['isAdmin'] ?? userData['is_admin'] ?? false,
      createdAt: userData['createdAt'] != null || userData['created_at'] != null
          ? DateTime.tryParse(userData['createdAt'] ?? userData['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'uuid': uuid,
      'subscription_url': subscriptionUrl,
      'data_limit': dataLimit,
      'used_data': usedData,
      'expiry_date': expiryDate?.toIso8601String(),
      'is_active': isActive,
      'is_admin': isAdmin,
    };
  }

  /// Get remaining data in bytes
  int get remainingData => dataLimit - usedData;

  /// Check if subscription is expired
  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  /// Format data usage for display
  String get formattedUsedData {
    return _formatBytes(usedData);
  }

  String get formattedDataLimit {
    return _formatBytes(dataLimit);
  }

  String get formattedRemainingData {
    return _formatBytes(remainingData);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  String toString() {
    return 'User(id: $id, email: $email, uuid: $uuid)';
  }
}
