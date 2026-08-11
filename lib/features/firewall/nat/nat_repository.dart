import '../../../core/api/api_choice.dart';
import '../../../core/api/opnsense_api_client.dart';
import '../../../core/api/opnsense_exception.dart';
import 'nat_models.dart';

class NatRepository {
  NatRepository(this.api);
  final OpnSenseApiClient api;

  Future<List<NatRuleSummary>> loadPortForwards() async {
    final raw = await api.getData(
      '/api/firewall/d_nat/searchRule',
      queryParameters: const {'current': 1, 'rowCount': 300},
    );
    return parse(raw, kind: NatRuleKind.portForward);
  }

  Future<List<NatRuleSummary>> loadOutbound() async {
    final raw = await api.getData(
      '/api/firewall/source_nat/searchRule',
      queryParameters: const {'current': 1, 'rowCount': 300},
    );
    return parse(raw, kind: NatRuleKind.outbound);
  }

  Future<Map<String, dynamic>> getRule(NatRuleSummary rule) {
    return getRuleModel(kind: rule.kind, uuid: rule.uuid);
  }

  Future<Map<String, dynamic>> getDefaultRule(NatRuleKind kind) {
    return getRuleModel(kind: kind);
  }

  Future<Map<String, dynamic>> getRuleModel({
    required NatRuleKind kind,
    String? uuid,
  }) async {
    final controller = _controller(kind);
    final suffix = uuid == null || uuid.isEmpty
        ? ''
        : '/${Uri.encodeComponent(uuid)}';
    final raw = await api.getData('/api/firewall/$controller/getRule$suffix');
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final model = map['rule'];
      if (model is Map) return Map<String, dynamic>.from(model);
      return map;
    }
    return <String, dynamic>{};
  }

  Future<String> saveRuleSafely({
    required NatRuleKind kind,
    String? uuid,
    required Map<String, dynamic> values,
  }) async {
    final controller = _controller(kind);
    return _changeSafelyController(
      controller: controller,
      change: () => api.postData(
        uuid == null || uuid.isEmpty
            ? '/api/firewall/$controller/addRule'
            : '/api/firewall/$controller/setRule/${Uri.encodeComponent(uuid)}',
        data: {'rule': values},
      ),
    );
  }

  Future<String> setEnabledSafely(NatRuleSummary rule, bool enabled) async {
    final controller = _controller(rule.kind);
    return _changeSafelyController(
      controller: controller,
      change: () => api.postData(
        '/api/firewall/$controller/toggleRule/${Uri.encodeComponent(rule.uuid)}/${enabled ? 0 : 1}',
      ),
    );
  }

  Future<String> deleteSafely(NatRuleSummary rule) async {
    final controller = _controller(rule.kind);
    return _changeSafelyController(
      controller: controller,
      change: () => api.postData(
        '/api/firewall/$controller/delRule/${Uri.encodeComponent(rule.uuid)}',
      ),
    );
  }

  Future<String> _changeSafelyController({
    required String controller,
    required Future<dynamic> Function() change,
  }) async {
    final savepoint = await api.postJson('/api/firewall/$controller/savepoint');
    final revision = _first(savepoint, const ['revision', 'timestamp', 'id']);
    if (revision.isEmpty) {
      throw StateError('The firewall did not return a rollback revision.');
    }

    await change();
    await api.postData(
      '/api/firewall/$controller/apply/${Uri.encodeComponent(revision)}',
    );

    await api.getData(
      '/api/firewall/$controller/searchRule',
      queryParameters: const {'current': 1, 'rowCount': 1},
    );

    try {
      await api.postData(
        '/api/firewall/$controller/cancelRollback/${Uri.encodeComponent(revision)}',
      );
    } on OpnSenseException catch (error) {
      if (error.statusCode != 404) rethrow;
      await api.postData(
        '/api/firewall/$controller/cancel_rollback/${Uri.encodeComponent(revision)}',
      );
    }
    return revision;
  }

  static List<ApiChoice> choices(Map<String, dynamic> model, String field) =>
      parseApiChoices(model[field], scalarValuesSelected: false);

  static Set<String> selectedChoices(
    Map<String, dynamic> model,
    String field,
  ) =>
      parseApiChoices(model[field])
          .where((choice) => choice.selected)
          .map((choice) => choice.value)
          .toSet();

  static String _controller(NatRuleKind kind) =>
      kind == NatRuleKind.portForward ? 'd_nat' : 'source_nat';

  static List<NatRuleSummary> parse(dynamic raw, {required NatRuleKind kind}) {
    dynamic candidate = raw;
    if (raw is Map) {
      candidate = raw['rows'] ?? raw['rules'] ?? raw['items'] ?? raw;
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
          (row) => NatRuleSummary(
            uuid: _first(row, const ['uuid']),
            kind: kind,
            interfaceName: _first(
              row,
              const ['interface', 'interfaces', 'if'],
            ),
            protocol: _first(row, const ['protocol']),
            source: _first(
              row,
              const ['source_net', 'source', 'src', 'source.network'],
            ),
            sourcePort: _first(
              row,
              const ['source_port', 'src_port', 'source.port'],
            ),
            destination: _first(
              row,
              const [
                'destination_net',
                'destination',
                'dst',
                'destination.network',
              ],
            ),
            destinationPort: _first(
              row,
              const ['destination_port', 'dst_port', 'destination.port'],
            ),
            target: _first(
              row,
              const ['target', 'target_ip', 'translation', 'nat_target'],
            ),
            targetPort: _first(
              row,
              const ['target_port', 'local_port', 'local-port', 'nat_port'],
            ),
            description: _first(row, const ['description', 'descr', 'name']),
            enabled: !_truthy(row['disabled']) &&
                _truthy(row['enabled'], defaultValue: true),
          ),
        )
        .toList();
  }

  static String _first(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      dynamic value = row[key];
      if (value == null && key.contains('.')) {
        dynamic current = row;
        for (final part in key.split('.')) {
          if (current is Map) {
            current = current[part];
          } else {
            current = null;
            break;
          }
        }
        value = current;
      }
      final text = _text(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String _text(dynamic value) {
    if (value == null) return '';
    if (value is String || value is num || value is bool) {
      return value.toString().trim();
    }
    if (value is List) {
      return value.map(_text).where((e) => e.isNotEmpty).join(', ');
    }
    if (value is Map) {
      for (final key in const [
        'network',
        'address',
        'port',
        'name',
        'label',
      ]) {
        final text = _text(value[key]);
        if (text.isNotEmpty) return text;
      }
      final selected = apiChoiceDisplayText(value);
      if (selected.isNotEmpty) return selected;
    }
    return '';
  }

  static bool _truthy(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().toLowerCase().trim();
    if (const ['1', 'true', 'yes', 'on', 'enabled'].contains(text)) return true;
    if (const ['0', 'false', 'no', 'off', 'disabled'].contains(text)) {
      return false;
    }
    return defaultValue;
  }
}
