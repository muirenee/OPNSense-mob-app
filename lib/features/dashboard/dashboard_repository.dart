import '../../core/api/opnsense_api_client.dart';
import 'dashboard_models.dart';

class DashboardRepository {
  DashboardRepository(this.api);

  final OpnSenseApiClient api;

  Future<DashboardSnapshot> load() async {
    // Keep the connection/authentication probe authoritative, but do not let
    // one optional dashboard card make the complete dashboard unavailable.
    // OPNsense 26.7 exposes interfaces_info with the detail flag as a PATH
    // argument (interfaces_info/1), not a ?details=true query argument. The
    // dashboard does not need the expensive detailed statistics, so use the
    // normal endpoint here.
    final systemInformation =
        await api.getJson('/api/diagnostics/system/system_information');

    final optional = await Future.wait<Map<String, dynamic>>([
      _safeGetJson('/api/diagnostics/system/system_resources'),
      _safeGetJson('/api/diagnostics/system/system_disk'),
      _safeGetJson('/api/interfaces/overview/interfaces_info'),
    ]);

    return DashboardSnapshot(
      systemInformation: systemInformation,
      memory: optional[0],
      disk: optional[1],
      interfaces: parseInterfaces(optional[2]),
    );
  }

  Future<Map<String, dynamic>> _safeGetJson(String path) async {
    try {
      return await api.getJson(path);
    } catch (_) {
      return <String, dynamic>{};
    }
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

    void add(dynamic value) {
      if (value is String) {
        final text = value.trim();
        if (text.isNotEmpty) addresses.add(text);
        return;
      }
      if (value is List) {
        for (final entry in value) {
          add(entry);
        }
        return;
      }
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        final ip = map['ipaddr'] ?? map['address'];
        if (ip != null && ip.toString().trim().isNotEmpty) {
          var text = ip.toString().trim();
          final bits = map['subnetbits'] ?? map['bits'];
          if (bits != null &&
              bits.toString().trim().isNotEmpty &&
              !text.contains('/')) {
            text = '$text/${bits.toString().trim()}';
          }
          addresses.add(text);
        }
      }
    }

    for (final key in const [
      'addr4',
      'addr6',
      'ipaddr',
      'ipaddrv6',
      'address',
      'ipv4',
      'ipv6',
    ]) {
      add(item[key]);
    }
    return addresses.where((value) => value.isNotEmpty).toSet().toList();
  }
}
