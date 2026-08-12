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

/// Builds the values used by OPNsense's net_selector and port_selector UI.
///
/// OPNsense NetworkAliasField accepts special networks, interface nets/addresses,
/// address aliases and manually-entered IP/CIDR values. PortField accepts
/// well-known service names, port aliases, numeric ports and (where enabled)
/// ranges. Sentinel exposes the known values while keeping manual entry open.
class FirewallReferenceRepository {
  FirewallReferenceRepository(this.api);

  final OpnSenseApiClient api;

  Future<FirewallReferenceOptions> load() async {
    final networks = <String, ApiChoice>{
      'any': const ApiChoice(value: 'any', label: 'Any'),
      '(self)': const ApiChoice(value: '(self)', label: 'This Firewall'),
    };
    final ports = <String, ApiChoice>{};
    _addWellKnownPorts(ports);

    try {
      final raw = await api.getData('/api/firewall/filter/getRule');
      final rule = _extractRule(raw);
      final interfaces = parseApiChoices(
        rule['interface'],
        scalarValuesSelected: false,
      );
      for (final interface in interfaces) {
        if (interface.value.isEmpty) continue;
        networks[interface.value] = ApiChoice(
          value: interface.value,
          label: '${interface.label} net',
        );
        networks['${interface.value}ip'] = ApiChoice(
          value: '${interface.value}ip',
          label: '${interface.label} address',
        );
      }
    } catch (_) {
      // Alias choices below remain useful even when filter-model access is denied.
    }

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
          ports[name] = ApiChoice(value: name, label: '$name · port alias');
        } else {
          networks[name] = ApiChoice(
            value: name,
            label: '$name · ${_aliasTypeLabel(type)}',
          );
        }
      }
    } catch (_) {
      // Special/interface choices and manual entry still work without alias ACL.
    }

    return FirewallReferenceOptions(
      networks: _sorted(networks.values),
      ports: _sorted(ports.values),
    );
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

  static String _aliasTypeLabel(String type) {
    if (type.isEmpty) return 'alias';
    return switch (type) {
      'host' => 'host alias',
      'network' => 'network alias',
      'url' || 'urltable' || 'urltable_ports' => 'URL alias',
      'geoip' => 'GeoIP alias',
      'external' => 'external alias',
      _ => '$type alias',
    };
  }

  static List<ApiChoice> _sorted(Iterable<ApiChoice> choices) {
    final result = choices.toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return result;
  }

  static void _addWellKnownPorts(Map<String, ApiChoice> output) {
    const services = <String, int>{
      'afs3-fileserver': 7000,
      'aol': 5190,
      'auth': 113,
      'avt-profile-1': 5004,
      'cvsup': 5999,
      'domain': 53,
      'ftp': 21,
      'hbci': 3000,
      'http': 80,
      'https': 443,
      'igmpv3lite': 465,
      'imap': 143,
      'imaps': 993,
      'ipsec-msft': 10000,
      'ipsec-nat-t': 4500,
      'isakmp': 500,
      'l2f': 1701,
      'ldap': 389,
      'microsoft-ds': 445,
      'ms-streaming': 1755,
      'ms-wbt-server': 3389,
      'msnp': 1863,
      'nat-stun-port': 3478,
      'netbios-dgm': 138,
      'netbios-ns': 137,
      'netbios-ssn': 139,
      'nntp': 119,
      'ntp': 123,
      'openvpn': 1194,
      'pop3': 110,
      'pop3s': 995,
      'pptp': 1723,
      'radius': 1812,
      'radius-acct': 1813,
      'rfb': 5900,
      'sip': 5060,
      'smtp': 25,
      'snmp': 161,
      'snmptrap': 162,
      'ssh': 22,
      'submission': 587,
      'telnet': 23,
      'teredo': 3544,
      'tftp': 69,
      'urd': 465,
      'wins': 1512,
    };
    output['any'] = const ApiChoice(value: 'any', label: 'Any port');
    for (final entry in services.entries) {
      output[entry.key] = ApiChoice(
        value: entry.key,
        label: '${entry.key} (${entry.value})',
      );
    }
  }
}
