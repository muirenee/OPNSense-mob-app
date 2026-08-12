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

  test('normalizes OPNsense case-sensitive filter protocols', () {
    expect(FirewallRepository.normalizeProtocol('tcp'), 'TCP');
    expect(FirewallRepository.normalizeProtocol('UDP'), 'UDP');
    expect(FirewallRepository.normalizeProtocol('tcp/udp'), 'TCP/UDP');
    expect(FirewallRepository.normalizeProtocol('icmp'), 'ICMP');
    expect(FirewallRepository.normalizeProtocol('icmp6'), 'IPV6-ICMP');
    expect(FirewallRepository.normalizeProtocol('any'), 'any');
  });

  test('only TCP and UDP filter protocols accept port fields', () {
    expect(FirewallRepository.protocolSupportsPorts('TCP'), isTrue);
    expect(FirewallRepository.protocolSupportsPorts('udp'), isTrue);
    expect(FirewallRepository.protocolSupportsPorts('TCP/UDP'), isTrue);
    expect(FirewallRepository.protocolSupportsPorts('ICMP'), isFalse);
    expect(FirewallRepository.protocolSupportsPorts('any'), isFalse);
  });

  test('normalizes friendly any port to OPNsense blank PortField value', () {
    expect(FirewallRepository.normalizePort('any'), '');
    expect(FirewallRepository.normalizePort(' ANY '), '');
    expect(FirewallRepository.normalizePort('443'), '443');
    expect(FirewallRepository.normalizePort('10000-20000'), '10000-20000');
  });
}
