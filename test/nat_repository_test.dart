import 'package:flutter_test/flutter_test.dart';
import 'package:netsource_opn_manager/features/firewall/nat/nat_models.dart';
import 'package:netsource_opn_manager/features/firewall/nat/nat_repository.dart';

void main() {
  test('parses destination NAT port forward', () {
    final rules = NatRepository.parse({
      'rows': [
        {
          'uuid': 'nat-1',
          'interface': 'wan',
          'protocol': 'TCP',
          'destination_net': 'wanip',
          'destination_port': '443',
          'target': '10.0.0.20',
          'target_port': '8443',
          'description': 'Portal',
        },
      ],
    }, kind: NatRuleKind.portForward);

    expect(rules, hasLength(1));
    expect(rules.first.destinationPort, '443');
    expect(rules.first.target, '10.0.0.20');
    expect(rules.first.kind, NatRuleKind.portForward);
  });
}
