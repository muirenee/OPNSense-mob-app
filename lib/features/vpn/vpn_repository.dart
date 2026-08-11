import '../../core/api/opnsense_api_client.dart';
import 'vpn_models.dart';

class VpnRepository {
  VpnRepository(this.api);

  final OpnSenseApiClient api;

  Future<VpnServiceStatus> loadWireGuardStatus() async {
    final raw = await api.getData('/api/wireguard/service/status');
    return parseServiceStatus(VpnKind.wireGuard, 'WireGuard', raw);
  }

  Future<VpnServiceStatus> loadIpsecStatus() async {
    final raw = await api.getData('/api/ipsec/service/status');
    return parseServiceStatus(VpnKind.ipsec, 'IPsec', raw);
  }

  Future<List<VpnSession>> loadWireGuardSessions() async {
    final raw = await api.getData('/api/wireguard/service/show');
    return parseSessions(VpnKind.wireGuard, raw);
  }

  Future<List<VpnSession>> loadOpenVpnSessions() async {
    final raw = await api.getData('/api/openvpn/service/search_sessions');
    return parseSessions(VpnKind.openVpn, raw);
  }

  Future<List<VpnSession>> loadIpsecSessions() async {
    final phase1 = await api.getData('/api/ipsec/sessions/search_phase1');
    return parseSessions(VpnKind.ipsec, phase1);
  }

  Future<void> performServiceAction(
    VpnKind kind,
    VpnServiceAction action,
  ) async {
    final command = switch (action) {
      VpnServiceAction.start => 'start',
      VpnServiceAction.stop => 'stop',
      VpnServiceAction.restart => 'restart',
    };
    final module = switch (kind) {
      VpnKind.wireGuard => 'wireguard',
      VpnKind.ipsec => 'ipsec',
      VpnKind.openVpn => 'openvpn',
    };
    if (kind == VpnKind.openVpn) {
      final openVpnCommand = switch (action) {
        VpnServiceAction.start => 'start_service',
        VpnServiceAction.stop => 'stop_service',
        VpnServiceAction.restart => 'restart_service',
      };
      await api.postData('/api/openvpn/service/$openVpnCommand');
      return;
    }
    await api.postData('/api/$module/service/$command');
  }

  static VpnServiceStatus parseServiceStatus(
    VpnKind kind,
    String label,
    dynamic raw,
  ) {
    final map = _asMap(raw);
    final status = _firstString(map, const [
      'status',
      'state',
      'running',
      'result',
      'status_translated',
    ]);
    return VpnServiceStatus(
      kind: kind,
      label: label,
      status: status.isEmpty ? _stringifyScalar(raw) : status,
      message: _firstString(map, const ['message', 'output', 'response']),
    );
  }

  static List<VpnSession> parseSessions(VpnKind kind, dynamic raw) {
    final rows = _extractRows(raw);
    return rows.map((row) {
      final id = _firstString(row, const [
        'id', 'uuid', 'session_id', 'peer_id', 'ikeid', 'instance', 'name'
      ]);
      final name = _firstString(row, const [
        'name', 'common_name', 'description', 'descr', 'peer', 'instance',
        'local-id', 'remote-id', 'identifier'
      ]);
      final status = _firstString(row, const [
        'status', 'state', 'connected', 'established', 'online', 'enabled'
      ]);
      final remote = _firstString(row, const [
        'remote', 'remote_host', 'real_address', 'endpoint', 'remote-host',
        'remote_address'
      ]);
      final virtualAddress = _firstString(row, const [
        'virtual_address', 'virtual_addr', 'tunnel_address', 'address',
        'allowed_ips', 'allowed-ips'
      ]);
      final connectedSince = _firstString(row, const [
        'connected_since', 'connected_time', 'since', 'established',
        'latest_handshake', 'latest-handshake'
      ]);
      final bytesIn = _firstString(row, const [
        'bytes_received', 'bytes_in', 'received', 'transfer_rx', 'rx'
      ]);
      final bytesOut = _firstString(row, const [
        'bytes_sent', 'bytes_out', 'sent', 'transfer_tx', 'tx'
      ]);
      return VpnSession(
        kind: kind,
        id: id,
        name: name.isEmpty ? (id.isEmpty ? _fallbackName(kind) : id) : name,
        status: status.isEmpty ? 'Unknown' : status,
        remote: remote,
        virtualAddress: virtualAddress,
        connectedSince: connectedSince,
        bytesIn: bytesIn,
        bytesOut: bytesOut,
        details: _compactDetails(row),
      );
    }).toList();
  }

  static String _fallbackName(VpnKind kind) => switch (kind) {
        VpnKind.wireGuard => 'WireGuard peer',
        VpnKind.openVpn => 'OpenVPN session',
        VpnKind.ipsec => 'IPsec tunnel',
      };

  static Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  static String _stringifyScalar(dynamic raw) {
    if (raw == null) return 'Unknown';
    if (raw is String || raw is num || raw is bool) return raw.toString();
    return 'Unknown';
  }

  static List<Map<String, dynamic>> _extractRows(dynamic raw) {
    dynamic candidate = raw;
    if (raw is Map) {
      candidate = raw['rows'] ??
          raw['items'] ??
          raw['sessions'] ??
          raw['peers'] ??
          raw['phase1'] ??
          raw['data'] ??
          raw;
    }
    final output = <Map<String, dynamic>>[];
    if (candidate is List) {
      for (final item in candidate) {
        if (item is Map) output.add(Map<String, dynamic>.from(item));
      }
      return output;
    }
    if (candidate is Map) {
      for (final entry in candidate.entries) {
        if (entry.value is Map) {
          final row = Map<String, dynamic>.from(entry.value as Map);
          row.putIfAbsent('name', () => entry.key.toString());
          output.add(row);
        } else if (entry.value is List) {
          for (final item in entry.value as List) {
            if (item is Map) output.add(Map<String, dynamic>.from(item));
          }
        }
      }
    }
    return output;
  }

  static String _firstString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  static String _compactDetails(Map<String, dynamic> row) {
    const preferred = [
      'interface', 'local', 'remote', 'protocol', 'cipher', 'type', 'role'
    ];
    final parts = <String>[];
    for (final key in preferred) {
      final value = row[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        parts.add('$key: ${value.toString().trim()}');
      }
    }
    return parts.join(' · ');
  }
}
