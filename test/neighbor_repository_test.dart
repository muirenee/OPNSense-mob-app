import 'package:flutter_test/flutter_test.dart';
import 'package:netsource_opn_manager/features/neighbors/neighbor_repository.dart';

void main() {
  test('parses ARP neighbor rows', () {
    final neighbors = NeighborRepository.parse({
      'rows': [
        {
          'ip': '10.0.0.5',
          'mac': 'aa:bb:cc:dd:ee:ff',
          'hostname': 'printer',
          'interface': 'lan',
        },
      ],
    }, type: 'ARP');

    expect(neighbors, hasLength(1));
    expect(neighbors.first.type, 'ARP');
    expect(neighbors.first.hostname, 'printer');
  });
}
