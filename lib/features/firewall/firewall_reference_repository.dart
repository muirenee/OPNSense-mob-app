import '../../core/api/api_choice.dart';
import '../../core/api/opnsense_api_client.dart';

class FirewallReferenceOptions {
  const FirewallReferenceOptions({
    required this.networks,
    required this.ports,
  });

  final List<ApiChoice> networks;
  final List<ApiChoice> ports;
}

/// Loads the same option inventories used by OPNsense's `net_selector` and
/// `port_selector` controls while preserving manual text entry in Sentinel.
class FirewallReferenceRepository {
  FirewallReferenceRepository(this.api);

  final OpnSenseApiClient api;

  Future<FirewallReferenceOptions> load() async {
    final networks = <String, ApiChoice>{
      'any': const ApiChoice(value: 'any', label: 'Any'),
      '(self)': const ApiChoice(value: '(self)', label: 'This Firewall'),
    };
    final ports = <String, ApiChoice>{
      '': const ApiChoice(value: '', label: 'Any port'),
    };

    // OPNsense 26.7 exposes these specifically for net_selector/port_selector.
    // Prefer them because they already account for virtual interfaces, aliases
    // and the firewall's own current list of well-known services.
    try {
      final raw = await api.getData(
        '/api/firewall/filter/list_network_select_options',
      );
      for (final choice in parseSelectOptions(
        raw,
        groups: const ['networks', 'aliases'],
      )) {
        networks[choice.value] = choice;
      }
    } catch (_) {
      // The derived fallback below supports older/restricted installations.
    }

    try {
      final raw = await api.getData(
        '/api/firewall/filter/list_port_select_options',
      );
      for (final choice in parseSelectOptions(
        raw,
        groups: const ['ports', 'aliases'],
      )) {
        ports[choice.value] = choice;
      }
    } catch (_) {
      // Seeded/fallback port values below remain usable.
    }

    _addWellKnownPortsIfMissing(ports);

    // Fallback interface special networks. Do not overwrite native selector
    // values because OPNsense knows which virtual interfaces support `ifip`.
    try {
      final raw = await api.getData('/api/firewall/filter/get_rule');
      final rule = _extractRule(raw);
      final interfaces = parseApiChoices(
        rule['interface'],
        scalarValuesSelected: false,
      );
      for (final interface in interfaces) {
        if (interface.value.isEmpty) continue;
        networks.putIfAbsent(
          interface.value,
          () => ApiChoice(
            value: interface.value,
            label: '${interface.label} network',
          ),
        );
        networks.putIfAbsent(
          '${interface.value}ip',
          () => ApiChoice(
            value: '${interface.value}ip',
            label: '${interface.label} address',
          ),
        );
      }
    } catch (_) {}

    // Fallback alias inventory when the selector endpoints are unavailable to
    // the API user. This also makes alias ACL failures independent from manual
    // IP/CIDR/port entry.
    try {
      final raw = await api.getData(
        '/api/firewall/alias/search_item',
        queryParameters: const {'current': 1, 'rowCount': 1000},
      );
      for (final row in _rows(raw)) {
        final name = _scalar(row['name']);
        final type = _scalar(row['type']).toLowerCase();
        if (name.isEmpty || _disabled(row)) continue;
        if (type == 'port') {
          ports.putIfAbsent(
            name,
            () => ApiChoice(value: name, label: '$name · port alias'),
          );
        } else if (type != 'internal') {
          networks.putIfAbsent(
            name,
            () => ApiChoice(value: name, label: '$name · alias'),
          );
        }
      }
    } catch (_) {}

    return FirewallReferenceOptions(
      networks: _sorted(networks.values),
      ports: _sorted(ports.values),
    );
  }

  static List<ApiChoice> parseSelectOptions(
    dynamic raw, {
    required List<String> groups,
  }) {
    if (raw is! Map) return const <ApiChoice>[];
    final map = Map<String, dynamic>.from(raw);
    final result = <String, ApiChoice>{};
    for (final groupName in groups) {
      final group = map[groupName];
      if (group is! Map) continue;
      final items = group['items'];
      if (items is! Map) continue;
      for (final entry in items.entries) {
        final value = entry.key.toString().trim();
        final label = entry.value?.toString().trim() ?? '';
        // The empty port value is meaningful: it represents any port.
        if (value.isEmpty && groupName != 'ports') continue;
        result[value] = ApiChoice(
          value: value,
          label: label.isEmpty
              ? (value.isEmpty ? 'Any port' : value)
              : label,
        );
      }
    }
    return _sorted(result.values);
  }

  static Map<String, dynamic> _extractRule(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final map = Map<String, dynamic>.from(raw);
    final rule = map['rule'];
    return rule is Map
        ? Map<String, dynamic>.from(rule)
        : Map<String, dynamic>.from(map);
  }

  static List<Map<String, dynamic>> _rows(dynamic raw) {
    if (raw is! Map) return const <Map<String, dynamic>>[];
    final map = Map<String, dynamic>.from(raw);
    final candidate = map['rows'] ?? map['items'] ?? map['aliases'];
    if (candidate is! List) return const <Map<String, dynamic>>[];
    return candidate
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  static String _scalar(dynamic value) {
    if (value == null) return '';
    if (value is String || value is num || value is bool) {
      return value.toString().trim();
    }
    if (value is Map) {
      final selected = parseApiChoices(value)
          .where((choice) => choice.selected)
          .toList();
      if (selected.length == 1) return selected.single.value;
      for (final key in const ['value', 'name', 'label']) {
        final nested = value[key];
        if (nested is String || nested is num) {
          final text = nested.toString().trim();
          if (text.isNotEmpty) return text;
        }
      }
    }
    return '';
  }

  static bool _disabled(Map<String, dynamic> row) {
    final disabled = _scalar(row['disabled']).toLowerCase();
    if (const {'1', 'true', 'yes', 'on'}.contains(disabled)) return true;
    final enabled = _scalar(row['enabled']).toLowerCase();
    return const {'0', 'false', 'no', 'off'}.contains(enabled);
  }

  static List<ApiChoice> _sorted(Iterable<ApiChoice> choices) {
    final result = choices.toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return result;
  }

  static void _addWellKnownPortsIfMissing(Map<String, ApiChoice> output) {
    const services = <String, int>{
      'domain': 53,
      'ftp': 21,
      'http': 80,
      'https': 443,
      'imap': 143,
      'imaps': 993,
      'ipsec-nat-t': 4500,
      'isakmp': 500,
      'ldap': 389,
      'microsoft-ds': 445,
      'ms-wbt-server': 3389,
      'ntp': 123,
      'openvpn': 1194,
      'pop3': 110,
      'pop3s': 995,
      'pptp': 1723,
      'radius': 1812,
      'radius-acct': 1813,
      'sip': 5060,
      'smtp': 25,
      'snmp': 161,
      'snmptrap': 162,
      'ssh': 22,
      'submission': 587,
      'telnet': 23,
      'tftp': 69,
    };
    for (final entry in services.entries) {
      output.putIfAbsent(
        entry.key,
        () => ApiChoice(
          value: entry.key,
          label: '${entry.key.toUpperCase()} (${entry.value})',
        ),
      );
    }
  }
}
