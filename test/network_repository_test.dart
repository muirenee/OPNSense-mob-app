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

  test('parses interface byte counters', () {
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
