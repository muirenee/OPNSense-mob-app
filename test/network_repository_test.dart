import 'package:flutter_test/flutter_test.dart';
import 'package:netsource_opn_manager/features/network/network_repository.dart';

void main() {
  test('parses gateway status rows defensively', () {
    final gateways = NetworkRepository.parseGateways({
      'items': [
        {
          'name': 'MTNMain',
          'status': 'Online',
          'delay': '18.2ms',
          'loss': '0.0%',
          'monitor': '8.8.8.8',
        },
      ],
    });

    expect(gateways, hasLength(1));
    expect(gateways.first.name, 'MTNMain');
    expect(gateways.first.isOnline, isTrue);
    expect(gateways.first.loss, '0.0%');
  });

  test('parses official OPNsense traffic counters by logical interface id', () {
    final stats = NetworkRepository.parseInterfaceStatistics({
      'time': 1786550000.25,
      'interfaces': {
        'wan': {
          'name': 'MTN Main',
          'bytes received': '1,000',
          'bytes transmitted': 2500,
          'packets received': 100,
          'packets transmitted': 90,
          'input errors': 2,
          'output errors': 1,
        },
      },
    });

    expect(stats.keys, contains('wan'));
    expect(stats.containsKey('MTN Main'), isFalse);
    expect(stats['wan']?['rxBytes'], 1000);
    expect(stats['wan']?['txBytes'], 2500);
    expect(stats['wan']?['rxPackets'], 100);
    expect(stats['wan']?['txPackets'], 90);
    expect(stats['wan']?['inputErrors'], 2);
    expect(stats['wan']?['outputErrors'], 1);
  });

  test('parses legacy interface byte counter names defensively', () {
    final stats = NetworkRepository.parseInterfaceStatistics({
      'em0': {
        'bytes received': '1,000',
        'bytes sent': 2500,
        'input errors': 2,
      },
    });

    expect(stats['em0']?['rxBytes'], 1000);
    expect(stats['em0']?['txBytes'], 2500);
    expect(stats['em0']?['inputErrors'], 2);
  });
}
