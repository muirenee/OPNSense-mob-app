import '../../core/api/opnsense_api_client.dart';
import 'dashboard_models.dart';

class DashboardRepository {
  DashboardRepository(this.api);

  final OpnSenseApiClient api;

  Future<DashboardSnapshot> load() async {
    // OPNsense OverviewController::interfacesInfoAction accepts the detailed
    // flag as an action argument (/interfaces_info/1), not as ?details=true.
    // Passing details as a query parameter is interpreted by the recordset
    // search helper and can return HTTP 400 on 26.7.
    final results = await Future.wait<Map<String, dynamic>>([
      api.getJson('/api/diagnostics/system/system_information'),
      api.getJson('/api/diagnostics/system/system_resources'),
      api.getJson('/api/diagnostics/system/system_disk'),
      api.getJson('/api/interfaces/overview/interfaces_info/1'),
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

    // OPNsense 26.7 detailed overview returns addr4/addr6 as the primary
    // address strings and ipv4/ipv6 as lists of address objects. Older builds
    // and some proxy normalizers may still expose the compact keys below.
    for (final key in ['addr4', 'addr6', 'ipaddr', 'ipaddrv6', 'address']) {
      final value = item[key];
      if (value is String && value.trim().isNotEmpty) {
        addresses.add(value.trim());
      }
    }

    for (final key in ['ipv4', 'ipv6']) {
      final value = item[key];
      if (value is List) {
        for (final entry in value) {
          if (entry is String && entry.trim().isNotEmpty) {
            addresses.add(entry.trim());
          } else if (entry is Map) {
            final address = entry['ipaddr']?.toString().trim() ?? '';
            if (address.isNotEmpty) addresses.add(address);
          }
        }
      } else if (value is String && value.trim().isNotEmpty) {
        addresses.add(value.trim());
      }
    }
    return addresses.toSet().toList();
  }
}
