import 'package:flutter_test/flutter_test.dart';
import 'package:netsource_opn_manager/features/dhcp/dhcp_models.dart';
import 'package:netsource_opn_manager/features/dhcp/dhcp_repository.dart';

void main() {
  test('uses the concrete KEA IPv4 leases controller', () {
    expect(DhcpRepository.leases4Path, '/api/kea/leases4/search');
    expect(
      DhcpRepository.deleteLease4Path,
      '/api/kea/leases4/del_lease',
    );
    expect(DhcpRepository.leases4Path, isNot('/api/kea/leases/search'));
  });

  test('parses KEA DHCP lease rows', () {
    final leases = DhcpRepository.parseLeases({
      'rows': [
        {
          'address': '192.168.1.20',
          'hwaddr': '00:11:22:33:44:55',
          'hostname': 'phone',
          'if_name': 'lan',
          'if_descr': 'LAN',
          'state': 0,
          'client_id': '01:00:11:22:33:44:55',
          'subnet_id': 4,
        },
      ],
    });

    expect(leases, hasLength(1));
    expect(leases.first.ip, '192.168.1.20');
    expect(leases.first.hostname, 'phone');
    expect(leases.first.source, 'Kea IPv4');
    expect(leases.first.clientId, '01:00:11:22:33:44:55');
    expect(leases.first.subnetId, '4');
    expect(leases.first.interfaceName, 'lan');
  });

  test('parses KEA subnets and reservations', () {
    final subnets = DhcpRepository.parseSubnets({
      'rows': [
        {
          'uuid': 'subnet-1',
          'subnet': '192.168.10.0/24',
          'description': 'LAN',
          'subnet_id': 10,
        },
      ],
    });
    final reservations = DhcpRepository.parseReservations(
      {
        'rows': [
          {
            'uuid': 'reservation-1',
            'subnet': 'subnet-1',
            'ip_address': '192.168.10.50',
            'hw_address': 'aa:bb:cc:dd:ee:ff',
            'hostname': 'printer',
            'description': 'Office printer',
          },
        ],
      },
      subnets: subnets,
    );

    expect(subnets, hasLength(1));
    expect(subnets.first.label, '192.168.10.0/24 · LAN');
    expect(reservations, hasLength(1));
    expect(reservations.first.subnetUuid, 'subnet-1');
    expect(reservations.first.subnetLabel, '192.168.10.0/24 · LAN');
    expect(reservations.first.hostname, 'printer');
  });

  test('matches a reservation to its KEA lease', () {
    const lease = DhcpLeaseSummary(
      ip: '192.168.10.50',
      mac: 'AA:BB:CC:DD:EE:FF',
    );
    const reservation = KeaReservationSummary(
      uuid: 'reservation-1',
      subnetUuid: 'subnet-1',
      ip: '192.168.10.50',
      mac: 'aa:bb:cc:dd:ee:ff',
    );

    expect(reservation.matchesLease(lease), isTrue);
  });
}
