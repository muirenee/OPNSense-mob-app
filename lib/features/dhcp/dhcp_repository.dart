import '../../core/api/opnsense_api_client.dart';
import '../../core/api/opnsense_exception.dart';
import 'dhcp_models.dart';

class DhcpRepository {
  DhcpRepository(this.api);

  final OpnSenseApiClient api;

  Future<List<DhcpLeaseSummary>> loadLeases() async {
    final endpoints = <({String path, String source})>[
      (path: '/api/dnsmasq/leases/search', source: 'Dnsmasq'),
      (path: '/api/kea/leases4/search', source: 'Kea'),
      (path: '/api/kea/leases/search', source: 'Kea'),
      (path: '/api/dhcpv4/leases/searchLease', source: 'DHCPv4'),
      (path: '/api/dhcpv4/leases/search_lease', source: 'DHCPv4'),
    ];

    OpnSenseException? lastUnavailable;
    var sawSuccessfulEndpoint = false;
    for (final endpoint in endpoints) {
      try {
        final raw = await api.getData(endpoint.path);
        sawSuccessfulEndpoint = true;
        final leases = parseLeases(raw, source: endpoint.source);
        if (leases.isNotEmpty) return leases;
      } on OpnSenseException catch (error) {
        if (error.statusCode == 403 || error.statusCode == 404) {
          lastUnavailable = error;
          continue;
        }
        rethrow;
      }
    }
    if (!sawSuccessfulEndpoint && lastUnavailable != null) throw lastUnavailable;
    return <DhcpLeaseSummary>[];
  }

  static List<DhcpLeaseSummary> parseLeases(
    dynamic raw, {
    String source = '',
  }) {
    final rows = _rows(raw, const ['rows', 'leases', 'items', 'data']);
    return rows.map((row) {
      return DhcpLeaseSummary(
        ip: _first(row, const ['ip', 'address', 'ip-address', 'ip_address']),
        mac: _first(row, const ['mac', 'hwaddr', 'hw-address', 'mac-address', 'mac_address']),
        hostname: _first(row, const ['hostname', 'host', 'client-hostname']),
        interfaceName: _first(row, const ['interface', 'if', 'interface_name']),
        state: _first(row, const ['state', 'status', 'binding-state']),
        starts: _first(row, const ['starts', 'start', 'cltt']),
        ends: _first(row, const ['ends', 'end', 'expire', 'expiration']),
        source: source,
      );
    }).where((item) => item.ip.isNotEmpty).toList();
  }

  static List<Map<String, dynamic>> _rows(dynamic raw, List<String> keys) {
    dynamic candidate = raw;
    if (raw is Map) {
      for (final key in keys) {
        if (raw[key] != null) {
          candidate = raw[key];
          break;
        }
      }
    }
    final rows = <Map<String, dynamic>>[];
    if (candidate is List) {
      for (final item in candidate) {
        if (item is Map) rows.add(Map<String, dynamic>.from(item));
      }
    } else if (candidate is Map) {
      for (final entry in candidate.entries) {
        if (entry.value is Map) {
          final row = Map<String, dynamic>.from(entry.value as Map);
          row.putIfAbsent('ip', () => entry.key.toString());
          rows.add(row);
        }
      }
    }
    return rows;
  }

  static String _first(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }
}
