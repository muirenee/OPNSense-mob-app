import 'package:flutter_test/flutter_test.dart';
import 'package:netsource_opn_manager/features/firewall/firewall_repository.dart';

void main() {
  test('parses firewall automation rule summary', () {
    final rules = FirewallRepository.parseRules({
      'rows': [
        {
          'uuid': 'abc',
          'enabled': '1',
          'action': 'pass',
          'interface': 'lan',
          'protocol': 'TCP',
          'source_net': '192.168.1.0/24',
          'destination_net': '10.0.0.10',
          'destination_port': '443',
          'description': 'Allow app',
          'log': '1',
        },
      ],
    });

    expect(rules, hasLength(1));
    expect(rules.first.enabled, isTrue);
    expect(rules.first.logging, isTrue);
    expect(rules.first.destinationPort, '443');
  });
}
