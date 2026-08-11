import '../../core/api/opnsense_api_client.dart';
import 'dashboard_models.dart';

class DashboardRepository {
  DashboardRepository(this.api);

  final OpnSenseApiClient api;

  Future<DashboardSnapshot> load() async {
    final results = await Future.wait<Map<String, dynamic>>([
      api.getJson('/api/diagnostics/system/system_information'),
      api.getJson('/api/diagnostics/system/memory'),
      api.getJson('/api/diagnostics/system/system_disk'),
      api.getJson('/api/interfaces/overview/interfaces_info?details=true'),
    ]);

    return DashboardSnapshot(
      systemInformation: results[0],
      memory: results[1],
      disk: results[2],
      interfaces: parseInterfaces(results[3]),
    );
  }

  static List<InterfaceSummary> parseInterfaces(Map<String, dynamic> raw) {
    final dynamic candidate = raw['rows'] ?? raw['interfaces'] ?? raw;
    final items = <Map<String, dynamic>>[];

    if (candidate is List) {
      for (final value in candidate) {
        if (value is Map) items.add(Map<String, dynamic>.from(value));
      }
    } else if (candidate is Map) {
      for (final entry in candidate.entries) {
        if (entry.value is Map) {
          final map = Map<String, dynamic>.from(entry.value as Map);
          map.putIfAbsent('identifier', () => entry.key.toString());
          items.add(map);
        }
      }
    }

    return items.map((item) {
      final identifier = _firstString(item, [
        'identifier',
        'if',
        'name',
        'device',
      ]);
      final description = _firstString(item, [
        'description',
        'descr',
        'friendlyname',
        'name',
      ]);
      final status = _firstString(item, ['status', 'link_state', 'link']);
      return InterfaceSummary(
        identifier: identifier.isEmpty ? description : identifier,
        description: description.isEmpty ? identifier : description,
        status: status.isEmpty ? 'Unknown' : status,
        addresses: _extractAddresses(item),
      );
    }).where((item) => item.identifier.isNotEmpty).toList();
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

  static List<String> _extractAddresses(Map<String, dynamic> item) {
    final addresses = <String>[];
    for (final key in ['ipaddr', 'ipaddrv6', 'address', 'ipv4', 'ipv6']) {
      final value = item[key];
      if (value is String && value.trim().isNotEmpty) {
        addresses.add(value.trim());
      } else if (value is List) {
        addresses.addAll(value.whereType<String>().where((v) => v.isNotEmpty));
      }
    }
    return addresses.toSet().toList();
  }
}
