import '../../../core/api/opnsense_api_client.dart';
import 'alias_models.dart';

class AliasRepository {
  AliasRepository(this.api);
  final OpnSenseApiClient api;

  Future<List<FirewallAliasSummary>> load({String search = ''}) async {
    final raw = await api.getData(
      '/api/firewall/alias/searchItem',
      queryParameters: {
        'current': 1,
        'rowCount': 300,
        if (search.trim().isNotEmpty) 'searchPhrase': search.trim(),
      },
    );
    return parse(raw);
  }

  Future<void> setEnabled(FirewallAliasSummary alias, bool enabled) async {
    if (alias.uuid.isEmpty) throw StateError('Alias UUID is missing.');
    await api.postData('/api/firewall/alias/toggleItem/${Uri.encodeComponent(alias.uuid)}/${enabled ? 1 : 0}');
    await api.postData('/api/firewall/alias/reconfigure');
  }

  Future<void> delete(FirewallAliasSummary alias) async {
    if (alias.uuid.isEmpty) throw StateError('Alias UUID is missing.');
    await api.postData('/api/firewall/alias/delItem/${Uri.encodeComponent(alias.uuid)}');
    await api.postData('/api/firewall/alias/reconfigure');
  }

  static List<FirewallAliasSummary> parse(dynamic raw) {
    dynamic candidate = raw;
    if (raw is Map) candidate = raw['rows'] ?? raw['items'] ?? raw['aliases'] ?? raw;
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
    return rows.map((row) => FirewallAliasSummary(
      uuid: _text(row['uuid']),
      name: _first(row, const ['name', 'aliasname']),
      type: _first(row, const ['type']),
      content: _first(row, const ['content', 'address', 'addresses']),
      description: _first(row, const ['description', 'descr']),
      enabled: !_truthy(row['disabled']) && _truthy(row['enabled'], defaultValue: true),
    )).where((item) => item.name.isNotEmpty).toList();
  }

  static String _first(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final text = _text(row[key]);
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
