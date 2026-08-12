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

  test('parses KEA DHCP lease rows and recognizes state 0 as active', () {
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
          'expire': 1786554000,
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
    expect(leases.first.state, 'Assigned');
    expect(leases.first.isActive, isTrue);
    expect(
      leases.first.ends,
      matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$')),
    );
  });

  test('normalizes official KEA lease states', () {
    expect(DhcpRepository.normalizeKeaState(0), 'Assigned');
    expect(DhcpRepository.normalizeKeaState(1), 'Declined');
    expect(DhcpRepository.normalizeKeaState(2), 'Expired reclaimed');
    expect(DhcpRepository.normalizeKeaState(3), 'Released');
    expect(DhcpRepository.normalizeKeaState(4), 'Registered');
    expect(const DhcpLeaseSummary(ip: '192.0.2.2', state: '0').isActive, isTrue);
    expect(
      const DhcpLeaseSummary(ip: '192.0.2.3', state: 'Expired reclaimed')
          .isActive,
      isFalse,
    );
  });

  test('formats KEA unix expiry in local OPNsense-style format', () {
    final formatted = DhcpRepository.formatKeaTimestamp(1704067200);
    final local = DateTime.fromMillisecondsSinceEpoch(
      1704067200 * 1000,
      isUtc: true,
    ).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    final expected =
        '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
    expect(formatted, expected);
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
