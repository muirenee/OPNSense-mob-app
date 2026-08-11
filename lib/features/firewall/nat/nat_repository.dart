import '../../../core/api/opnsense_api_client.dart';
import 'nat_models.dart';

class NatRepository {
  NatRepository(this.api);
  final OpnSenseApiClient api;

  Future<List<NatRuleSummary>> loadPortForwards() async {
    final raw = await api.getData('/api/firewall/d_nat/searchRule', queryParameters: const {'current': 1, 'rowCount': 300});
    return parse(raw, kind: NatRuleKind.portForward);
  }

  Future<List<NatRuleSummary>> loadOutbound() async {
    final raw = await api.getData('/api/firewall/source_nat/searchRule', queryParameters: const {'current': 1, 'rowCount': 300});
    return parse(raw, kind: NatRuleKind.outbound);
  }

  static List<NatRuleSummary> parse(dynamic raw, {required NatRuleKind kind}) {
    dynamic candidate = raw;
    if (raw is Map) candidate = raw['rows'] ?? raw['rules'] ?? raw['items'] ?? raw;
    final rows = <Map<String, dynamic>>[];
    if (candidate is List) {
      for (final item in candidate) {
        if (item is Map) rows.add(Map<String, dynamic>.from(item));
      }
    } else if (candidate is Map) {
      for (final entry in candidate.entries) {
        if (entry.value is Map) {
          final row = Map<String, dynamic>.from(entry.value as Map);
          row.putIfAbsent('uuid', () => entry.key.toString());
          rows.add(row);
        }
      }
    }
    return rows.map((row) => NatRuleSummary(
      uuid: _first(row, const ['uuid']),
      kind: kind,
      interfaceName: _first(row, const ['interface', 'interfaces', 'if']),
      protocol: _first(row, const ['protocol']),
      source: _first(row, const ['source_net', 'source', 'src']),
      sourcePort: _first(row, const ['source_port', 'src_port']),
      destination: _first(row, const ['destination_net', 'destination', 'dst']),
      destinationPort: _first(row, const ['destination_port', 'dst_port']),
      target: _first(row, const ['target', 'target_ip', 'translation', 'nat_target']),
      targetPort: _first(row, const ['target_port', 'local_port', 'nat_port']),
      description: _first(row, const ['description', 'descr', 'name']),
      enabled: !_truthy(row['disabled']) && _truthy(row['enabled'], defaultValue: true),
    )).toList();
  }

  static String _first(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      final text = _text(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String _text(dynamic value) {
    if (value == null) return '';
    if (value is List) return value.map(_text).where((e) => e.isNotEmpty).join(', ');
    if (value is Map) {
      for (final key in ['selected', 'value', 'name', 'label']) {
        final text = _text(value[key]);
        if (text.isNotEmpty) return text;
      }
    }
    return value.toString().trim();
  }

  static bool _truthy(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().toLowerCase().trim();
    if (['1', 'true', 'yes', 'on', 'enabled'].contains(text)) return true;
    if (['0', 'false', 'no', 'off', 'disabled'].contains(text)) return false;
    return defaultValue;
  }
}
