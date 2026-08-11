import 'package:flutter_test/flutter_test.dart';
import 'package:netsource_opn_manager/features/captive_portal/captive_portal_repository.dart';

void main() {
  test('parses captive portal zones', () {
    final zones = CaptivePortalRepository.parseZones({
      'rows': [
        {
          'uuid': 'z1',
          'zoneid': '1',
          'description': 'Guest WiFi',
          'interfaces': ['lan'],
          'enabled': '1',
          'idletimeout': '30',
          'hardtimeout': '480',
        },
      ],
    });

    expect(zones.single.description, 'Guest WiFi');
    expect(zones.single.enabled, isTrue);
    expect(zones.single.interfaces, contains('lan'));
  });

  test('parses captive portal sessions', () {
    final sessions = CaptivePortalRepository.parseSessions({
      'rows': [
        {
          'sessionId': 'abc123',
          'userName': 'guest1',
          'ipAddress': '192.168.1.50',
          'macAddress': '00:11:22:33:44:55',
          'zoneid': '1',
        },
      ],
    });

    expect(sessions.single.sessionId, 'abc123');
    expect(sessions.single.username, 'guest1');
    expect(sessions.single.ip, '192.168.1.50');
  });

  test('parses generated vouchers', () {
    final vouchers = CaptivePortalRepository.parseVouchers({
      'rows': [
        {'username': 'VOUCHER1', 'password': 'PASS1', 'validity': '60'},
      ],
    });

    expect(vouchers.single.username, 'VOUCHER1');
    expect(vouchers.single.password, 'PASS1');
  });
}
