class FirewallProfile {
  const FirewallProfile({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.allowSelfSignedCertificate = false,
  });

  final String id;
  final String name;
  final String baseUrl;
  final bool allowSelfSignedCertificate;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'allowSelfSignedCertificate': allowSelfSignedCertificate,
      };

  factory FirewallProfile.fromJson(Map<String, Object?> json) {
    return FirewallProfile(
      id: json['id']! as String,
      name: json['name']! as String,
      baseUrl: json['baseUrl']! as String,
      allowSelfSignedCertificate:
          json['allowSelfSignedCertificate'] as bool? ?? false,
    );
  }
}

class FirewallCredentials {
  const FirewallCredentials({required this.apiKey, required this.apiSecret});

  final String apiKey;
  final String apiSecret;
}
