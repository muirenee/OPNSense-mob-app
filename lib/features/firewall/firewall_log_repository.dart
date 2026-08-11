import '../../core/api/opnsense_api_client.dart';
import 'firewall_log_models.dart';

class FirewallLogRepository {
  FirewallLogRepository(this.api);

  final OpnSenseApiClient api;

  Future<List<FirewallLogEntry>> load() async {
    final raw = await api.getData('/api/diagnostics/firewall/log');
    return parse(raw);
  }

  static List<FirewallLogEntry> parse(dynamic raw) {
    dynamic candidate = raw;
    if (raw is Map) {
      candidate = raw['rows'] ?? raw['data'] ?? raw['log'] ?? raw['entries'] ?? raw;
    }

    final rows = <Map<String, dynamic>>[];
    if (candidate is List) {
      for (final item in candidate) {
        if (item is Map) rows.add(Map<String, dynamic>.from(item));
      }
    } else if (candidate is Map) {
      for (final entry in candidate.entries) {
        if (entry.value is Map) {
          rows.add(Map<String, dynamic>.from(entry.value as Map));
        }
      }
    }

    return rows.map((row) {
      return FirewallLogEntry(
        timestamp: _first(row, const [
          '__timestamp__',
          'timestamp',
          'time',
          'datetime',
        ]),
        action: _first(row, const ['action', 'act']),
        interfaceName: _first(row, const ['interface', 'if', 'interface_name']),
        protocol: _first(row, const ['protoname', 'protocol', 'proto']),
        source: _first(row, const ['src', 'source', 'source_address']),
        destination: _first(row, const ['dst', 'destination', 'destination_address']),
        sourcePort: _first(row, const ['srcport', 'source_port', 'sport']),
        destinationPort: _first(row, const ['dstport', 'destination_port', 'dport']),
        label: _first(row, const ['label', 'description', 'rule_label']),
        ruleId: _first(row, const ['rid', 'rulenr', 'rule_id']),
      );
    }).toList();
  }

  static String _first(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }
}
