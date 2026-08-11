import 'package:flutter_test/flutter_test.dart';
import 'package:netsource_opn_manager/features/dhcp/dhcp_repository.dart';

void main() {
  test('parses DHCP lease rows', () {
    final leases = DhcpRepository.parseLeases({
      'rows': [
        {
          'ip': '192.168.1.20',
          'mac': '00:11:22:33:44:55',
          'hostname': 'phone',
          'interface': 'lan',
          'state': 'active',
        },
      ],
    }, source: 'Dnsmasq');

    expect(leases, hasLength(1));
    expect(leases.first.ip, '192.168.1.20');
    expect(leases.first.hostname, 'phone');
    expect(leases.first.source, 'Dnsmasq');
  });
}
