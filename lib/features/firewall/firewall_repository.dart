import '../../core/api/opnsense_api_client.dart';
import '../../core/api/opnsense_exception.dart';
import 'firewall_models.dart';

class FirewallRepository {
  FirewallRepository(this.api);

  final OpnSenseApiClient api;

  Future<List<FirewallRuleSummary>> loadRules({String search = ''}) async {
    final raw = await api.getData(
      '/api/firewall/filter/searchRule',
      queryParameters: {
        'current': 1,
        'rowCount': 200,
        if (search.trim().isNotEmpty) 'searchPhrase': search.trim(),
      },
    );
    return parseRules(raw);
  }

  /// Toggle a Firewall Automation rule using OPNsense's rollback-safe flow:
  /// savepoint -> toggle -> apply with rollback revision -> connectivity test ->
  /// cancel rollback. If connectivity fails after apply, cancelRollback is not
  /// called and OPNsense can automatically revert the firewall component.
  Future<String> toggleRuleSafely({
    required FirewallRuleSummary rule,
    required bool enabled,
  }) async {
    if (rule.uuid.isEmpty) {
      throw StateError('The selected rule does not have a UUID.');
    }

    final savepoint = await api.postJson('/api/firewall/filter/savepoint');
    final revision = _first(savepoint, const ['revision', 'timestamp', 'id']);
    if (revision.isEmpty) {
      throw StateError('OPNsense did not return a rollback revision.');
    }

    await api.postData(
      '/api/firewall/filter/toggleRule/${Uri.encodeComponent(rule.uuid)}/${enabled ? 1 : 0}',
    );
    await api.postData(
      '/api/firewall/filter/apply/${Uri.encodeComponent(revision)}',
    );

    // Confirm that the same firewall API privilege used for the change is
    // still reachable before making the new rule state permanent. A failed
    // check intentionally leaves the rollback timer active.
    await api.getData(
      '/api/firewall/filter/searchRule',
      queryParameters: const {'current': 1, 'rowCount': 1},
    );
    try {
      await api.postData(
        '/api/firewall/filter/cancelRollback/${Uri.encodeComponent(revision)}',
      );
    } on OpnSenseException catch (error) {
      if (error.statusCode != 404) rethrow;
      await api.postData(
        '/api/firewall/filter/cancel_rollback/${Uri.encodeComponent(revision)}',
      );
    }
    return revision;
  }

  static List<FirewallRuleSummary> parseRules(dynamic raw) {
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

    return rows.map((row) {
      return FirewallRuleSummary(
        uuid: _display(row['uuid']),
        action: _first(row, const ['action', 'type']),
        interfaceName: _first(row, const ['interface', 'if', 'interfaces']),
        direction: _first(row, const ['direction']),
        protocol: _first(row, const ['protocol', 'ipprotocol']),
        source: _first(row, const ['source_net', 'source', 'src']),
        sourcePort: _first(row, const ['source_port', 'src_port']),
        destination: _first(row, const ['destination_net', 'destination', 'dst']),
        destinationPort: _first(row, const ['destination_port', 'dst_port']),
        description: _first(row, const ['description', 'descr', 'name']),
        enabled: _boolValue(row['enabled'], defaultValue: true) &&
            !_boolValue(row['disabled']),
        logging: _boolValue(row['log']) || _boolValue(row['logging']),
      );
    }).toList();
  }

  static String _first(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      final text = _display(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String _display(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is num || value is bool) return value.toString();
    if (value is List) {
      return value.map(_display).where((item) => item.isNotEmpty).join(', ');
    }
    if (value is Map) {
      for (final key in ['selected', 'value', 'name', 'label']) {
        if (value[key] != null) {
          final result = _display(value[key]);
          if (result.isNotEmpty) return result;
        }
      }
      final selected = <String>[];
      for (final entry in value.entries) {
        if (_boolValue(entry.value)) selected.add(entry.key.toString());
      }
      if (selected.isNotEmpty) return selected.join(', ');
    }
    return value.toString();
  }

  static bool _boolValue(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().trim().toLowerCase();
    if (const {'1', 'true', 'yes', 'on', 'enabled'}.contains(text)) return true;
    if (const {'0', 'false', 'no', 'off', 'disabled', ''}.contains(text)) {
      return false;
    }
    return defaultValue;
  }
}
