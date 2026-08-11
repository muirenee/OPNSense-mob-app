import 'package:flutter_test/flutter_test.dart';
import 'package:netsource_opn_manager/features/firewall/firewall_log_repository.dart';

void main() {
  test('parses firewall log entry', () {
    final entries = FirewallLogRepository.parse({
      'rows': [
        {
          '__timestamp__': '2026-08-11T07:30:00+02:00',
          'action': 'block',
          'interface': 'wan',
          'protoname': 'tcp',
          'src': '203.0.113.20',
          'srcport': '45123',
          'dst': '192.0.2.10',
          'dstport': '443',
          'label': 'Default deny',
        }
      ],
    });

    expect(entries, hasLength(1));
    expect(entries.first.action, 'block');
    expect(entries.first.destinationPort, '443');
  });
}
