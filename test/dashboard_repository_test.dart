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
}
