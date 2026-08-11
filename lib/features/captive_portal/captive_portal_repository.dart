import '../../core/api/api_choice.dart';
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

  Future<Map<String, dynamic>> getZone([String? uuid]) async {
    final suffix = uuid == null || uuid.isEmpty
        ? ''
        : '/${Uri.encodeComponent(uuid)}';
    final raw = await api.getData('/api/captiveportal/settings/get_zone$suffix');
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final zone = map['zone'];
      if (zone is Map) return Map<String, dynamic>.from(zone);
      return map;
    }
    return <String, dynamic>{};
  }

  Future<void> saveZone({
    String? uuid,
    required Map<String, dynamic> values,
  }) async {
    final raw = await api.postData(
      uuid == null || uuid.isEmpty
          ? '/api/captiveportal/settings/add_zone'
          : '/api/captiveportal/settings/set_zone/${Uri.encodeComponent(uuid)}',
      data: {'zone': values},
    );
    _ensureSuccess(raw, 'Save captive portal zone');
    final reconfigure = await api.postData('/api/captiveportal/service/reconfigure');
    _ensureSuccess(reconfigure, 'Reconfigure captive portal');
  }

  Future<void> deleteZone(String uuid) async {
    final raw = await api.postData(
      '/api/captiveportal/settings/del_zone/${Uri.encodeComponent(uuid)}',
    );
    _ensureSuccess(raw, 'Delete captive portal zone');
    final reconfigure = await api.postData('/api/captiveportal/service/reconfigure');
    _ensureSuccess(reconfigure, 'Reconfigure captive portal');
  }

  Future<void> toggleZone(CaptivePortalZone zone, bool enabled) async {
    final raw = await api.postData(
      '/api/captiveportal/settings/toggle_zone/${Uri.encodeComponent(zone.uuid)}/${enabled ? 1 : 0}',
    );
    _ensureSuccess(raw, 'Toggle captive portal zone');
    final reconfigure = await api.postData('/api/captiveportal/service/reconfigure');
    _ensureSuccess(reconfigure, 'Reconfigure captive portal');
  }

  Future<List<CaptivePortalSession>> loadSessions({
    String selectedZones = '',
  }) async {
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
      final key = entry.key.toString();
      if (entry.value is String || entry.value is num) {
        result[key] = entry.value.toString();
      } else if (entry.value is Map) {
        final option = Map<String, dynamic>.from(entry.value as Map);
        result[key] = _plainFirst(
          option,
          const ['description', 'name', 'label', 'value'],
          fallback: key,
        );
      }
    }
    return result;
  }

  Future<void> disconnectSession(String sessionId) async {
    final raw = await api.postData(
      '/api/captiveportal/session/disconnect',
      data: {'sessionId': sessionId},
    );
    _ensureSuccess(raw, 'Disconnect captive portal session');
  }

  Future<void> authorizeClient({
    required String zoneId,
    required String username,
    required String ip,
  }) async {
    final raw = await api.postData(
      '/api/captiveportal/session/connect/${Uri.encodeComponent(zoneId)}',
      data: {'user': username, 'ip': ip},
    );
    _ensureSuccess(raw, 'Authorize captive portal client');
  }

  Future<List<String>> loadVoucherProviders() async {
    final raw = await api.getData('/api/captiveportal/voucher/list_providers');
    return stringList(raw, preferredContainers: const ['providers']);
  }

  Future<List<String>> loadVoucherGroups(String provider) async {
    final raw = await api.getData(
      '/api/captiveportal/voucher/list_voucher_groups/${Uri.encodeComponent(provider)}',
    );
    return stringList(raw, preferredContainers: const ['groups']);
  }

  Future<List<CaptivePortalVoucher>> loadVouchers(
    String provider,
    String group,
  ) async {
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
    _ensureSuccess(raw, 'Generate captive portal vouchers');
    return parseVouchers(raw);
  }

  Future<void> expireVoucher(String provider, String username) async {
    final raw = await api.postData(
      '/api/captiveportal/voucher/expire_voucher/${Uri.encodeComponent(provider)}',
      data: {'username': username},
    );
    _ensureSuccess(raw, 'Expire captive portal voucher');
  }

  Future<void> dropExpiredVouchers(String provider, String group) async {
    final raw = await api.postData(
      '/api/captiveportal/voucher/drop_expired_vouchers/${Uri.encodeComponent(provider)}/${Uri.encodeComponent(group)}',
    );
    _ensureSuccess(raw, 'Drop expired captive portal vouchers');
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

  static String encodeChoices(Iterable<String> values) =>
      encodeApiChoiceValues(values);

  static String? selectedOne(Map<String, dynamic> model, String field) {
    final selected = parseApiChoices(model[field])
        .where((choice) => choice.selected)
        .toList();
    if (selected.isNotEmpty) return selected.first.value;
    final raw = model[field];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return null;
  }

  static List<CaptivePortalZone> parseZones(dynamic raw) {
    return _rows(raw).map((row) {
      return CaptivePortalZone(
        uuid: _first(row, const ['uuid', 'id']),
        zoneId: _first(row, const ['zoneid', 'zone_id', 'id']),
        description: _first(row, const ['description', 'descr', 'name']),
        interfaces: apiChoiceDisplayText(row['interfaces'] ?? row['interface']),
        authServers: apiChoiceDisplayText(row['authservers']),
        idleTimeout: _first(row, const ['idletimeout'], fallback: '0'),
        hardTimeout: _first(row, const ['hardtimeout'], fallback: '0'),
        serverName: _first(row, const ['servername']),
        enabled: !_truthy(row['disabled']) &&
            _truthy(row['enabled'], defaultValue: true),
        roaming: _truthy(row['roaming'], defaultValue: true),
        concurrentLogins: _truthy(
          row['concurrentlogins'],
          defaultValue: true,
        ),
      );
    }).where((item) => item.uuid.isNotEmpty || item.zoneId.isNotEmpty).toList();
  }

  static List<CaptivePortalSession> parseSessions(dynamic raw) {
    return _rows(raw).map((row) {
      return CaptivePortalSession(
        sessionId: _first(
          row,
          const ['sessionId', 'session_id', 'sessionid', 'id'],
        ),
        zoneId: _first(row, const ['zoneid', 'zone_id', 'zone']),
        username: _first(row, const ['userName', 'username', 'user', 'name']),
        ip: _first(row, const ['ipAddress', 'ip', 'address']),
        mac: _first(row, const ['macAddress', 'mac', 'mac_address']),
        start: _first(
          row,
          const ['startTime', 'start', 'sessionStart', 'session_start'],
        ),
        lastAccess: _first(
          row,
          const ['lastAccess', 'last_access', 'lastActivity'],
        ),
        timeLeft: _first(row, const ['timeLeft', 'timeleft', 'time_left']),
        bytesIn: _first(row, const ['bytesIn', 'bytes_in', 'input_octets']),
        bytesOut: _first(row, const ['bytesOut', 'bytes_out', 'output_octets']),
      );
    }).where((item) => item.sessionId.isNotEmpty || item.ip.isNotEmpty).toList();
  }

  static List<CaptivePortalVoucher> parseVouchers(dynamic raw) {
    dynamic candidate = raw;
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      candidate = map['vouchers'] ?? map['rows'] ?? map['items'] ?? raw;
    }
    final rows = _rows(candidate);
    if (rows.isNotEmpty) {
      return rows
          .map(
            (row) => CaptivePortalVoucher(
              username: _first(
                row,
                const ['username', 'user', 'voucher', 'code'],
              ),
              password: _first(row, const ['password', 'pass']),
              validity: _first(row, const ['validity', 'minutes']),
              expiry: _first(row, const ['expiry', 'expirytime', 'expires']),
              used: _first(row, const ['used', 'active', 'status']),
            ),
          )
          .where((item) => item.username.isNotEmpty)
          .toList();
    }
    if (candidate is List) {
      return candidate
          .map((item) {
            if (item is String || item is num) {
              return CaptivePortalVoucher(username: item.toString());
            }
            return null;
          })
          .whereType<CaptivePortalVoucher>()
          .toList();
    }
    return const <CaptivePortalVoucher>[];
  }

  static List<String> stringList(
    dynamic raw, {
    List<String> preferredContainers = const [],
  }) {
    dynamic candidate = raw;
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      for (final key in preferredContainers) {
        if (map[key] != null) {
          candidate = map[key];
          break;
        }
      }
      if (identical(candidate, raw)) {
        candidate = map['rows'] ?? map['items'] ?? map['data'] ?? raw;
      }
    }

    final values = <String>[];
    if (candidate is List) {
      for (final item in candidate) {
        if (item is String || item is num) {
          final value = item.toString().trim();
          if (value.isNotEmpty) values.add(value);
        } else if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final value = _plainFirst(
            map,
            const ['name', 'group', 'id', 'value', 'label', 'description'],
          );
          if (value.isNotEmpty) values.add(value);
        }
      }
    } else if (candidate is Map) {
      final optionChoices = parseApiChoices(
        candidate,
        scalarValuesSelected: false,
      );
      for (final choice in optionChoices) {
        final value = choice.label.trim().isEmpty
            ? choice.value.trim()
            : choice.label.trim();
        if (value.isNotEmpty && value != 'true' && value != 'false') {
          values.add(value);
        }
      }
    } else if (candidate is String || candidate is num) {
      final value = candidate.toString().trim();
      if (value.isNotEmpty) values.add(value);
    }

    final output = values.toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return output;
  }

  static List<Map<String, dynamic>> _rows(dynamic raw) {
    dynamic candidate = raw;
    if (raw is Map) {
      candidate = raw['rows'] ??
          raw['items'] ??
          raw['data'] ??
          raw['sessions'] ??
          raw['vouchers'] ??
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
          row.putIfAbsent('uuid', () => entry.key.toString());
          rows.add(row);
        }
      }
    }
    return rows;
  }

  static String _first(
    Map<String, dynamic> map,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = map[key];
      if (value is String || value is num) {
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      } else if (value is Map || value is Iterable) {
        final text = apiChoiceDisplayText(value);
        if (text.isNotEmpty) return text;
      }
    }
    return fallback;
  }

  static String _plainFirst(
    Map<String, dynamic> map,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = map[key];
      if (value is String || value is num) {
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
    }
    return fallback;
  }

  static bool _truthy(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().trim().toLowerCase();
    if (const {'1', 'true', 'yes', 'on', 'enabled', 'running'}.contains(text)) {
      return true;
    }
    if (const {'0', 'false', 'no', 'off', 'disabled', 'stopped', ''}.contains(text)) {
      return false;
    }
    return defaultValue;
  }

  static void _ensureSuccess(dynamic raw, String operation) {
    if (raw is! Map) return;
    final map = Map<String, dynamic>.from(raw);
    final result = map['result']?.toString().trim().toLowerCase();
    final status = map['status']?.toString().trim().toLowerCase();
    if (result == 'failed' || status == 'failed' || status == 'error') {
      final validations = map['validations'] ?? map['validation'];
      if (validations is Map && validations.isNotEmpty) {
        final details = validations.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join(' · ');
        throw StateError('$operation failed: $details');
      }
      final message = _plainFirst(map, const ['message', 'error']);
      throw StateError(
        message.isEmpty ? '$operation failed.' : '$operation failed: $message',
      );
    }
  }
}
