import '../../core/api/api_choice.dart';
import '../../core/api/opnsense_api_client.dart';
import 'firewall_models.dart';

class FirewallRepository {
  FirewallRepository(this.api);

  final OpnSenseApiClient api;

  Future<List<FirewallRuleSummary>> loadRules({String search = ''}) async {
    final raw = await api.getData(
      '/api/firewall/filter/search_rule',
      queryParameters: {
        'current': 1,
        'rowCount': 200,
        if (search.trim().isNotEmpty) 'searchPhrase': search.trim(),
      },
    );
    return parseRules(raw);
  }

  Future<Map<String, dynamic>> getRule([String? uuid]) async {
    final suffix = uuid == null || uuid.isEmpty
        ? ''
        : '/${Uri.encodeComponent(uuid)}';
    final raw = await api.getData('/api/firewall/filter/get_rule$suffix');
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final rule = map['rule'];
      if (rule is Map) return Map<String, dynamic>.from(rule);
      return map;
    }
    return <String, dynamic>{};
  }

  /// Returns the real interface/group values published by OPNsense's firewall
  /// UI. Synthetic grid filters such as __floating and __any are deliberately
  /// not returned as rule interface values.
  Future<List<ApiChoice>> loadInterfaceChoices() async {
    final raw = await api.getData('/api/firewall/filter/get_interface_list');
    if (raw is! Map) return const <ApiChoice>[];

    final byValue = <String, ApiChoice>{};
    final map = Map<String, dynamic>.from(raw);
    for (final groupName in const ['groups', 'interfaces']) {
      final group = map[groupName];
      if (group is! Map) continue;
      final items = group['items'];
      if (items is List) {
        for (final item in items) {
          if (item is! Map) continue;
          final row = Map<String, dynamic>.from(item);
          final value = row['value']?.toString().trim() ?? '';
          if (value.isEmpty || value.startsWith('__')) continue;
          final label = row['label']?.toString().trim() ?? value;
          byValue[value] = ApiChoice(
            value: value,
            label: groupName == 'groups' ? '$label · group' : label,
          );
        }
      }
    }

    final result = byValue.values.toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return result;
  }

  Future<String> saveRuleSafely({
    String? uuid,
    required Map<String, dynamic> values,
  }) async {
    return _changeAndApply(() {
      return api.postData(
        uuid == null || uuid.isEmpty
            ? '/api/firewall/filter/add_rule'
            : '/api/firewall/filter/set_rule/${Uri.encodeComponent(uuid)}',
        data: {'rule': values},
      );
    });
  }

  Future<String> deleteRuleSafely(FirewallRuleSummary rule) async {
    if (rule.uuid.isEmpty) throw StateError('Firewall rule UUID is missing.');
    return _changeAndApply(
      () => api.postData(
        '/api/firewall/filter/del_rule/${Uri.encodeComponent(rule.uuid)}',
      ),
    );
  }

  Future<String> toggleRuleSafely({
    required FirewallRuleSummary rule,
    required bool enabled,
  }) async {
    if (rule.uuid.isEmpty) {
      throw StateError('The selected rule does not have a UUID.');
    }
    return _changeAndApply(
      () => api.postData(
        '/api/firewall/filter/toggle_rule/${Uri.encodeComponent(rule.uuid)}/${enabled ? 1 : 0}',
      ),
    );
  }

  /// OPNsense 26.7 firewall controllers persist the model mutation first and
  /// expose a separate POST /apply action. They do not expose the savepoint /
  /// cancel_rollback transaction endpoints previously assumed by Sentinel.
  Future<String> _changeAndApply(Future<dynamic> Function() change) async {
    final changed = await change();
    _ensureMutationSuccess(changed, 'Firewall change');

    final applied = await api.postData('/api/firewall/filter/apply');
    _ensureMutationSuccess(applied, 'Apply firewall change');

    final uuid = changed is Map
        ? _first(Map<String, dynamic>.from(changed), const ['uuid'])
        : '';
    return uuid.isEmpty ? 'applied' : uuid;
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

  static String? selectedChoice(Map<String, dynamic> model, String field) {
    final parsed = parseApiChoices(model[field]);
    for (final choice in parsed) {
      if (choice.selected) return choice.value;
    }
    final raw = model[field];
    if (raw is String || raw is num || raw is bool) {
      final value = raw.toString().trim();
      if (value.isNotEmpty) return value;
    }
    if (raw is Map) {
      final direct = raw['value'];
      if (direct is String || direct is num) {
        final value = direct.toString().trim();
        if (value.isNotEmpty) return value;
      }
    }
    return null;
  }

  static String fieldValue(
    Map<String, dynamic> model,
    String field, {
    String fallback = '',
  }) =>
      selectedChoice(model, field) ?? fallback;

  /// ProtocolField values in OPNsense are case-sensitive. In particular, its
  /// validation explicitly checks TCP, UDP and TCP/UDP when ports are used.
  static String normalizeProtocol(String? value) {
    final text = value?.trim() ?? '';
    switch (text.toLowerCase()) {
      case '':
      case 'any':
        return 'any';
      case 'tcp':
        return 'TCP';
      case 'udp':
        return 'UDP';
      case 'tcp/udp':
      case 'tcp_udp':
        return 'TCP/UDP';
      case 'icmp':
        return 'ICMP';
      case 'icmp6':
      case 'icmpv6':
      case 'ipv6-icmp':
        return 'IPV6-ICMP';
      case 'esp':
        return 'ESP';
      case 'gre':
        return 'GRE';
      default:
        return text;
    }
  }

  static bool protocolSupportsPorts(String? value) {
    final protocol = normalizeProtocol(value);
    return const {'TCP', 'UDP', 'TCP/UDP'}.contains(protocol);
  }

  /// OPNsense PortField represents an unrestricted port with an empty value.
  /// Accept the user-friendly word "any" but never submit it as a port name.
  static String normalizePort(String value) {
    final text = value.trim();
    return text.toLowerCase() == 'any' ? '' : text;
  }

  static List<FirewallRuleSummary> parseRules(dynamic raw) {
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
        destinationPort: _first(
          row,
          const ['destination_port', 'dst_port'],
        ),
        description: _first(row, const ['description', 'descr', 'name']),
        enabled: _boolValue(row['enabled'], defaultValue: true) &&
            !_boolValue(row['disabled']),
        logging: _boolValue(row['log']) || _boolValue(row['logging']),
      );
    }).toList();
  }

  static String _first(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final text = _display(map[key]);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String _display(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is num || value is bool) return value.toString();
    if (value is List || value is Map) return apiChoiceDisplayText(value);
    return '';
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

  static void _ensureMutationSuccess(dynamic raw, String operation) {
    final normalized = OpnSenseApiClient.normalizeResponseData(raw);
    if (normalized is! Map) return;
    final map = Map<String, dynamic>.from(normalized);
    final result = map['result']?.toString().trim().toLowerCase();
    final status = map['status']?.toString().trim().toLowerCase();
    if (result == 'failed' || status == 'failed' || status == 'error') {
      final validations = map['validations'] ?? map['validation'];
      final details = <String>[];
      if (validations is Map) {
        for (final entry in validations.entries) {
          final value = entry.value;
          if (value is List) {
            details.addAll(value.map((item) => item.toString().trim()));
          } else if (value != null) {
            details.add(value.toString().trim());
          }
        }
      }
      final fallback = (map['message'] ?? map['error'] ?? '').toString().trim();
      final detail = details.where((value) => value.isNotEmpty).join(' · ');
      throw StateError(
        detail.isNotEmpty
            ? '$operation failed: $detail'
            : fallback.isNotEmpty
                ? '$operation failed: $fallback'
                : '$operation failed.',
      );
    }
  }
}
