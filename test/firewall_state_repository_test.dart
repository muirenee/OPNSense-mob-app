import 'package:flutter_test/flutter_test.dart';
import 'package:netsource_opn_manager/features/firewall/states/firewall_state_repository.dart';

void main() {
  test('uses the detailed OPNsense query_states endpoint', () {
    expect(
      FirewallStateRepository.queryStatesPath,
      '/api/diagnostics/firewall/query_states',
    );
  });

  test('parses official PF query_states rows', () {
    final states = FirewallStateRepository.parse({
      'rows': [
        {
          'id': '100',
          'creatorid': 'abcd1234',
          'interface': 'WAN',
          'iface': 'pppoe0',
          'direction': 'in',
          'proto': 'tcp',
          'src_addr': '10.0.0.5',
          'src_port': '50422',
          'dst_addr': '1.1.1.1',
          'dst_port': '443',
          'state': 'ESTABLISHED:ESTABLISHED',
        },
      ],
      'total': 1,
    });

    expect(states, hasLength(1));
    expect(states.first.protocol, 'tcp');
    expect(states.first.interfaceName, 'WAN');
    expect(states.first.direction, 'in');
    expect(states.first.source, '10.0.0.5:50422');
    expect(states.first.destination, '1.1.1.1:443');
    expect(states.first.creatorId, 'abcd1234');
  });

  test('formats IPv6 state endpoints with brackets', () {
    final states = FirewallStateRepository.parse({
      'rows': [
        {
          'id': '200',
          'proto': 'tcp',
          'src_addr': '2001:db8::10',
          'src_port': '1234',
          'dst_addr': '2001:4860:4860::8888',
          'dst_port': '443',
        },
      ],
    });

    expect(states.single.source, '[2001:db8::10]:1234');
    expect(states.single.destination, '[2001:4860:4860::8888]:443');
  });
}
