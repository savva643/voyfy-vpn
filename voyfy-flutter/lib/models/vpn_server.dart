/// VPN Server Model
/// Represents a VPN server location
class VpnServer {
  final String id;
  final String name;
  final String country;
  final String countryCode;
  final String host;
  final int port;
  final bool premium;
  final int? load;
  final String? vlessUrl;

  VpnServer({
    required this.id,
    required this.name,
    required this.country,
    required this.countryCode,
    required this.host,
    this.port = 443,
    this.premium = false,
    this.load,
    this.vlessUrl,
  });

  factory VpnServer.fromJson(Map<String, dynamic> json) {
    return VpnServer(
      id: json['id'] ?? json['uuid'] ?? '',
      name: json['name'] ?? '',
      country: json['country'] ?? '',
      countryCode: json['countryCode'] ?? json['country_code'] ?? '',
      host: json['host'] ?? '',
      port: json['port'] ?? 443,
      premium: json['premium'] ?? false,
      load: json['load'] ?? json['load_percentage'],
      vlessUrl: json['vlessUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'country': country,
      'country_code': countryCode,
      'host': host,
      'port': port,
      'premium': premium,
      'load': load,
      'vlessUrl': vlessUrl,
    };
  }

  @override
  String toString() {
    return 'VpnServer(id: $id, name: $name, country: $country, host: $host)';
  }

  VpnServer copyWith({
    String? id,
    String? name,
    String? country,
    String? countryCode,
    String? host,
    int? port,
    bool? premium,
    int? load,
    String? vlessUrl,
  }) {
    return VpnServer(
      id: id ?? this.id,
      name: name ?? this.name,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      host: host ?? this.host,
      port: port ?? this.port,
      premium: premium ?? this.premium,
      load: load ?? this.load,
      vlessUrl: vlessUrl ?? this.vlessUrl,
    );
  }
}
