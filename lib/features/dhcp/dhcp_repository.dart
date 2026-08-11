import '../../core/api/opnsense_api_client.dart';
import 'dhcp_models.dart';

class DhcpRepository {
  DhcpRepository(this.api);

  final OpnSenseApiClient api;

  Future<KeaDhcpData> loadAll() async {
    final results = await Future.wait<dynamic>([
      api.getData(
        '/api/kea/leases/search',
        queryParameters: const {'current': 1, 'rowCount': 1000},
      ),
      api.getData(
        '/api/kea/dhcpv4/search_reservation',
        queryParameters: const {'current': 1, 'rowCount': 1000},
      ),
      api.getData(
        '/api/kea/dhcpv4/search_subnet',
        queryParameters: const {'current': 1, 'rowCount': 500},
      ),
    ]);

    final subnets = parseSubnets(results[2]);
    return KeaDhcpData(
      leases: parseLeases(results[0]),
      reservations: parseReservations(results[1], subnets: subnets),
      subnets: subnets,
    );
  }

  Future<List<DhcpLeaseSummary>> loadLeases() async {
    final raw = await api.getData(
      '/api/kea/leases/search',
      queryParameters: const {'current': 1, 'rowCount': 1000},
    );
    return parseLeases(raw);
  }

  Future<List<KeaSubnetSummary>> loadSubnets() async {
    final raw = await api.getData(
      '/api/kea/dhcpv4/search_subnet',
      queryParameters: const {'current': 1, 'rowCount': 500},
    );
    return parseSubnets(raw);
  }

  Future<List<KeaReservationSummary>> loadReservations({
    List<KeaSubnetSummary>? subnets,
  }) async {
    final raw = await api.getData(
      '/api/kea/dhcpv4/search_reservation',
      queryParameters: const {'current': 1, 'rowCount': 1000},
    );
    return parseReservations(raw, subnets: subnets ?? const []);
  }

  Future<KeaReservationSummary?> getReservation(
    String uuid, {
    List<KeaSubnetSummary> subnets = const [],
  }) async {
    final raw = await api.getData(
      '/api/kea/dhcpv4/get_reservation/${Uri.encodeComponent(uuid)}',
    );
    if (raw is! Map) return null;
    final map = raw['reservation'];
    if (map is! Map) return null;
    return reservationFromMap(
      Map<String, dynamic>.from(map),
      uuid: uuid,
      subnets: subnets,
    );
  }

  Future<void> addReservation(KeaReservationDraft draft) async {
    await api.postData(
      '/api/kea/dhcpv4/add_reservation',
      data: {'reservation': draft.toApi()},
    );
    await reconfigure();
  }

  Future<void> updateReservation(
    String uuid,
    KeaReservationDraft draft,
  ) async {
    await api.postData(
      '/api/kea/dhcpv4/set_reservation/${Uri.encodeComponent(uuid)}',
      data: {'reservation': draft.toApi()},
    );
    await reconfigure();
  }

  Future<void> deleteReservation(String uuid) async {
    await api.postData(
      '/api/kea/dhcpv4/del_reservation/${Uri.encodeComponent(uuid)}',
    );
    await reconfigure();
  }

  Future<void> releaseLease(String ip) async {
    await api.postData(
      '/api/kea/leases/del_lease/${Uri.encodeComponent(ip)}',
    );
  }

  Future<void> reconfigure() async {
    await api.postData('/api/kea/service/reconfigure');
  }

  KeaSubnetSummary? subnetForIp(
    String ip,
    List<KeaSubnetSummary> subnets,
  ) {
    for (final subnet in subnets) {
      if (_ipv4InCidr(ip, subnet.subnet)) return subnet;
    }
    return null;
  }

  static List<DhcpLeaseSummary> parseLeases(dynamic raw) {
    final rows = _rows(raw, const ['rows', 'leases', 'items', 'data']);
    return rows.map((row) {
      return DhcpLeaseSummary(
        ip: _first(row, const [
          'ip',
          'address',
          'ip-address',
          'ip_address',
        ]),
        mac: _first(row, const [
          'mac',
          'hwaddr',
          'hw-address',
          'hw_address',
          'mac-address',
          'mac_address',
        ]),
        hostname: _first(row, const [
          'hostname',
          'host',
          'client-hostname',
        ]),
        interfaceName: _first(row, const [
          'interface',
          'if',
          'interface_name',
          'iface',
        ]),
        state: _first(row, const [
          'state',
          'status',
          'binding-state',
        ]),
        starts: _first(row, const ['starts', 'start', 'cltt']),
        ends: _first(row, const [
          'ends',
          'end',
          'expire',
          'expiration',
          'valid_lft',
        ]),
        clientId: _first(row, const [
          'client-id',
          'client_id',
          'clientid',
        ]),
        subnetId: _first(row, const [
          'subnet-id',
          'subnet_id',
          'subnetid',
        ]),
        source: 'Kea',
      );
    }).where((item) => item.ip.isNotEmpty).toList();
  }

  static List<KeaSubnetSummary> parseSubnets(dynamic raw) {
    final rows = _rows(raw, const ['rows', 'subnets', 'items', 'data']);
    return rows.map((row) {
      return KeaSubnetSummary(
        uuid: _first(row, const ['uuid', 'id']),
        subnet: _first(row, const ['subnet', 'network']),
        description: _first(row, const ['description', 'descr']),
        subnetId: _first(row, const ['subnet_id', 'subnet-id']),
      );
    }).where((item) => item.uuid.isNotEmpty && item.subnet.isNotEmpty).toList();
  }

  static List<KeaReservationSummary> parseReservations(
    dynamic raw, {
    List<KeaSubnetSummary> subnets = const [],
  }) {
    final rows = _rows(raw, const [
      'rows',
      'reservations',
      'items',
      'data',
    ]);
    return rows.map((row) {
      final uuid = _first(row, const ['uuid', 'id']);
      return reservationFromMap(
        row,
        uuid: uuid,
        subnets: subnets,
      );
    }).where((item) => item.uuid.isNotEmpty).toList();
  }

  static KeaReservationSummary reservationFromMap(
    Map<String, dynamic> row, {
    required String uuid,
    List<KeaSubnetSummary> subnets = const [],
  }) {
    final subnetUuid = _first(row, const ['subnet', 'subnet_uuid']);
    var subnetLabel = _first(row, const [
      'subnet_description',
      'subnet_label',
      'subnet_name',
    ]);
    if (subnetLabel.isEmpty) {
      for (final subnet in subnets) {
        if (subnet.uuid == subnetUuid) {
          subnetLabel = subnet.label;
          break;
        }
      }
    }
    return KeaReservationSummary(
      uuid: uuid,
      subnetUuid: subnetUuid,
      subnetLabel: subnetLabel,
      ip: _first(row, const ['ip_address', 'ip-address', 'ip']),
      mac: _first(row, const ['hw_address', 'hw-address', 'mac']),
      clientId: _first(row, const ['client_id', 'client-id']),
      hostname: _first(row, const ['hostname']),
      description: _first(row, const ['description', 'descr']),
    );
  }

  static List<Map<String, dynamic>> _rows(dynamic raw, List<String> keys) {
    dynamic candidate = raw;
    if (raw is Map) {
      for (final key in keys) {
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
          row.putIfAbsent('uuid', () => entry.key.toString());
          rows.add(row);
        }
      }
    }
    return rows;
  }

  static String _first(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      final text = _text(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String _text(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is num || value is bool) return value.toString();
    if (value is List) {
      return value.map(_text).where((item) => item.isNotEmpty).join(', ');
    }
    if (value is Map) {
      for (final key in const ['selected', 'value', 'name', 'label']) {
        if (value[key] != null) {
          final result = _text(value[key]);
          if (result.isNotEmpty) return result;
        }
      }
    }
    return value.toString().trim();
  }

  static bool _ipv4InCidr(String ip, String cidr) {
    final parts = cidr.split('/');
    if (parts.length != 2) return false;
    final prefix = int.tryParse(parts[1]);
    if (prefix == null || prefix < 0 || prefix > 32) return false;
    final ipValue = _ipv4ToInt(ip);
    final networkValue = _ipv4ToInt(parts[0]);
    if (ipValue == null || networkValue == null) return false;
    final mask = prefix == 0 ? 0 : (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
    return (ipValue & mask) == (networkValue & mask);
  }

  static int? _ipv4ToInt(String value) {
    final parts = value.split('.');
    if (parts.length != 4) return null;
    var result = 0;
    for (final part in parts) {
      final octet = int.tryParse(part);
      if (octet == null || octet < 0 || octet > 255) return null;
      result = (result << 8) | octet;
    }
    return result;
  }
}
