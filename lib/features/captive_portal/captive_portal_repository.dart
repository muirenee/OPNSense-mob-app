import '../../core/api/opnsense_api_client.dart';
import 'captive_portal_models.dart';

class CaptivePortalRepository {
  CaptivePortalRepository(this.api);

  final OpnSenseApiClient api;

  Future<List<CaptivePortalZone>> loadZones() async {
    final raw = await api.getData(
      '/api/captiveportal/settings/search_zones',
      queryParameters: const {'current': 1, 'rowCount': 100},
    );
    return parseZones(raw);
  }

  Future<Map<String, dynamic>> getZone(String uuid) async {
    final raw = await api.getData(
      '/api/captiveportal/settings/get_zone/${Uri.encodeComponent(uuid)}',
    );
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final zone = map['zone'];
      if (zone is Map) return Map<String, dynamic>.from(zone);
      return map;
    }
    return <String, dynamic>{};
  }

  Future<void> saveZone({String? uuid, required Map<String, dynamic> values}) async {
    await api.postData(
      uuid == null || uuid.isEmpty
          ? '/api/captiveportal/settings/add_zone'
          : '/api/captiveportal/settings/set_zone/${Uri.encodeComponent(uuid)}',
      data: {'zone': values},
    );
    await api.postData('/api/captiveportal/service/reconfigure');
  }

  Future<void> deleteZone(String uuid) async {
    await api.postData('/api/captiveportal/settings/del_zone/${Uri.encodeComponent(uuid)}');
    await api.postData('/api/captiveportal/service/reconfigure');
  }

  Future<void> toggleZone(CaptivePortalZone zone, bool enabled) async {
    await api.postData(
      '/api/captiveportal/settings/toggle_zone/${Uri.encodeComponent(zone.uuid)}/${enabled ? 1 : 0}',
    );
    await api.postData('/api/captiveportal/service/reconfigure');
  }

  Future<List<CaptivePortalSession>> loadSessions({String selectedZones = ''}) async {
    final raw = await api.getData(
      '/api/captiveportal/session/search',
      queryParameters: {
        if (selectedZones.isNotEmpty) 'selected_zones': selectedZones,
      },
    );
    return parseSessions(raw);
  }

  Future<Map<String, String>> loadSessionZones() async {
    final raw = await api.getData('/api/captiveportal/session/zones');
    if (raw is! Map) return <String, String>{};
    final map = Map<String, dynamic>.from(raw);
    final result = <String, String>{};
    for (final entry in map.entries) {
      if (entry.value is String || entry.value is num) {
        result[entry.key] = entry.value.toString();
      } else if (entry.value is Map) {
        result[entry.key] = _first(
          Map<String, dynamic>.from(entry.value as Map),
          const ['description', 'name', 'label'],
          fallback: entry.key,
        );
      }
    }
    return result;
  }

  Future<void> disconnectSession(String sessionId) async {
    await api.postData(
      '/api/captiveportal/session/disconnect',
      data: {'sessionId': sessionId},
    );
  }

  Future<void> authorizeClient({
    required String zoneId,
    required String username,
    required String ip,
  }) async {
    await api.postData(
      '/api/captiveportal/session/connect/${Uri.encodeComponent(zoneId)}',
      data: {'user': username, 'ip': ip},
    );
  }

  Future<List<String>> loadVoucherProviders() async {
    final raw = await api.getData('/api/captiveportal/voucher/list_providers');
    return _stringList(raw);
  }

  Future<List<String>> loadVoucherGroups(String provider) async {
    final raw = await api.getData(
      '/api/captiveportal/voucher/list_voucher_groups/${Uri.encodeComponent(provider)}',
    );
    return _stringList(raw);
  }

  Future<List<CaptivePortalVoucher>> loadVouchers(String provider, String group) async {
    final raw = await api.getData(
      '/api/captiveportal/voucher/list_vouchers/${Uri.encodeComponent(provider)}/${Uri.encodeComponent(group)}',
    );
    return parseVouchers(raw);
  }

  Future<List<CaptivePortalVoucher>> generateVouchers({
    required String provider,
    required String group,
    required int count,
    required int validityMinutes,
    int expiryTime = 0,
  }) async {
    final raw = await api.postData(
      '/api/captiveportal/voucher/generate_vouchers/${Uri.encodeComponent(provider)}',
      data: {
        'count': count,
        'validity': validityMinutes,
        'expirytime': expiryTime,
        'vouchergroup': group,
      },
    );
    return parseVouchers(raw);
  }

  Future<void> expireVoucher(String provider, String username) async {
    await api.postData(
      '/api/captiveportal/voucher/expire_voucher/${Uri.encodeComponent(provider)}',
      data: {'username': username},
    );
  }

  Future<void> dropExpiredVouchers(String provider, String group) async {
    await api.postData(
      '/api/captiveportal/voucher/drop_expired_vouchers/${Uri.encodeComponent(provider)}/${Uri.encodeComponent(group)}',
    );
  }

  static List<CaptivePortalZone> parseZones(dynamic raw) {
    return _rows(raw).map((row) {
      return CaptivePortalZone(
        uuid: _first(row, const ['uuid', 'id']),
        zoneId: _first(row, const ['zoneid', 'zone_id', 'id']),
        description: _first(row, const ['description', 'descr', 'name']),
        interfaces: _text(row['interfaces'] ?? row['interface']),
        authServers: _text(row['authservers']),
        idleTimeout: _first(row, const ['idletimeout'], fallback: '0'),
        hardTimeout: _first(row, const ['hardtimeout'], fallback: '0'),
        serverName: _first(row, const ['servername']),
        enabled: !_truthy(row['disabled']) && _truthy(row['enabled'], defaultValue: true),
        roaming: _truthy(row['roaming'], defaultValue: true),
        concurrentLogins: _truthy(row['concurrentlogins'], defaultValue: true),
      );
    }).where((item) => item.uuid.isNotEmpty || item.zoneId.isNotEmpty).toList();
  }

  static List<CaptivePortalSession> parseSessions(dynamic raw) {
    return _rows(raw).map((row) {
      return CaptivePortalSession(
        sessionId: _first(row, const ['sessionId', 'session_id', 'sessionid', 'id']),
        zoneId: _first(row, const ['zoneid', 'zone_id', 'zone']),
        username: _first(row, const ['userName', 'username', 'user', 'name']),
        ip: _first(row, const ['ipAddress', 'ip', 'address']),
        mac: _first(row, const ['macAddress', 'mac', 'mac_address']),
        start: _first(row, const ['startTime', 'start', 'sessionStart', 'session_start']),
        lastAccess: _first(row, const ['lastAccess', 'last_access', 'lastActivity']),
        timeLeft: _first(row, const ['timeLeft', 'timeleft', 'time_left']),
        bytesIn: _first(row, const ['bytesIn', 'bytes_in', 'input_octets']),
        bytesOut: _first(row, const ['bytesOut', 'bytes_out', 'output_octets']),
      );
    }).where((item) => item.sessionId.isNotEmpty || item.ip.isNotEmpty).toList();
  }

  static List<CaptivePortalVoucher> parseVouchers(dynamic raw) {
    final rows = _rows(raw);
    if (rows.isNotEmpty) {
      return rows.map((row) => CaptivePortalVoucher(
        username: _first(row, const ['username', 'user', 'voucher', 'code']),
        password: _first(row, const ['password', 'pass']),
        validity: _first(row, const ['validity', 'minutes']),
        expiry: _first(row, const ['expiry', 'expirytime', 'expires']),
        used: _first(row, const ['used', 'active', 'status']),
      )).where((item) => item.username.isNotEmpty).toList();
    }
    if (raw is List) {
      return raw.map((item) {
        if (item is String) return CaptivePortalVoucher(username: item);
        return null;
      }).whereType<CaptivePortalVoucher>().toList();
    }
    return const <CaptivePortalVoucher>[];
  }

  static List<Map<String, dynamic>> _rows(dynamic raw) {
    dynamic candidate = raw;
    if (raw is Map) {
      candidate = raw['rows'] ?? raw['items'] ?? raw['data'] ?? raw['sessions'] ?? raw['vouchers'] ?? raw;
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

  static List<String> _stringList(dynamic raw) {
    dynamic candidate = raw;
    if (raw is Map) candidate = raw['rows'] ?? raw['items'] ?? raw['data'] ?? raw['providers'] ?? raw['groups'] ?? raw;
    final values = <String>[];
    if (candidate is List) {
      for (final item in candidate) {
        if (item is String || item is num) {
          values.add(item.toString());
        } else if (item is Map) {
          final text = _first(Map<String, dynamic>.from(item), const ['name', 'id', 'value', 'label']);
          if (text.isNotEmpty) values.add(text);
        }
      }
    } else if (candidate is Map) {
      for (final entry in candidate.entries) {
        final text = _text(entry.value);
        values.add(text.isEmpty ? entry.key.toString() : text);
      }
    }
    return values.toSet().toList()..sort();
  }

  static String _first(Map<String, dynamic> map, List<String> keys, {String fallback = ''}) {
    for (final key in keys) {
      final text = _text(map[key]);
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  static String _text(dynamic value) {
    if (value == null) return '';
    if (value is List) return value.map(_text).where((e) => e.isNotEmpty).join(', ');
    if (value is Map) {
      for (final key in const ['selected', 'value', 'name', 'label', 'description']) {
        final text = _text(value[key]);
        if (text.isNotEmpty) return text;
      }
      final selected = <String>[];
      for (final entry in value.entries) {
        if (_truthy(entry.value)) selected.add(entry.key.toString());
      }
      if (selected.isNotEmpty) return selected.join(', ');
    }
    return value.toString().trim();
  }

  static bool _truthy(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().trim().toLowerCase();
    if (const {'1', 'true', 'yes', 'on', 'enabled', 'running'}.contains(text)) return true;
    if (const {'0', 'false', 'no', 'off', 'disabled', 'stopped', ''}.contains(text)) return false;
    return defaultValue;
  }
}
