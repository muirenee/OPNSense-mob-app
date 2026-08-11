import 'package:flutter_test/flutter_test.dart';
import 'package:netsource_opn_manager/features/captive_portal/captive_portal_repository.dart';

void main() {
  test('parses captive portal zones with human option labels', () {
    final zones = CaptivePortalRepository.parseZones({
      'rows': [
        {
          'uuid': 'z1',
          'zoneid': '1',
          'description': 'Guest WiFi',
          'interfaces': {
            'lan': {'value': 'LAN', 'selected': 1},
            'wan': {'value': 'WAN', 'selected': 0},
          },
          'authservers': {
            'local': {'value': 'Local Database', 'selected': 1},
            'radius': {'value': 'RADIUS', 'selected': 0},
          },
          'enabled': '1',
          'idletimeout': '30',
          'hardtimeout': '480',
        },
      ],
    });

    expect(zones.single.description, 'Guest WiFi');
    expect(zones.single.enabled, isTrue);
    expect(zones.single.interfaces, 'LAN');
    expect(zones.single.authServers, 'Local Database');
    expect(zones.single.interfaces, isNot(contains('{')));
  });

  test('extracts portal field choices and selected values', () {
    final model = <String, dynamic>{
      'interfaces': {
        'lan': {'value': 'LAN', 'selected': 1},
        'guest': {'value': 'Guest VLAN', 'selected': 0},
      },
    };
    final choices = CaptivePortalRepository.choices(model, 'interfaces');
    expect(choices, hasLength(2));
    expect(
      choices.singleWhere((choice) => choice.value == 'guest').label,
      'Guest VLAN',
    );
    expect(
      CaptivePortalRepository.selectedChoices(model, 'interfaces'),
      {'lan'},
    );
  });

  test('normalizes voucher provider map without JSON strings', () {
    final providers = CaptivePortalRepository.stringList({
      'providers': {
        'radius1': {'value': 'Hotel Vouchers', 'selected': 0},
        'local': {'value': 'Local Database', 'selected': 0},
      },
    }, preferredContainers: const ['providers']);

    expect(providers, contains('Hotel Vouchers'));
    expect(providers, contains('Local Database'));
    expect(providers.join(' '), isNot(contains('{')));
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
