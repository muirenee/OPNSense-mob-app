import 'package:flutter_test/flutter_test.dart';
import 'package:netsource_opn_manager/features/dashboard/dashboard_repository.dart';

void main() {
  test('parses map-shaped interface response defensively', () {
    final result = DashboardRepository.parseInterfaces({
      'wan': {
        'description': 'WAN',
        'status': 'up',
        'ipaddr': '203.0.113.10',
      },
      'lan': {
        'description': 'LAN',
        'status': 'up',
        'ipaddr': '192.168.1.1',
      },
    });

    expect(result, hasLength(2));
    expect(result.first.identifier, 'wan');
    expect(result.first.addresses, contains('203.0.113.10'));
  });

  test('parses official OPNsense ipv4 and ipv6 interface entries', () {
    final result = DashboardRepository.parseInterfaces({
      'rows': [
        {
          'identifier': 'wan',
          'description': 'WAN',
          'status': 'up',
          'addr4': '203.0.113.18/30',
          'ipv4': [
            {'ipaddr': '203.0.113.18', 'subnetbits': 30},
          ],
          'ipv6': [
            {'ipaddr': '2001:db8::18', 'subnetbits': 64},
          ],
        },
      ],
    });

    expect(result, hasLength(1));
    expect(result.single.identifier, 'wan');
    expect(result.single.addresses, contains('203.0.113.18/30'));
    expect(result.single.addresses, contains('2001:db8::18/64'));
  });
}
