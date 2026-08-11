import '../../core/api/opnsense_api_client.dart';
import 'neighbor_models.dart';

class NeighborRepository {
  NeighborRepository(this.api);
  final OpnSenseApiClient api;

  Future<List<NeighborSummary>> load() async {
    final results = await Future.wait<dynamic>([
      api.getData('/api/diagnostics/interface/search_arp'),
      api.getData('/api/diagnostics/interface/search_ndp'),
    ]);
    return [
      ...parse(results[0], type: 'ARP'),
      ...parse(results[1], type: 'NDP'),
    ];
  }

  static List<NeighborSummary> parse(dynamic raw, {required String type}) {
    final rows = _rows(raw);
    return rows.map((row) => NeighborSummary(
      ip: _first(row, const ['ip', 'address', 'ip_address']),
      mac: _first(row, const ['mac', 'mac_address', 'lladdr']),
      hostname: _first(row, const ['hostname', 'host']),
      interfaceName: _first(row, const ['interface', 'if', 'interface_name']),
      status: _first(row, const ['status', 'state', 'expires']),
      type: type,
    )).where((item) => item.ip.isNotEmpty).toList();
  }

  static List<Map<String, dynamic>> _rows(dynamic raw) {
    dynamic candidate = raw;
    if (raw is Map) candidate = raw['rows'] ?? raw['items'] ?? raw['data'] ?? raw;
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
      if (value != null && value.toString().trim().isNotEmpty) return value.toString().trim();
    }
    return '';
  }
}
