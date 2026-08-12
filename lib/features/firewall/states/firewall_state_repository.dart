import '../../../core/api/opnsense_api_client.dart';
import 'firewall_state_models.dart';

class FirewallStateRepository {
  FirewallStateRepository(this.api);
  final OpnSenseApiClient api;

  static const String queryStatesPath =
      '/api/diagnostics/firewall/query_states';

  Future<List<FirewallStateSummary>> load() async {
    // pf_states only reports the current state-table size and limit. The
    // detailed PF rows used by the OPNsense States page come from query_states
    // and that action is POST-only.
    final raw = await api.postData(
      queryStatesPath,
      data: const {
        'current': 1,
        'rowCount': 1000,
        'searchPhrase': '',
      },
    );
    return parse(raw);
  }

  static List<FirewallStateSummary> parse(dynamic raw) {
    dynamic candidate = raw;
    if (raw is Map) {
      candidate = raw['rows'] ??
          raw['states'] ??
          raw['items'] ??
          raw['data'] ??
          raw;
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
          row.putIfAbsent('id', () => entry.key.toString());
          rows.add(row);
        }
      }
    }
    return rows.map((row) {
      final source = _endpoint(
        row,
        combinedKeys: const ['src', 'source'],
        addressKeys: const ['src_addr', 'source_addr'],
        portKeys: const ['src_port', 'source_port'],
      );
      final destination = _endpoint(
        row,
        combinedKeys: const ['dst', 'destination'],
        addressKeys: const ['dst_addr', 'destination_addr'],
        portKeys: const ['dst_port', 'destination_port'],
      );
      return FirewallStateSummary(
        id: _first(row, const ['id', 'stateid', 'state_id']),
        creatorId: _first(row, const ['creatorid', 'creator_id']),
        interfaceName:
            _first(row, const ['interface', 'iface', 'if', 'interface_name']),
        protocol: _first(row, const ['proto', 'protocol']),
        direction: _first(row, const ['direction', 'dir']),
        source: source,
        destination: destination,
        state: _first(row, const ['state', 'status']),
        age: _first(row, const ['age']),
        expires: _first(row, const ['expires', 'expire']),
        packets: _first(row, const ['packets', 'pkts']),
        bytes: _first(row, const ['bytes']),
      );
    }).where((item) {
      return item.id.isNotEmpty ||
          item.source.isNotEmpty ||
          item.destination.isNotEmpty;
    }).toList();
  }

  static String _endpoint(
    Map<String, dynamic> row, {
    required List<String> combinedKeys,
    required List<String> addressKeys,
    required List<String> portKeys,
  }) {
    final combined = _first(row, combinedKeys);
    if (combined.isNotEmpty) return combined;
    final address = _first(row, addressKeys);
    final port = _first(row, portKeys);
    if (address.isEmpty) return '';
    if (port.isEmpty || port == '0') return address;
    if (address.contains(':') && !address.startsWith('[')) {
      return '[$address]:$port';
    }
    return '$address:$port';
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
    if (value is List) {
      return value.map(_flatten).where((e) => e.isNotEmpty).join(' / ');
    }
    if (value is Map) {
      return value.values.map(_flatten).where((e) => e.isNotEmpty).join(' / ');
    }
    return value?.toString().trim() ?? '';
  }
}
