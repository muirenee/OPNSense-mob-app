enum LicensePlan { free, personal, professional, msp }

enum LicenseStatus { active, grace, expired, revoked }

class LicenseEntitlement {
  const LicenseEntitlement({
    required this.plan,
    required this.status,
    required this.maxFirewalls,
    required this.features,
    this.licenseId = '',
    this.expiresAt,
    this.offlineUntil,
    this.leaseToken = '',
  });

  final LicensePlan plan;
  final LicenseStatus status;
  final int maxFirewalls;
  final Set<String> features;
  final String licenseId;
  final DateTime? expiresAt;
  final DateTime? offlineUntil;
  final String leaseToken;

  factory LicenseEntitlement.free() => const LicenseEntitlement(
        plan: LicensePlan.free,
        status: LicenseStatus.active,
        maxFirewalls: 1,
        features: {
          'firewall-management',
          'network-management',
          'vpn-management',
          'diagnostics',
          'demo-mode',
        },
      );

  String get planLabel => switch (plan) {
        LicensePlan.free => 'Free',
        LicensePlan.personal => 'Personal',
        LicensePlan.professional => 'Professional',
        LicensePlan.msp => 'MSP',
      };

  bool get isUsable {
    if (status == LicenseStatus.revoked || status == LicenseStatus.expired) {
      return false;
    }
    final now = DateTime.now().toUtc();
    if (offlineUntil != null && now.isAfter(offlineUntil!.toUtc())) return false;
    if (expiresAt != null && now.isAfter(expiresAt!.toUtc())) return false;
    return true;
  }

  bool hasFeature(String feature) => features.contains(feature);

  Map<String, dynamic> toJson() => {
        'plan': plan.name,
        'status': status.name,
        'max_firewalls': maxFirewalls,
        'features': features.toList()..sort(),
        'license_id': licenseId,
        if (expiresAt != null) 'expires_at': expiresAt!.toUtc().toIso8601String(),
        if (offlineUntil != null)
          'offline_until': offlineUntil!.toUtc().toIso8601String(),
        'lease_token': leaseToken,
      };

  factory LicenseEntitlement.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features'];
    final features = <String>{};
    if (rawFeatures is Iterable) {
      features.addAll(
        rawFeatures.map((value) => value.toString().trim()).where((v) => v.isNotEmpty),
      );
    }
    return LicenseEntitlement(
      plan: LicensePlan.values.firstWhere(
        (value) => value.name == json['plan']?.toString().toLowerCase(),
        orElse: () => LicensePlan.free,
      ),
      status: LicenseStatus.values.firstWhere(
        (value) => value.name == json['status']?.toString().toLowerCase(),
        orElse: () => LicenseStatus.active,
      ),
      maxFirewalls: _int(json['max_firewalls'], fallback: 1),
      features: features.isEmpty ? LicenseEntitlement.free().features : features,
      licenseId: json['license_id']?.toString() ?? '',
      expiresAt: _date(json['expires_at']),
      offlineUntil: _date(json['offline_until']),
      leaseToken: json['lease_token']?.toString() ?? '',
    );
  }

  static int _int(dynamic value, {required int fallback}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static DateTime? _date(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return null;
    return DateTime.tryParse(value.toString())?.toUtc();
  }
}
