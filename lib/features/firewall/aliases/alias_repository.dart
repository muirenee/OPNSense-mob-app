import '../../../core/api/api_choice.dart';
import '../../../core/api/opnsense_api_client.dart';
import 'alias_models.dart';

class AliasRepository {
  AliasRepository(this.api);
  final OpnSenseApiClient api;

  Future<List<FirewallAliasSummary>> load({String search = ''}) async {
    final raw = await api.getData(
      '/api/firewall/alias/search_item',
      queryParameters: {
        'current': 1,
        'rowCount': 300,
        if (search.trim().isNotEmpty) 'searchPhrase': search.trim(),
      },
    );
    return parse(raw);
  }

  Future<Map<String, dynamic>> getItem(String uuid) async {
    final raw = await api.getData(
      '/api/firewall/alias/get_item/${Uri.encodeComponent(uuid)}',
    );
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final alias = map['alias'];
      if (alias is Map) return Map<String, dynamic>.from(alias);
      return map;
    }
    return <String, dynamic>{};
  }

  Future<void> save({String? uuid, required Map<String, dynamic> values}) async {
    final raw = await api.postData(
      uuid == null || uuid.isEmpty
          ? '/api/firewall/alias/add_item'
          : '/api/firewall/alias/set_item/${Uri.encodeComponent(uuid)}',
      data: {'alias': values},
    );
    _ensureSuccess(raw, 'Save alias');
    final applied = await api.postData('/api/firewall/alias/reconfigure');
    _ensureSuccess(applied, 'Reconfigure aliases');
  }

  Future<void> setEnabled(FirewallAliasSummary alias, bool enabled) async {
    if (alias.uuid.isEmpty) throw StateError('Alias UUID is missing.');
    final raw = await api.postData(
      '/api/firewall/alias/toggle_item/${Uri.encodeComponent(alias.uuid)}/${enabled ? 1 : 0}',
    );
    _ensureSuccess(raw, enabled ? 'Enable alias' : 'Disable alias');
    final applied = await api.postData('/api/firewall/alias/reconfigure');
    _ensureSuccess(applied, 'Reconfigure aliases');
  }

  Future<void> delete(FirewallAliasSummary alias) async {
    if (alias.uuid.isEmpty) throw StateError('Alias UUID is missing.');
    final raw = await api.postData(
      '/api/firewall/alias/del_item/${Uri.encodeComponent(alias.uuid)}',
    );
    _ensureSuccess(raw, 'Delete alias');
    final applied = await api.postData('/api/firewall/alias/reconfigure');
    _ensureSuccess(applied, 'Reconfigure aliases');
  }

  static List<FirewallAliasSummary> parse(dynamic raw) {
    dynamic candidate = raw;
    if (raw is Map) {
      candidate = raw['rows'] ?? raw['items'] ?? raw['aliases'] ?? raw;
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
          row.putIfAbsent('uuid', () => entry.key.toString());
          rows.add(row);
        }
      }
    }
    return rows
        .map(
          (row) => FirewallAliasSummary(
            uuid: _text(row['uuid']),
            name: _first(row, const ['name', 'aliasname']),
            type: _machineValue(row['type']),
            content: _first(row, const ['content', 'address', 'addresses']),
            description: _first(row, const ['description', 'descr']),
            enabled: !_truthy(row['disabled']) &&
                _truthy(row['enabled'], defaultValue: true),
          ),
        )
        .where((item) => item.name.isNotEmpty)
        .toList();
  }

  static String _first(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final text = _text(row[key]);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String _machineValue(dynamic value) {
    if (value is Map || value is Iterable) {
      final selected = parseApiChoices(value)
          .where((choice) => choice.selected)
          .toList();
      if (selected.length == 1) return selected.single.value;
      final display = apiChoiceDisplayText(value);
      if (display.isNotEmpty) return display;
    }
    return _text(value);
  }

  static String _text(dynamic value) {
    if (value == null) return '';
    if (value is String || value is num || value is bool) {
      return value.toString().trim();
    }
    if (value is List) {
      final selected = parseApiChoices(value)
          .where((choice) => choice.selected)
          .map((choice) => choice.value)
          .toList();
      if (selected.isNotEmpty) return selected.join(', ');
      return value.map(_text).where((e) => e.isNotEmpty).join(', ');
    }
    if (value is Map) {
      final selected = parseApiChoices(value)
          .where((choice) => choice.selected)
          .map((choice) => choice.value)
          .toList();
      if (selected.isNotEmpty) return selected.join(', ');
      for (final key in const ['value', 'name', 'label']) {
        final text = _text(value[key]);
        if (text.isNotEmpty) return text;
      }
      return '';
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

  static void _ensureSuccess(dynamic raw, String operation) {
    if (raw is! Map) return;
    final map = Map<String, dynamic>.from(raw);
    final result = map['result']?.toString().toLowerCase().trim();
    final status = map['status']?.toString().toLowerCase().trim();
    if (result == 'failed' || status == 'failed' || status == 'error') {
      final validation = map['validations'] ?? map['validation'];
      final detail = validation is Map
          ? validation.values
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .join(' · ')
          : (map['message'] ?? map['error'] ?? '').toString().trim();
      throw StateError(detail.isEmpty ? '$operation failed.' : '$operation failed: $detail');
    }
  }
}
