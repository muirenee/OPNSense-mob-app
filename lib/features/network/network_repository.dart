import '../../core/api/opnsense_api_client.dart';
import '../dashboard/dashboard_repository.dart';
import 'network_models.dart';

class NetworkRepository {
  NetworkRepository(this.api);

  final OpnSenseApiClient api;

  Future<NetworkSnapshot> load() async {
    final results = await Future.wait<dynamic>([
      api.getData('/api/routes/gateway/status'),
      api.getData('/api/interfaces/overview/interfaces_info',
          queryParameters: const {'details': 'true'}),
      api.getData('/api/diagnostics/interface/get_interface_statistics'),
    ]);

    final gateways = parseGateways(results[0]);
    final overviewMap = _asMap(results[1]);
    final overview = DashboardRepository.parseInterfaces(overviewMap);
    final stats = parseInterfaceStatistics(results[2]);

    final interfaces = overview.map((item) {
      final counters = stats[item.identifier] ??
          _findCounters(stats, item.description);
      return NetworkInterfaceSummary(
        identifier: item.identifier,
        description: item.description,
        status: item.status,
        addresses: item.addresses,
        rxBytes: counters?['rxBytes'],
        txBytes: counters?['txBytes'],
        rxPackets: counters?['rxPackets'],
        txPackets: counters?['txPackets'],
        inputErrors: counters?['inputErrors'],
        outputErrors: counters?['outputErrors'],
      );
    }).toList();

    return NetworkSnapshot(gateways: gateways, interfaces: interfaces);
  }

  Future<Map<String, Map<String, int?>>> loadInterfaceCounters() async {
    final raw = await api.getData(
      '/api/diagnostics/interface/get_interface_statistics',
    );
    return parseInterfaceStatistics(raw);
  }

  static List<GatewaySummary> parseGateways(dynamic raw) {
    final rows = _rows(raw, preferredKeys: const ['rows', 'items', 'gateways']);
    return rows.map((row) {
      return GatewaySummary(
        name: _firstString(row, const ['name', 'gateway', 'gwname', 'identifier']),
        status: _firstString(row, const ['status', 'state', 'status_translated']),
        interfaceName:
            _firstString(row, const ['interface', 'if', 'interface_name']),
        address: _firstString(row, const ['address', 'gateway_ip', 'gateway']),
        monitor: _firstString(row, const ['monitor', 'monitor_ip', 'monitorip']),
        delay: _firstString(row, const ['delay', 'rtt', 'latency']),
        loss: _firstString(row, const ['loss', 'packetloss', 'packet_loss']),
      );
    }).where((item) => item.name.isNotEmpty).toList();
  }

  static Map<String, Map<String, int?>> parseInterfaceStatistics(dynamic raw) {
    final output = <String, Map<String, int?>>{};
    final rows = _rows(
      raw,
      preferredKeys: const ['rows', 'interfaces', 'statistics', 'data'],
      includeMapKeys: true,
    );

    for (final row in rows) {
      final id = _firstString(
        row,
        const ['identifier', 'name', 'interface', 'if', 'device', '_mapKey'],
      );
      if (id.isEmpty) continue;
      output[id] = {
        'rxBytes': _firstInt(row, const [
          'bytes received',
          'bytes_received',
          'ibytes',
          'rx_bytes',
          'inbytes',
        ]),
        'txBytes': _firstInt(row, const [
          'bytes sent',
          'bytes_sent',
          'obytes',
          'tx_bytes',
          'outbytes',
        ]),
        'rxPackets': _firstInt(row, const [
          'packets received',
          'packets_received',
          'ipackets',
          'rx_packets',
        ]),
        'txPackets': _firstInt(row, const [
          'packets sent',
          'packets_sent',
          'opackets',
          'tx_packets',
        ]),
        'inputErrors': _firstInt(row, const [
          'input errors',
          'input_errors',
          'ierrors',
          'rx_errors',
        ]),
        'outputErrors': _firstInt(row, const [
          'output errors',
          'output_errors',
          'oerrors',
          'tx_errors',
        ]),
      };
    }
    return output;
  }

  static List<Map<String, dynamic>> _rows(
    dynamic raw, {
    required List<String> preferredKeys,
    bool includeMapKeys = false,
  }) {
    dynamic candidate = raw;
    if (raw is Map) {
      for (final key in preferredKeys) {
        if (raw[key] != null) {
          candidate = raw[key];
          break;
        }
      }
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
          if (includeMapKeys) row['_mapKey'] = entry.key.toString();
          row.putIfAbsent('name', () => entry.key.toString());
          rows.add(row);
        }
      }
    }
    return rows;
  }

  static Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  static String _firstString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  static Map<String, int?>? _findCounters(
    Map<String, Map<String, int?>> stats,
    String description,
  ) {
    final target = description.toLowerCase();
    for (final entry in stats.entries) {
      if (entry.key.toLowerCase() == target) return entry.value;
    }
    return null;
  }

  static int? _firstInt(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final cleaned = value.replaceAll(',', '').trim();
        final parsed = int.tryParse(cleaned);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }
}
