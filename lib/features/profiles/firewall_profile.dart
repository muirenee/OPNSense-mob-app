class FirewallProfile {
  const FirewallProfile({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.allowSelfSignedCertificate = false,
    this.isDemo = false,
  });

  static const FirewallProfile demo = FirewallProfile(
    id: '__demo__',
    name: 'Sentinel Demo',
    baseUrl: 'demo://local',
    isDemo: true,
  );

  final String id;
  final String name;
  final String baseUrl;
  final bool allowSelfSignedCertificate;
  final bool isDemo;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'allowSelfSignedCertificate': allowSelfSignedCertificate,
        'isDemo': isDemo,
      };

  factory FirewallProfile.fromJson(Map<String, Object?> json) {
    return FirewallProfile(
      id: json['id']! as String,
      name: json['name']! as String,
      baseUrl: json['baseUrl']! as String,
      allowSelfSignedCertificate:
          json['allowSelfSignedCertificate'] as bool? ?? false,
      isDemo: json['isDemo'] as bool? ?? false,
    );
  }
}

class FirewallCredentials {
  const FirewallCredentials({required this.apiKey, required this.apiSecret});

  static const FirewallCredentials demo = FirewallCredentials(
    apiKey: 'demo',
    apiSecret: 'demo',
  );

  final String apiKey;
  final String apiSecret;
}
