import '../../../core/api/opnsense_api_client.dart';
import 'firewall_state_models.dart';

class FirewallStateRepository {
  FirewallStateRepository(this.api);
  final OpnSenseApiClient api;

  Future<List<FirewallStateSummary>> load() async {
    final raw = await api.getData('/api/diagnostics/firewall/pf_states');
    return parse(raw);
  }

  static List<FirewallStateSummary> parse(dynamic raw) {
    dynamic candidate = raw;
    if (raw is Map) candidate = raw['rows'] ?? raw['states'] ?? raw['items'] ?? raw['data'] ?? raw;
    final rows = <Map<String, dynamic>>[];
    if (candidate is List) {
      for (final item in candidate) {
        if (item is Map) rows.add(Map<String, dynamic>.from(item));
      }
    } else if (candidate is Map) {
      for (final entry in candidate.entries) {
        if (entry.value is Map) {
          final row = Map<String, dynamic>.from(entry.value as Map);
          row.putIfAbsent('id', () => entry.key.toString());
          rows.add(row);
        }
      }
    }
    return rows.map((row) => FirewallStateSummary(
      id: _first(row, const ['id', 'stateid', 'state_id']),
      creatorId: _first(row, const ['creatorid', 'creator_id']),
      interfaceName: _first(row, const ['interface', 'if', 'interface_name']),
      protocol: _first(row, const ['proto', 'protocol']),
      direction: _first(row, const ['direction', 'dir']),
      source: _first(row, const ['src', 'source', 'source_addr']),
      destination: _first(row, const ['dst', 'destination', 'destination_addr']),
      state: _first(row, const ['state', 'status']),
      age: _first(row, const ['age']),
      expires: _first(row, const ['expires', 'expire']),
      packets: _first(row, const ['packets', 'pkts']),
      bytes: _first(row, const ['bytes']),
    )).toList();
  }

  static String _first(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value == null) continue;
      if (value is Map || value is List) {
        final text = _flatten(value);
        if (text.isNotEmpty) return text;
      } else if (value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  static String _flatten(dynamic value) {
    if (value is List) return value.map(_flatten).where((e) => e.isNotEmpty).join(' / ');
    if (value is Map) return value.values.map(_flatten).where((e) => e.isNotEmpty).join(' / ');
    return value?.toString().trim() ?? '';
  }
}
