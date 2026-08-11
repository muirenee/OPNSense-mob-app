import 'package:flutter_test/flutter_test.dart';
import 'package:netsource_opn_manager/features/firewall/states/firewall_state_repository.dart';

void main() {
  test('parses PF state rows', () {
    final states = FirewallStateRepository.parse({
      'rows': [
        {
          'id': '100',
          'interface': 'wan',
          'proto': 'tcp',
          'src': '10.0.0.5:50422',
          'dst': '1.1.1.1:443',
          'state': 'ESTABLISHED:ESTABLISHED',
        },
      ],
    });

    expect(states, hasLength(1));
    expect(states.first.protocol, 'tcp');
    expect(states.first.destination, contains('1.1.1.1'));
  });
}
