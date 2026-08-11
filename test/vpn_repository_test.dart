import 'package:flutter_test/flutter_test.dart';
import 'package:netsource_opn_manager/features/vpn/vpn_models.dart';
import 'package:netsource_opn_manager/features/vpn/vpn_repository.dart';

void main() {
  test('parses WireGuard service status', () {
    final status = VpnRepository.parseServiceStatus(
      VpnKind.wireGuard,
      'WireGuard',
      {'status': 'running'},
    );
    expect(status.isRunning, isTrue);
    expect(status.label, 'WireGuard');
  });

  test('parses OpenVPN session rows defensively', () {
    final sessions = VpnRepository.parseSessions(VpnKind.openVpn, {
      'rows': [
        {
          'id': 'session-1',
          'common_name': 'roadwarrior',
          'status': 'connected',
          'real_address': '203.0.113.10:55123',
          'virtual_address': '10.8.0.10',
        },
      ],
    });
    expect(sessions, hasLength(1));
    expect(sessions.first.name, 'roadwarrior');
    expect(sessions.first.isConnected, isTrue);
    expect(sessions.first.virtualAddress, '10.8.0.10');
  });
}
