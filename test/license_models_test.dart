import 'package:flutter_test/flutter_test.dart';
import 'package:netsource_opn_manager/core/licensing/license_models.dart';

void main() {
  test('free entitlement allows one firewall and enables ads', () {
    final entitlement = LicenseEntitlement.free();
    expect(entitlement.plan, LicensePlan.free);
    expect(entitlement.maxFirewalls, 1);
    expect(entitlement.isUsable, isTrue);
    expect(entitlement.adsEnabled, isTrue);
    expect(entitlement.isCommercial, isFalse);
    expect(entitlement.hasFeature('ad-supported'), isTrue);
  });

  test('commercial entitlement parses server payload and disables ads', () {
    final entitlement = LicenseEntitlement.fromJson({
      'plan': 'professional',
      'status': 'active',
      'max_firewalls': 5,
      'features': ['diagnostics', 'multi-firewall'],
      'license_id': 'lic_123',
      'lease_token': 'opaque-lease',
      'expires_at': '2099-08-12T00:00:00Z',
      'offline_until': '2099-08-19T00:00:00Z',
    });
    expect(entitlement.plan, LicensePlan.professional);
    expect(entitlement.maxFirewalls, 5);
    expect(entitlement.hasFeature('multi-firewall'), isTrue);
    expect(entitlement.leaseToken, 'opaque-lease');
    expect(entitlement.adsEnabled, isFalse);
    expect(entitlement.isCommercial, isTrue);
  });

  test('revoked entitlement is not usable and does not enable ads', () {
    final entitlement = LicenseEntitlement.fromJson({
      'plan': 'personal',
      'status': 'revoked',
      'max_firewalls': 1,
      'features': ['diagnostics'],
      'lease_token': 'revoked-token',
    });
    expect(entitlement.isUsable, isFalse);
    expect(entitlement.adsEnabled, isFalse);
    expect(entitlement.isCommercial, isFalse);
  });
}
