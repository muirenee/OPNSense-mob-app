import 'package:flutter_test/flutter_test.dart';
import 'package:netsource_opn_manager/features/firewall/firewall_reference_repository.dart';

void main() {
  test('parses OPNsense network selector groups', () {
    final choices = FirewallReferenceRepository.parseSelectOptions(
      {
        'single': {'label': 'Single host or Network'},
        'networks': {
          'label': 'Networks',
          'items': {
            'any': 'any',
            '(self)': 'This Firewall',
            'wan': 'WAN network',
            'wanip': 'WAN address',
          },
        },
        'aliases': {
          'label': 'Aliases',
          'items': {'WebServers': 'WebServers'},
        },
      },
      groups: const ['networks', 'aliases'],
    );

    expect(choices.map((choice) => choice.value), contains('wanip'));
    expect(choices.map((choice) => choice.value), contains('WebServers'));
  });

  test('parses OPNsense port selector including blank any value', () {
    final choices = FirewallReferenceRepository.parseSelectOptions(
      {
        'ports': {
          'label': 'Ports',
          'items': {'': 'any', 'https': 'HTTPS (443)'},
        },
        'aliases': {
          'label': 'Aliases',
          'items': {'SIP_PORTS': 'SIP_PORTS'},
        },
      },
      groups: const ['ports', 'aliases'],
    );

    expect(choices.any((choice) => choice.value.isEmpty), isTrue);
    expect(choices.any((choice) => choice.value == 'https'), isTrue);
    expect(choices.any((choice) => choice.value == 'SIP_PORTS'), isTrue);
  });
}
